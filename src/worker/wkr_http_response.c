/* WebROaR - Ruby Application Server - http://webroar.in/
 * Copyright (C) 2009  Goonj LLC
 *
 * This file is part of WebROaR.
 *
 * WebROaR is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * WebROaR is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <worker.h>
#include <stdlib.h>

extern config_t *Config;

http_resp_t* http_resp_new() {
  LOG_FUNCTION
  http_resp_t *rsp = wr_malloc(http_resp_t);

  if (rsp == NULL) {
    return NULL;
  }

  wr_buffer_new(rsp->resp_body);
  wr_string_null(rsp->header);

  rsp->bytes_write = 0;
  rsp->resp_code = 0;
  rsp->scgi = NULL;
#ifdef _POSIX_C_SOURCE
  rsp->file = 0;
#else
  rsp->file = NULL;
#endif

  return rsp;
}

void http_resp_free(http_resp_t **r) {
  LOG_FUNCTION
  http_resp_t *rsp = *r;
  if (rsp) {
    wr_buffer_free(rsp->resp_body);
    wr_string_free(rsp->header);
    if (rsp->scgi)
      scgi_free(rsp->scgi);
    if (rsp->file) {
#ifdef _POSIX_C_SOURCE
      close(rsp->file);
#else
      fclose(rsp->file);
      rsp->file = NULL;
#endif      
    }
    free(rsp);
  }
  *r = NULL;
}

void http_resp_set(http_resp_t *rsp) {
  LOG_FUNCTION
  rsp->bytes_write = 0;
  rsp->resp_code = 0;
  wr_buffer_null(rsp->resp_body);
  wr_string_free(rsp->header);
  if (rsp->scgi)
    scgi_free(rsp->scgi);
  if (rsp->file) {
#ifdef _POSIX_C_SOURCE
      close(rsp->file);
#else
      fclose(rsp->file);
      rsp->file = NULL;
#endif
  }
  rsp->scgi = NULL;
}

int http_resp_body_add(http_resp_t *rsp, const char* str, size_t len) {
  LOG_FUNCTION
  wr_buffer_add(rsp->resp_body, str, len);
  return 0;
}

int http_resp_process(http_resp_t *rsp) {
  LOG_FUNCTION
  rsp->scgi = scgi_new();

  if (rsp->scgi == NULL) {
    return -1;
  }

  char str[16];
  size_t len;

  len = sprintf(str, "%d", rsp->resp_code);
  scgi_header_add(rsp->scgi, Config->Worker.Header.resp_code.str, Config->Worker.Header.resp_code.len, str, len);

  len = sprintf(str, "%d", rsp->resp_body->len);
  scgi_header_add(rsp->scgi, Config->Worker.Header.resp_content_len.str, Config->Worker.Header.resp_content_len.len, str, len);

  scgi_content_length_add(rsp->scgi, rsp->resp_body->len + rsp->header.len);

  scgi_build(rsp->scgi);

  return 0;
}

void http_resp_file_write_cb(struct ev_loop* loop, struct ev_io* watcher, int revent) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;

  LOG_DEBUG(DEBUG, "http_resp_file_write_cb() conn id=%d, Request id=%d",
          w->http->conn_id, w->http->req_id);

  if (revent & EV_WRITE) {
#ifndef _POSIX_C_SOURCE
  http_resp_t *rsp = w->http->resp;
  ssize_t sent;

    if (rsp->file) {
      char buffer[Config->Worker.max_body_size];
      ssize_t read;
      int rv = fseek(rsp->file, rsp->bytes_write, SEEK_SET);
      if (rv < 0) {
        LOG_ERROR(WARN, "Error reading file:%s", strerror(errno));
        return;
      }
      read = fread(buffer, 1, Config->Worker.max_body_size, rsp->file);
      sent = send(watcher->fd, buffer, read, 0);
    }

    if (sent < 0) {
      ev_io_stop(loop, watcher);
      LOG_ERROR(WARN, "Error sending response:%s,errno=%d", strerror(errno), errno);
      // errno 32 = Broken Pipe.
      if (errno == 32)
        sigproc();
      return;
    }

    rsp->bytes_write += sent;

    LOG_DEBUG(DEBUG, "http_resp_file_write_cb() bytes write = %d, sent = %d", rsp->bytes_write, sent);

    if (rsp->bytes_write >= rsp->resp_body->len) {
      ev_io_stop(loop, watcher);
      http_resp_set(rsp);
      LOG_DEBUG(DEBUG, "http_resp_file_write_cb() starting read watcher.");
      ev_io_init(watcher, http_req_header_cb, w->req_fd, EV_READ);
      ev_io_start(loop, watcher);
    }
#endif    
  }
}

void http_resp_body_write_cb(struct ev_loop* loop, struct ev_io* watcher, int revent) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;
  http_resp_t *rsp = w->http->resp;

  ssize_t sent;

  LOG_DEBUG(DEBUG, "http_resp_body_write_cb() conn id=%d, Request id=%d",
          w->http->conn_id, w->http->req_id);

  if (revent & EV_WRITE) {
    sent = send(watcher->fd,
            rsp->resp_body->str + rsp->bytes_write,
            rsp->resp_body->len - rsp->bytes_write,
            0);

    if (sent < 0) {
      ev_io_stop(loop, watcher);
      LOG_ERROR(WARN, "Error sending response:%s,errno=%d", strerror(errno), errno);
      // errno 32 = Broken Pipe.
      if (errno == 32)
        sigproc();
      return;
    }

    rsp->bytes_write += sent;

    LOG_DEBUG(DEBUG, "http_resp_body_write_cb() bytes write = %d, sent = %d", rsp->bytes_write, sent);

    if (rsp->bytes_write >= rsp->resp_body->len) {
      ev_io_stop(loop, watcher);
      http_resp_set(rsp);
      LOG_DEBUG(DEBUG, "http_resp_body_write_cb() starting read watcher.");
      ev_io_init(watcher, http_req_header_cb, w->req_fd, EV_READ);
      ev_io_start(loop, watcher);
    }
  }
}

void http_resp_file_send_cb(struct ev_loop* loop, struct ev_io* watcher, int revent) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;
  http_resp_t *rsp = w->http->resp;

#ifdef _POSIX_C_SOURCE
   long int rv = sendfile(watcher->fd, rsp->file, &rsp->bytes_write, rsp->resp_body->len - rsp->bytes_write);
   if (rv == -1) {
    LOG_ERROR(SEVERE, "error from sendfile: %s\n", strerror(errno));
    return;
  }
#else
   char buffer[Config->Worker.max_body_size];
   ssize_t read, sent;
   int rv = fseek(rsp->file, rsp->bytes_write, SEEK_SET);
   if(rv < 0) {
     LOG_ERROR(WARN,"Error reading file:%s",strerror(errno));
     return;
   }
   read = fread(buffer, 1, Config->Worker.max_body_size, rsp->file);
   sent = send(watcher->fd, buffer, read, 0);
   if (sent < 0) {
    LOG_ERROR(SEVERE, "error in file sending: %s\n", strerror(errno));
    return;
  }
  rsp->bytes_write += sent;
#endif

  LOG_DEBUG(DEBUG, "http_resp_body_write_cb() bytes wrire = %d, file size = %d",
          rsp->bytes_write, rsp->resp_body->len);

  if (rsp->bytes_write >= rsp->resp_body->len) {
    ev_io_stop(w->loop, &w->w_req);
    http_resp_set(rsp);
    LOG_DEBUG(DEBUG, "http_resp_body_write_cb() starting read watcher.");
    ev_io_init(watcher, http_req_header_cb, w->req_fd, EV_READ);
    ev_io_start(loop, watcher);
  }
}

void http_resp_header_write_cb(struct ev_loop* loop, struct ev_io* watcher, int revent) {
  LOG_FUNCTION;
  wkr_t *w = (wkr_t*) watcher->data;
  http_resp_t *rsp = w->http->resp;

  ssize_t sent;

  LOG_DEBUG(DEBUG, "http_resp_header_write_cb() conn id=%d, Request id=%d",
          w->http->conn_id, w->http->req_id);

  if (revent & EV_WRITE) {
    sent = send(watcher->fd,
            rsp->header.str + rsp->bytes_write,
            rsp->header.len - rsp->bytes_write,
            0);

    if (sent < 0) {
      ev_io_stop(loop, watcher);
      LOG_ERROR(WARN, "Error sending response:%s,errno=%d", strerror(errno), errno);
      // errno 32 = Broken Pipe.
      if (errno == 32)
        sigproc();
      return;
    }

    rsp->bytes_write += sent;

    LOG_DEBUG(DEBUG, "http_resp_header_write_cb() bytes write = %d, sent = %d", rsp->bytes_write, sent);

    if (rsp->bytes_write >= rsp->header.len) {
      ev_io_stop(loop, watcher);
      LOG_DEBUG(DEBUG, "http_resp_header_write_cb() starting read watcher. bytes write=%d", rsp->bytes_write);
      if (rsp->resp_body->len > 0) {
        rsp->bytes_write = 0;
        if (w->http->is_static && w->http->resp->resp_code == 200) {
          ev_io_init(watcher, http_resp_file_send_cb, w->req_fd, EV_WRITE);
          //send_file(w);
          //ev_io_init(watcher, http_resp_file_write_cb, w->req_fd, EV_WRITE);
        }else {
          ev_io_init(watcher, http_resp_body_write_cb, w->req_fd, EV_WRITE);
        }
        ev_io_start(loop, watcher);
      } else {
        http_resp_set(rsp);
        LOG_DEBUG(DEBUG, "http_resp_body_write_cb() starting read watcher");
        ev_io_init(watcher, http_req_header_cb, w->req_fd, EV_READ);
        ev_io_start(loop, watcher);
      }
    }
  }
}

void http_resp_scgi_write_cb(struct ev_loop* loop, struct ev_io* watcher, int revent) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;
  http_resp_t *rsp = w->http->resp;

  LOG_DEBUG(DEBUG, "http_resp_scgi_write_cb() conn id=%d, Request id=%d",
          w->http->conn_id, w->http->req_id);

  if (revent & EV_WRITE) {
  if (scgi_send(rsp->scgi, watcher->fd) <= 0) {
      ev_io_stop(loop, watcher);
      LOG_ERROR(WARN, "Error sending response:%s,errno=%d", strerror(errno), errno);
      // errno 32 = Broken Pipe.
      if (errno == 32)
        sigproc();
      return;
    }

    LOG_DEBUG(DEBUG, "http_resp_scgi_write_cb() bytes write = %d, sent = %d", rsp->scgi->length, rsp->scgi->bytes_sent);

    if (rsp->scgi->bytes_sent >= rsp->scgi->length) {
      ev_io_stop(loop, watcher);
      LOG_DEBUG(DEBUG, "http_resp_scgi_write_cb() starting read watcher. bytes write=%d", rsp->bytes_write);
      rsp->bytes_write = 0;
      ev_io_init(watcher, http_resp_header_write_cb, w->req_fd, EV_WRITE);
      ev_io_start(loop, watcher);
    }
  }
}
