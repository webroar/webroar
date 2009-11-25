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
#include <wr_logger.h>
#include <netinet/in.h>
#include <sys/un.h>

extern int is_alive;

wkr_ctl_t* wkr_ctl_new() {
  LOG_FUNCTION
  wkr_ctl_t *ctl = wr_malloc(wkr_ctl_t);

  if(ctl == NULL) {
    return NULL;
  }

  ctl->fd = -1;
  ctl->msg_size = ctl->bytes_read = 0;
  ctl->scgi = NULL;

  return ctl;
}

void wkr_ctl_free(wkr_ctl_t **c) {
  LOG_FUNCTION
  wkr_ctl_t *ctl = *c;
  if(ctl) {
    if(ctl->fd > 0)
      close(ctl->fd);
    if(ctl->scgi)
      scgi_free(ctl->scgi);
    free(ctl);
  }
  *c = NULL;
}

/** Process control message */
static inline void ctl_msg_process(wkr_t* w) {
  LOG_FUNCTION
  wkr_ctl_t *ctl = w->ctl;
  char *value;

  scgi_t* ctl_req = ctl->scgi;
  ctl->scgi = NULL;

  value = (char*) scgi_header_value_get(ctl_req, "METHOD");
  if(value) {
    if(strcmp(value,"ADD")==0) {
      // Response of ADD method
      value = (char*) scgi_header_value_get(ctl_req, "STATUS");
      if(value && strcmp(value, "OK")==0) {
        LOG_INFO("Worker connected with Head.");
      } else {
        LOG_ERROR(SEVERE,"Unable to connect with Head.");
        sigproc();
      }
    } else if(strcmp(value,"REMOVE")==0) {
      //Request to REMOVE worker
      //TODO: need to send acknowledgement for clossing or not
      /*scgi_t* ctl_resp = scgi_new();
      if(ctl_resp){
        scgi_header_add(ctl_resp, "METHOD", strlen("METHOD"), "REMOVE", strlen("REMOVE"));
        scgi_header_add(ctl_resp, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
        scgi_build(ctl_resp);
        send(control.fd, ctl_resp->request_buffer, ctl_resp->request_length, 0);
        scgi_free(ctl_resp);
    }*/
      sigproc();
    } else if(strcmp(value,"PING") == 0) {
      LOG_INFO("Worker got PING message");
      scgi_t* ctl_resp = scgi_new();
      if(ctl_resp) {
        scgi_header_add(ctl_resp, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
        scgi_header_add(ctl_resp, "METHOD", strlen("METHOD"), "PING", strlen("PING"));
        scgi_header_add(ctl_resp, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
        scgi_build(ctl_resp);
        ctl->scgi = ctl_resp;
        ev_io_start(w->loop, &ctl->w_write);
      }
    }
  } else {
    LOG_ERROR(SEVERE,"METHOD is missing");
  }
}

/** Send SCGI control message */
void ctl_write_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t* w = (wkr_t*) watcher->data;
  wkr_ctl_t *ctl = w->ctl;

  if(revents & EV_ERROR) {
    ev_io_stop(loop, watcher);
    LOG_ERROR(SEVERE,"Error writing control message :%s",strerror(errno));
    sigproc();
    return;
  }
  if(scgi_send(ctl->scgi, watcher->fd) <= 0){
    ev_io_stop(loop, watcher);
    LOG_ERROR(SEVERE,"Error writing control message :%s",strerror(errno));
    sigproc();
    return;
  }

  // Check message length
  if(ctl->scgi->bytes_sent >= ctl->scgi->length) {
    ev_io_stop(loop, watcher);
    LOG_DEBUG(DEBUG, "ctl_write_cb() message sent successfully");
    scgi_free(ctl->scgi);
    ctl->scgi = NULL;
  }
}

/** Read control message */
void ctl_read_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t* w = (wkr_t*) watcher->data;
  wkr_ctl_t *ctl = w->ctl;

  if(revents & EV_ERROR) {
    ev_io_stop(loop, watcher);
    is_alive = 0;
    LOG_ERROR(SEVERE,"Error reading control message :%s",strerror(errno));
    return;
  }
  int bytesRead = recv(watcher->fd, ctl->msg + ctl->bytes_read,
                       WR_MSG_SIZE - ctl->bytes_read, 0);

  if(bytesRead <= 0) {
    LOG_ERROR(SEVERE,"Error reading control message :%s",strerror(errno));
    ev_io_stop(loop, watcher);
    is_alive = 0;
    return;
  }
  ctl->bytes_read += bytesRead;

  int i;
  for(i = 0 ; i <  ctl->bytes_read ; i++) {
    if(ctl->msg[i] == ':') {
      break;
    }
  }
  if(i >= ctl->bytes_read)
    return;
  ctl->msg_size = atoi(ctl->msg);
  ctl->msg_size += (i+2);

  scgi_t* ctl_req = NULL;

  if(ctl->bytes_read >= ctl->msg_size) {
    ctl_req = scgi_parse(ctl->msg, ctl->msg_size);
    if(ctl_req == NULL ) {
      LOG_ERROR(SEVERE,"Cannot parse control message.");
      ev_io_stop(loop,watcher);
      is_alive = 0;
      return;
    }
    ctl->msg_size += atoi(scgi_header_value_get(ctl_req, SCGI_CONTENT_LENGTH));
    if(ctl->bytes_read < ctl->msg_size) {
      scgi_free(ctl_req);
      return;
    }

    ctl->scgi = ctl_req;
    ctl_msg_process(w);
    scgi_free(ctl_req);
  } else {
    return;
  }

  ctl->bytes_read = ctl->msg_size = 0;
}

/** Send connect acknowledgement on internet socket */
int send_ack_on_internet_socket(wkr_t* w) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG,"send_ack_on_internet_socket() port = %i", w->listen_port);
  wkr_ctl_t *ctl = w->ctl;

  struct sockaddr_in addr;

  if ((ctl->fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    LOG_ERROR(WARN,"socket():%s",strerror(errno));
    return -1;
  }
  setsocketoption(ctl->fd);
  LOG_DEBUG(DEBUG,"send_ack_on_internet_socket() FD for control.fd is %d",ctl->fd);
  int iport = atoi(w->tmp->ctl_path.str);
  addr.sin_family = AF_INET;         // host byte order
  addr.sin_port = htons(iport);     // short, network byte order
  addr.sin_addr.s_addr =  htonl(INADDR_ANY); // auto-fill with my IP
  memset(addr.sin_zero, '\0', sizeof addr.sin_zero);

  if(connect(ctl->fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
    LOG_ERROR(SEVERE,"Connection with controller failed:%s",strerror(errno));
    return -1;
  }
  char buf[WR_SHORT_STR_LEN];
  int len;
  pid_t pid = getpid();

  scgi_t* add_request = scgi_new();
  if(add_request == NULL) {
    LOG_ERROR(SEVERE,"Cannot create SCGI Request");
    return -1;
  }

  // Construct SCGI request
  scgi_header_add(add_request, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
  scgi_header_add(add_request, "METHOD", strlen("METHOD"), "ADD", strlen("ADD"));
  scgi_header_add(add_request, "APPLICATION", strlen("APPLICATION"), w->tmp->name.str, w->tmp->name.len);
  scgi_header_add(add_request, "UDS", strlen("UDS"), "NO", strlen("NO"));
  len = sprintf(buf, "%d", w->listen_port);
  scgi_header_add(add_request, "PORT", strlen("PORT"), buf, len);
  len = sprintf(buf, "%d", pid);
  scgi_header_add(add_request, "PID", strlen("PID"), buf, len);

  scgi_build(add_request);

  ctl->w_read.data = ctl->w_write.data = w;
  ctl->bytes_read = 0;
//  ctl->bytes_write = 0;
  ctl->scgi = add_request;
  ev_io_init(&(ctl->w_read),ctl_read_cb, ctl->fd,EV_READ);
  ev_io_start(w->loop,&(ctl->w_read));
  ev_io_init(&(ctl->w_write),ctl_write_cb, ctl->fd,EV_WRITE);
  ev_io_start(w->loop,&(ctl->w_write));

  return 0;
}

/** Send connect  acknowledgement on unix domain socket */
int send_ack_on_unix_socket(wkr_t* w) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG,"send_ack_on_unix_socket() path = %s", w->sock_path.str);
  wkr_ctl_t *ctl = w->ctl;
  size_t len;

  char buf[WR_SHORT_STR_LEN];
  pid_t pid = getpid();
  scgi_t* add_request = scgi_new();
  if(add_request == NULL) {
    LOG_ERROR(SEVERE,"Cannot create SCGI Request");
    return -1;
  }

  // Construct SCGI request
  scgi_header_add(add_request, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
  scgi_header_add(add_request, "METHOD", strlen("METHOD"), "ADD", strlen("ADD"));
  scgi_header_add(add_request, "APPLICATION", strlen("APPLICATION"), w->tmp->name.str, w->tmp->name.len);
  scgi_header_add(add_request, "UDS", strlen("UDS"), "YES", strlen("YES"));
  scgi_header_add(add_request, "SOCK_PATH", strlen("SOCK_PATH"), w->sock_path.str, w->sock_path.len);
  len = sprintf(buf, "%d",  pid);
  scgi_header_add(add_request, "PID", strlen("PID"), buf, len);

  scgi_build(add_request);

  ctl->w_read.data = ctl->w_write.data = w;
  ctl->bytes_read = 0; 
  //ctl->bytes_write = 0;
  ctl->scgi = add_request;
  ev_io_init(&(ctl->w_read),ctl_read_cb, ctl->fd,EV_READ);
  ev_io_start(w->loop,&(ctl->w_read));
  ev_io_init(&(ctl->w_write),ctl_write_cb, ctl->fd,EV_WRITE);
  ev_io_start(w->loop,&(ctl->w_write));

  return 0;
}
