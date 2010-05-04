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
/**********************************************************
 *             Worker
 *********************************************************/

/**
 * Parse argument list
 * Initialize Worker to accept SCGI request from Head
 * Load web application
 * Start Atals Worker
 */

#include <worker.h>
#include <stdlib.h>
#include <assert.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <ev.c>

extern config_t *Config;

wkr_tmp_t* wkr_tmp_new() {
  LOG_FUNCTION
  wkr_tmp_t *tmp = wr_malloc(wkr_tmp_t);

  if(tmp == NULL) {
    return NULL;
  }
  wr_string_null(tmp->path);
  wr_string_null(tmp->env);
  wr_string_null(tmp->type);
  wr_string_null(tmp->name);
  wr_string_null(tmp->resolver);
  wr_string_null(tmp->root_path);
  wr_string_null(tmp->ctl_path);
  wr_string_null(tmp->log_file);
  tmp->env_var = NULL;

  tmp->profiler = 'n';
  tmp->gid = tmp->uid = 0;
  // HTTP1.1 assumes persistent connection by default
  tmp->keep_alive = TRUE;
  tmp->is_uds = FALSE;
  tmp->is_static = 0;

  return tmp;
}

void wkr_tmp_free(wkr_tmp_t** t) {
  LOG_FUNCTION
  wkr_tmp_t *tmp = *t;
  if(tmp) {
    wr_string_free(tmp->path);
    wr_string_free(tmp->env);
    wr_string_free(tmp->type);
    wr_string_free(tmp->name);
    wr_string_free(tmp->resolver);
    wr_string_free(tmp->root_path);
    wr_string_free(tmp->ctl_path);
    wr_string_free(tmp->log_file);
    wr_string_list_free(tmp->env_var);

    free(tmp);
  }
  *t = NULL;
}

/** Create new Worker */
wkr_t* worker_new(struct ev_loop *loop, wkr_tmp_t *tmp) {
  LOG_FUNCTION
  wkr_t* w = wr_malloc(wkr_t);

  assert(w!=NULL);

  w->req_fd = -1;
  w->listen_fd = -1;
  w->is_uds = tmp->is_uds;
  w->loop = loop;
  wr_string_null(w->sock_path);
  w->listen_port = 0;

  w->tmp = tmp;
  assert(w->tmp!=NULL);

  w->ctl = wkr_ctl_new();
  assert(w->ctl!=NULL);

  // Connect to head controller UDS socket before user previliges get lowered.
  if(tmp->is_uds) {
    struct sockaddr_un addr;

    if ((w->ctl->fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
      LOG_ERROR(WARN,"socket()%s",strerror(errno));
      worker_free(&w);
      return NULL;
    }

    setsocketoption(w->ctl->fd);

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, tmp->ctl_path.str);

    int len = sizeof(addr.sun_family)+strlen(addr.sun_path);
#ifdef __APPLE__
    len ++;
#endif

    LOG_DEBUG(DEBUG,"send_ack_on_unix_socket() connecting with socket %s",addr.sun_path);
    if(connect(w->ctl->fd, (struct sockaddr *)&addr, len) < 0) {
      LOG_ERROR(SEVERE,"Connect with controller fd failed: %s",strerror(errno));
      worker_free(&w);
      return NULL;
    }
  }

  return w;
}

void worker_free(wkr_t **wrk) {
  LOG_FUNCTION
  wkr_t *w = *wrk;
  if(w) {
    if(w->req_fd > 0)
      close(w->req_fd);
    if(w->listen_fd > 0)
      close(w->listen_fd);
    if(w->sock_path.str) {
      // Set root privilege to remove socket file.
      //      if(setegid(0)!=0){
      //        LOG_ERROR(SEVERE,"setegid() to root failed");
      //      }
      //      if(seteuid(0)!=0){
      //        LOG_ERROR(SEVERE,"seteuid() to root failed");
      //      }
      unlink(w->sock_path.str);
      wr_string_free(w->sock_path);
    }
    ev_io_stop(w->loop, &(w->w_accept));
    ev_io_stop(w->loop, &(w->ctl->w_read));
    if(w->http)
      http_free(&w->http);    
    if(w->tmp)
      wkr_tmp_free(&w->tmp);
    if(w->ctl)
      wkr_ctl_free(&w->ctl);

    free(w);
  }
  *wrk=NULL;
}

/** Conenct worker on internet socket */
static inline int connect_internet_socket(wkr_t* w) {
  LOG_FUNCTION
  struct sockaddr_in addr;
  if ((w->listen_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    perror("socket()");
    return -1;
  }

  if(setnonblock(w->listen_fd)<0) {
    LOG_ERROR(SEVERE,"Setting fd non block failed");
    return -1;
  }
  setsocketoption(w->listen_fd);
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = 0; // to bind to an ephemeral port
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(w->listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("bind()");
    return -1;
  }
  //determine port to which listen_fd bound
  int len = sizeof(addr);
  if(getsockname(w->listen_fd,(struct sockaddr *)&addr, &len) < 0) {
    LOG_ERROR(4,"getsockname():%s",strerror(errno));
    return -1;
  }
  w->listen_port = ntohs(addr.sin_port);
  LOG_DEBUG(4,"connect_internet_socket() Initializing worker at port %d. FD is=%d",w->listen_port, w->listen_fd);
  // TODO: Accept connections only from WebROaR
  if (listen(w->listen_fd,2) < 0) {
    perror("listen()");
    return -1;
  }
  return 0;
}

/** Connect worker on unix domain socket */
static inline int connect_unix_socket(wkr_t* w) {
  LOG_FUNCTION
  struct sockaddr_un addr;

  if ((w->listen_fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    LOG_ERROR(SEVERE,"Socket opening error:%s",strerror(errno));
    return -1;
  }

  if(setnonblock(w->listen_fd)<0) {
    LOG_ERROR(SEVERE,"Setting fd non block failed");
    return -1;
  }
  setsocketoption(w->listen_fd);
  memset(&addr, 0, sizeof(addr));
  /* Preparing socket path unique to this worker*/
  w->sock_path.str = (char*) malloc(sizeof(char)*50);
  w->sock_path.len = sprintf(w->sock_path.str, "%s_%d", Config->Worker.sock_path.str, getpid());

  LOG_DEBUG(DEBUG,"connect_unix_socket() socket name is %s",w->sock_path.str);

  addr.sun_family = AF_UNIX;
  //strcpy(addr.sun_path,w->sock_path);
  strcpy(addr.sun_path,w->sock_path.str);
  unlink(addr.sun_path);
  LOG_DEBUG(DEBUG,"connect_unix_socket() Binding worker at socket path %s",w->sock_path.str);

  int len = sizeof(addr.sun_family) + strlen(addr.sun_path);
#ifdef __APPLE__
  len ++;
#endif

  if (bind(w->listen_fd, (struct sockaddr *)&addr, len) < 0) {
    perror("bind()");
    return -1;
  }
  //LOG_DEBUG(DEBUG,"connect_unix_socket() Listening worker at socket path %s",w->sock_path);
  LOG_DEBUG(DEBUG,"connect_unix_socket() Listening worker at socket path %s",w->sock_path.str);
  /* TODO: Accept connections only from WebROaR*/
  if (listen(w->listen_fd,2) < 0) {
    perror("listen()");
    return -1;
  }
  return 0;
}


/** Connect worket to Head */
int worker_connect(wkr_t* w) {
  LOG_FUNCTION
  int retval;
  if(w->is_uds == 1) {
    retval = connect_unix_socket(w);
  }else{
    retval = connect_internet_socket(w);
  }

  if(retval >= 0 ) return send_ack_ctl_msg(w);
  
  return -1;
}

/** This function accept connection from Head. */
static void request_accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;

  if(EV_ERROR & revents) {
    LOG_ERROR(SEVERE,"request_accept_cb() got error event, returning.\n");
    return;
  }

  if(w->is_uds) {
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);
    w->req_fd = accept(watcher->fd, (struct sockaddr *)&client_addr, &client_len); 
    //TODO: accept from WebROaR Head only
  } else {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    w->req_fd = accept(watcher->fd, (struct sockaddr *)&client_addr, &client_len); 
    //TODO: accept from WebROaR Head only
  }

  if (w->req_fd < 0) {
    LOG_ERROR(SEVERE,"accept() error:%s",strerror(errno));
    return;
  }

  if (setnonblock(w->req_fd) < 0) {
    LOG_ERROR(FATAL, "failed to set client socket to non-blocking");
    return;
  }
  LOG_INFO("Successfully connected with client. Read watcher starting");
  w->w_req.data = w;
  //worker_conversation_set(w->w_conversation);
  ev_io_init(&(w->w_req), http_req_header_cb, w->req_fd, EV_READ);
  ev_io_start(loop, &(w->w_req));
}

void worker_accept_requests(wkr_t* w) {
  LOG_FUNCTION
  w->w_accept.data = w;
  ev_io_init(&(w->w_accept), request_accept_cb, w->listen_fd, EV_READ);
  ev_io_start(w->loop,&(w->w_accept));
  //wkr_tmp_free(&w->tmp);
}
