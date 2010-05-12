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
#include <assert.h>

extern config_t *Config;

http_req_t* http_req_new() {
  LOG_FUNCTION
  http_req_t* req = wr_malloc(http_req_t);

  if(req == NULL) {
    return NULL;
  }

  req->bytes_read = req->scgi_header_len = req->req_len = 0;
  req->file = NULL;
  req->scgi = NULL;

  return req;
};

void http_req_free(http_req_t** r) {
  LOG_FUNCTION
  http_req_t* req = *r;
  if(req) {
    if(req->file) {
      fclose(req->file);
      unlink(req->file_name);
    }
    if(req->scgi)
      scgi_free(req->scgi);
    free(req);
  }
  *r = NULL;
}

void http_req_set(http_req_t *req) {
  LOG_FUNCTION
  req->bytes_read = req->scgi_header_len = req->req_len = 0;
  if(req->file) {
    fclose(req->file);
    unlink(req->file_name);
  }
  if(req->scgi)
    scgi_free(req->scgi);
  req->file = NULL;
  req->scgi = NULL;
}

/* pass an allocated buffer and the length to read. this function will try to
 * fill the buffer with that length of data read from the body of the request.
 * the return value says how much was actually written.
 */
int http_req_body_read(http_req_t *req, char *buf, int len) {
  LOG_FUNCTION
  size_t read = 0;

  if(req->bytes_read >= req->req_len) {
    LOG_DEBUG(DEBUG,"Request body reading complete.");
    return 0;
  }
  if(req->file) {
    read = fread(buf, sizeof(char), len, req->file);

    //      FILE *f=fopen("/tmp/wkr.log","a+");
    //    if(f){
    //      fwrite(buf,  read, sizeof(char), f);
    //      fclose(f);
    //    }
    req->bytes_read += read;
    LOG_DEBUG(DEBUG,"http_req_body_read() from file asked len = %d, actual read =%d  bytes sent = %d/%d",
              len, read, req->bytes_read, req->req_len);
    /* TODO error checking! */
    return read;
  } else {
    char* req_body = req->buf + req->scgi_header_len;

    read = wr_ramp(wr_min(len, req->req_len - req->bytes_read));
    memcpy( buf, req_body + req->bytes_read, read);

    //    FILE *f=fopen("/tmp/wkr.log","a+");
    //    if(f){
    //      fwrite(buf,  read, sizeof(char), f);
    //      fclose(f);
    //    }

    req->bytes_read += read;
    LOG_DEBUG(DEBUG,"http_req_body_read() from buffer asked len = %d, actual read = %d, bytes sent = %d/%d",
              len, read, req->bytes_read, req->req_len);
    return read;
  }
}

/** Read SCGI request body in buffer */
void http_req_body_read_in_buff(http_req_t *req, struct ev_loop *loop, struct ev_io *watcher) {
  LOG_FUNCTION
  ssize_t read = recv(watcher->fd,
                      req->buf + req->scgi_header_len + req->bytes_read,
                      req->req_len - req->bytes_read,
                      0);
  if(read < 0) {
    LOG_ERROR(SEVERE,"Error reading header:%s",strerror(errno));
    return;
  }

  if(read == 0) {
    ev_io_stop(loop, watcher);
    LOG_DEBUG(DEBUG,"peer might closing");
    sigproc();
    return;
  }
  req->bytes_read += read;

  if(req->bytes_read == req->req_len) {
    ev_io_stop(loop, watcher);
    req->bytes_read = 0;
    http_req_process();
  }
}

/** Read SCGI request body in file */
void http_req_body_read_in_file(http_req_t *req, struct ev_loop *loop, struct ev_io *watcher) {
  LOG_FUNCTION
  char buffer[STR_SIZE10KB+1];
  ssize_t read, write = 0, rv;

  read = recv(watcher->fd,
              buffer,
              wr_min(req->req_len - req->bytes_read, STR_SIZE10KB),
              0);

  if(read < 0) {
    LOG_ERROR(WARN,"error in request parsing");
    return;
  }

  while(write < read) {
    rv = fwrite(buffer + write, sizeof(char), read - write, req->file);
    if(rv<0) {
      LOG_ERROR(WARN,"error in writing request into file:%s",strerror(errno));
    } else {
      write += rv;
    }
  }
  req->bytes_read += read;

  if(req->bytes_read == req->req_len) {
    ev_io_stop(loop, watcher);
    req->bytes_read = 0;
    rewind(req->file);
    http_req_process();
  }
}

/** Read SCGI request body */
void http_req_body_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t *w     = (wkr_t*) watcher->data;
  http_req_t *req   = w->http->req;

  LOG_DEBUG(DEBUG,"read_request_body_cb() conn id=%d, Request id=%d",
            w->http->conn_id,  w->http->req_id);

  if(EV_ERROR & revents) {
    LOG_ERROR(SEVERE,"read_request_body_cb() got error event, returning.");
    return;
  }

  if (revents & EV_READ) {
    if(req->file == NULL) {
      http_req_body_read_in_buff(req, loop, watcher);
    } else {
      http_req_body_read_in_file(req, loop, watcher);
    }
  }
}

/** Parse SCGI request */
void parser_req_buf(http_req_t *req, struct ev_loop *loop, struct ev_io *watcher) {
  LOG_FUNCTION
  if(req->scgi_header_len == 0) {
    // Fetch header packet length
    int i;

    for( i = 0 ; i < req->bytes_read; i++) {
      if(req->buf[i] == ':')
        break;
    }

    if(i >= req->bytes_read)
      return;

    req->scgi_header_len = atoi(req->buf) + i + 2;

    LOG_DEBUG(DEBUG,"parser_req_buf() header pkt len =%d and header len = %d, bytes read = %d",
              req->scgi_header_len,
              req->scgi_header_len - i - 2,
              req->bytes_read);
  }

  if(req->bytes_read >= req->scgi_header_len) {
    ev_io_stop(loop, watcher);
    if(req->buf[req->scgi_header_len-1] != ',') {
      LOG_ERROR(WARN,"error in request parsing = %c", req->buf[req->scgi_header_len-1]);
      return;
    } else {
      req->scgi = scgi_parse(req->buf, req->scgi_header_len);
      if(req->scgi == NULL) {
        LOG_ERROR(SEVERE,"Error in preparing scgi headers");
        return;
      }
      //first header in SCGI request must be content-length
      req->req_len = atoi(scgi_header_value_get(req->scgi, SCGI_CONTENT_LENGTH));
      req->bytes_read -= req->scgi_header_len;
      LOG_DEBUG(DEBUG, "Request length = %d", req->req_len);
      
#ifdef L_DEBUG
      // Fetch Connection id
      wkr_t *w = (wkr_t*) watcher->data;
      scgi_header_t *header = scgi_header_get(req->scgi, Config->Worker.Header.conn_id.str);
      if(header){
        w->http->conn_id = atoi(req->scgi->header + req->scgi->start_offset + header->value_offset);
      }else{
        w->http->conn_id = 0;
      }
      
      // Fetch request id
      header = scgi_header_get(req->scgi, Config->Worker.Header.req_id.str);
      if(header){
        w->http->req_id = atoi(req->scgi->header + req->scgi->start_offset + header->value_offset);
      }else{
        w->http->req_id = 0;
      }
      LOG_DEBUG(DEBUG,"parser_req_buf() content len=%d, conn id=%d, Request id=%d",
                req->req_len, w->http->conn_id, w->http->req_id );
#endif

      LOG_DEBUG(DEBUG, "butes read = %d, request length = %d", req->bytes_read, req->req_len);
      if(req->bytes_read == req->req_len) {
        req->bytes_read = 0;
        http_req_process();
      } else {
        if(req->req_len + req->scgi_header_len  > STR_SIZE10KB) {
          ssize_t write;
          size_t processed_bytes = 0;

          sprintf(req->file_name, "/tmp/proc_upload_file_%d", getpid());

          req->file = fopen(req->file_name,"w+");
          assert(req->file !=NULL);
          //reading body part from request buffer
          while(processed_bytes < req->bytes_read) {
            write = fwrite(req->buf + req->scgi_header_len + processed_bytes,
                           sizeof(char),
                           req->bytes_read - processed_bytes,
                           req->file);
            if(write < 0) {
              LOG_ERROR(WARN,"Error writing into file:%s",strerror(errno));
            } else {
              processed_bytes += write;
            }
          }
        }

        ev_io_init(watcher, http_req_body_cb, watcher->fd,EV_READ);
        ev_io_start(loop,watcher);
      }
    }
  }
}

/** Read SCGI request headers */
void http_req_header_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t *w     = (wkr_t*) watcher->data;
  http_req_t *req   = w->http->req;

  if(EV_ERROR & revents) {
    LOG_ERROR(SEVERE,"http_req_header_cb() got error event, returning.");
    return;
  }
  if (revents & EV_READ) {

    ssize_t read = recv(watcher->fd
                        , req->buf + req->bytes_read
                        , STR_SIZE10KB - req->bytes_read
                        , 0
                       );
    if(read < 0) {
      LOG_ERROR(SEVERE,"Error reading header:%s",strerror(errno));
      return;
    }

    if(read == 0) {
      ev_io_stop(loop,watcher);
      LOG_DEBUG(DEBUG,"peer might closing");
      sigproc();
      return;
    }

    req->bytes_read += read;
    parser_req_buf(req, loop, watcher);
  }
}

