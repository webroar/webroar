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
#include <wr_request.h>
#include <sys/un.h>
#include <errno.h>

/*************** Private Functions **********************/

/**
 * Validate SCGI Control message.
 * 1) Add Worker
 *         COMPONENT: WORKER
 *         METHOD: ADD
 *         APPLICATION: /<baseuri>
 *         USD: {YES/NO}
 *         PORT: <port> or SOCK_PATH: <sock_path>
 *         PID: <pid>
 * 2) Remove Worker
 *         COMPONENT: WORKER
 *         METHOD: REMOVE
 * 3) Add Application
 *         COMPONENT: APPLICATION
 *         METHOD: ADD
 *         APP_NAME: <application name>
 *         APP_BASE_URI: <baseuri>
 *         APP_TYPE: <application type>
 *         APP_PATH: <appliaction path>
 *         APP_ANALYTICS: <analytics flag>
 *         APP_LOG_LEVEL: <logging level> (optional)
 *         APP_MIN_WORKER: <min workers> (optional)
 *         APP_MAX_WORKER: <max workers> (optional)
 * 4) Remove Application
 *         COMPONENT: APPLICATION
 *         METHOD: ADD
 **/

static inline wr_ctl_msg_t* wr_ctl_msg_validate(scgi_t* request, wr_ctl_t* ctl) {
  LOG_FUNCTION
  wr_ctl_msg_t* ctl_msg = wr_malloc(wr_ctl_msg_t);
  char *val, *val1, *val2;
  char error[WR_STR_LEN];

  ctl->type = WR_CTL_MSG_NONE;
  ctl->scgi = scgi_new();

  val = (char*) scgi_header_value_get(request,"COMPONENT");
  if(val == NULL) {
    strcpy(error,"COMPONENT missing.");
    goto ctl_msg_err;
  }
  scgi_header_add(ctl->scgi, "COMPONENT", strlen("COMPONENT"), val, strlen(val));
  if(strcmp(val,"APPLICATION")==0) {
    val = (char*) scgi_header_value_get(request,"METHOD");
    if(val == NULL) {
      strcpy(error,"METHOD missing.");
      goto ctl_msg_err;
    }
    scgi_header_add(ctl->scgi, "METHOD", strlen("METHOD"), val, strlen(val));

    ctl_msg->msg.app.app_name.str = (char*) scgi_header_value_get(request,"APP_NAME");
    if(ctl_msg->msg.app.app_name.str == NULL) {
      strcpy(error,"Application name is missing.");
      goto ctl_msg_err;
    }

    // Application Add
    if(strcmp(val,"ADD")==0) {
      ctl->type = WR_CTL_MSG_APPLICATION_ADD;
    } else if(strcmp(val,"REMOVE")==0) {
      ctl->type = WR_CTL_MSG_APPLICATION_REMOVE;
    } else if(strcmp(val,"RELOAD")==0) {
      ctl->type = WR_CTL_MSG_APPLICATION_RELOAD;
    } else {
      strcpy(error,"Invalid METHOD.");
      goto ctl_msg_err;
    }
  } else if(strcmp(val,"WORKER")==0) {
    val = (char*) scgi_header_value_get(request,"METHOD");
    if(val == NULL) {
      strcpy(error,"METHOD missing.");
      goto ctl_msg_err;
    }
    scgi_header_add(ctl->scgi, "METHOD", strlen("METHOD"), val, strlen(val));
    // Worker Add
    if(strcmp(val,"ADD")==0) {
      ctl->type = WR_CTL_MSG_WORKER_ADD;

      ctl_msg->msg.wkr.app_name.str  =   (char*) scgi_header_value_get(request,"APPLICATION");
      ctl_msg->msg.wkr.pid.str =   (char*) scgi_header_value_get(request,"PID");
      ctl_msg->msg.wkr.port.str  =   (char*) scgi_header_value_get(request,"PORT");
      ctl_msg->msg.wkr.sock_path.str  =   (char*) scgi_header_value_get(request,"SOCK_PATH");
      ctl_msg->msg.wkr.uds.str  =   (char*) scgi_header_value_get(request,"UDS");

      if(ctl_msg->msg.wkr.app_name.str == NULL ||
          ctl_msg->msg.wkr.pid.str == NULL ||
          ctl_msg->msg.wkr.uds.str == NULL) {
        strcpy(error,"Missing some headers.");
        goto ctl_msg_err;
      }

    } else if(strcmp(val,"REMOVE")==0) {
      ctl->type = WR_CTL_MSG_WORKER_REMOVE;
    } else if(strcmp(val,"PING") == 0) {
      ctl->type = WR_CTL_MSG_WORKER_PING;
    } else {
      strcpy(error,"Invalid METHOD.");
      goto ctl_msg_err;
    }
  } else {
    strcpy(error,"Invalid COMPONENT.");
    goto ctl_msg_err;
  }

  return ctl_msg;
ctl_msg_err:
  LOG_ERROR(WARN,"Error found in controller message");
  ctl->type = WR_CTL_MSG_TYPE_ERROR;
  scgi_body_add(ctl->scgi, error, strlen(error));
  scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  return ctl_msg;
}

static void wr_ctl_msg_write_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  if(EV_ERROR & revents) {
    LOG_ERROR(4,"got error event, returning.");
    return;
  }

  wr_ctl_t* ctl = (wr_ctl_t*) w->data;
  
  if(scgi_send(ctl->scgi, w->fd) <= 0){
    LOG_ERROR(4,"got error event, returning.");
    return;
  }
  
  LOG_DEBUG(DEBUG,"Sending control messag %d/%d", ctl->scgi->bytes_sent, ctl->scgi->length);
  if(ctl->scgi->bytes_sent >= ctl->scgi->length) {
    ev_io_stop(loop, w);
    scgi_free(ctl->scgi);
    ctl->scgi = NULL;
    if(ctl->type == WR_CTL_MSG_TYPE_ERROR) {
      wr_ctl_free(ctl);
    }
    /*if(control->type == WR_CTL_MSG_WORKER_PING){
      ev_io_start(loop, &control->w_read);
  }*/
  }
}

/** Process Control message */
static inline void wr_ctl_msg_process(scgi_t* request,  wr_ctl_t* ctl) {
  LOG_FUNCTION

  wr_ctl_msg_t* ctl_msg = wr_ctl_msg_validate(request, ctl);

  //  ctl->type.type = ctl_msg->type;
  //ctl->resp_nbytes = 0;
  ctl->w_write.data = ctl;
  ev_io_init(&(ctl->w_write ), wr_ctl_msg_write_cb, ctl->fd, EV_WRITE);
  int flag = 0;

  switch(ctl->type) {
  case WR_CTL_MSG_APPLICATION_ADD:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_APPLICATION_ADD");
    //    wr_ctl_msg_app_add(ctl_msg, ctl);
    if(ctl->svr && ctl->svr->on_app_add)
      ctl->svr->on_app_add(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_APPLICATION_REMOVE:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_APPLICATION_REMOVE");
    //    wr_ctl_msg_app_remove(ctl_msg, ctl);
    if(ctl->svr && ctl->svr->on_app_remove)
      ctl->svr->on_app_remove(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_APPLICATION_RELOAD:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_APPLICATION_RELOAD");
    //    wr_ctl_msg_app_reload(ctl_msg, ctl);
    if(ctl->svr && ctl->svr->on_app_reload)
      ctl->svr->on_app_reload(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_WORKER_ADD:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_WORKER_ADD");
    //    wr_ctl_msg_wkr_add(ctl_msg, ctl);
    if(ctl->svr && ctl->svr->on_wkr_add)
      ctl->svr->on_wkr_add(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_WORKER_REMOVE:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_WORKER_REMOVE");
    //    wr_ctl_msg_wkr_remove(ctl_msg, ctl);
    if(ctl->svr && ctl->svr->on_wkr_remove)
      ctl->svr->on_wkr_remove(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_WORKER_PING:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_WORKER_PING");
    //    scgi_free(ctl_msg->resp);
    //    wr_wkr_ping_reply(ctl->wkr);
    if(ctl->svr && ctl->svr->on_wkr_ping)
      ctl->svr->on_wkr_ping(ctl, ctl_msg);
    else
      flag =1;
    break;
  case WR_CTL_MSG_TYPE_ERROR:
    LOG_DEBUG(DEBUG,"WR_CTL_MSG_TYPE_ERROR");
    wr_ctl_resp_write(ctl);
    break;
  }
  if(flag) {
    LOG_DEBUG(DEBUG,"Operation not handled.");
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    scgi_body_add(ctl->scgi,"Operation not handled.",strlen("Operation not handled."));
    wr_ctl_resp_write(ctl);
  }
  scgi_free(request);

  free(ctl_msg);
}

/** Read and handle data sent by control port of Workers*/
static void wr_ctl_msg_read_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_ctl_t* ctl = (wr_ctl_t*) w->data;

  if(EV_ERROR & revents) {
    LOG_ERROR(4,"got error event, returning.");
    return;
  }

  //Read data
  int bytesRead = recv(w->fd,
                       ctl->msg + ctl->ctl_nbytes,
                       WR_MSG_SIZE - ctl->ctl_nbytes,
                       0);

  if(bytesRead <= 0 && ctl && ctl->svr && ctl->svr->is_running) {
    LOG_ERROR(WARN,"Error receiving contol message port or socket path:%s, fd = %d, bytesRead=%d",strerror(errno), w->fd, bytesRead);
    if(ctl->wkr) {
      ctl->wkr->state += (WR_WKR_ERROR + WR_WKR_HANG);
    }
    wr_ctl_free(ctl);
    return;
  }
  ctl->ctl_nbytes += bytesRead;

  scgi_t* request = NULL;
  request = scgi_parse(ctl->msg, ctl->ctl_nbytes);
  if(request == NULL ) {
    LOG_ERROR(SEVERE,"Cannot parse control message.");
    return;
  }

/*
  if(atoi(request->header->value) > request->request_body_len) {
    return;
  }
*/

  wr_ctl_msg_process(request, ctl);
  //ctl->msg_size =
  ctl->ctl_nbytes = 0;
}

/**
 * This function accept connection from worker.
 * We need to change it to keep detail of each worker. Currently it is maintaining only latest worker connected.
 * Its prone produce bug.
 */
static void wr_ctl_accept_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_svr_t* server = (wr_svr_t*) w->data;
  wr_ctl_t* ctl = NULL;

  if(EV_ERROR & revents) {
    LOG_ERROR(4,"got error event, returning.\n");
    return;
  }

  int client_fd;
  if(server->ctl->uds) {
    //Accept connection from Internet socket
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    client_fd = accept(w->fd, (struct sockaddr *)&client_addr, &client_len);
  } else {
    //Accept connection using UNIX domain socket
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);
    client_fd = accept(w->fd, (struct sockaddr *)&client_addr, &client_len);
  }

  if (client_fd == -1) {
    LOG_ERROR(SEVERE,"accept error:%s.",strerror(errno));
    return;
  }

  //Create new Controller
  ctl = wr_ctl_new(server);
  if(!ctl) {
    LOG_ERROR(SEVERE,"Memory allocation error.");
    return;
  }

  ctl->fd = client_fd;


  LOG_DEBUG(DEBUG,"Accepted connection with worker. client->fd =%d",client_fd);
  if (setnonblock(client_fd) < 0) {
    LOG_ERROR(5, "Failed to set client socket to non-blocking");
    return;
  }
  LOG_INFO("Successfully connected with controller client. Read watcher starting...");

  //Start control read watcher
  ctl->w_read.data = ctl;

  ev_io_init(&(ctl->w_read),wr_ctl_msg_read_cb,client_fd,EV_READ);
  ev_io_start(loop,&(ctl->w_read));
}

/** Start listening for Workers connect request on Internet socket */
static inline int wr_ctl_init_on_inet_sock(wr_svr_t *server) {
  LOG_FUNCTION
  struct linger ling = {
                         0, 0
                       };
  struct sockaddr_in addr;
  int flags = 1, len;

  if ((server->ctl->fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    perror("socket()");
    return -1;
  }
  LOG_DEBUG(DEBUG,"FD for controller_fd is %d",server->ctl->fd);
  if(setnonblock(server->ctl->fd) < 0) {
    LOG_ERROR(SEVERE,"Setting controller_fd non-block failed:%s",strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }
  setsocketoption(server->ctl->fd);

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = 0; //bind to an ephemeral port
  addr.sin_addr.s_addr = htonl(INADDR_ANY);

  if(bind(server->ctl->fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    LOG_ERROR(SEVERE,"bind():%s",strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }

  //determine port to which listen_fd bound
  len = sizeof(addr);
  if(getsockname(server->ctl->fd,(struct sockaddr *)&addr, &len) < 0) {
    LOG_ERROR(4,"getsockname():%s",strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }
  server->ctl->port = ntohs(addr.sin_port);
  FILE *tmp_sock = fopen(WR_TMP_SOCK_FILE,"w");
  if(tmp_sock) {
    fprintf(tmp_sock,"%d", server->ctl->port);
    fclose(tmp_sock);
  }

  //determine port to which controller_fd bound
  LOG_DEBUG(4,"Initializing controller on port %d, FD is=%d",server->ctl->port,server->ctl->fd);

  if(listen(server->ctl->fd, WR_REQ_CONN_POOL) < 0 )// TODO: Accept connections only from workers
  {
    LOG_ERROR(SEVERE,"listen error on port=%d:%s",server->ctl->port,strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }
  return 0;
}

/** Start listening for Workers connect request on UNIX domain socket */
static inline int wr_ctl_init_on_uds(wr_svr_t *server) {
  LOG_FUNCTION
  struct sockaddr_un addr;
  char sock_path[WR_LONG_STR_LEN];

  if ((server->ctl->fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    LOG_ERROR(SEVERE,"Socket opening error:%s",strerror(errno));
    return -1;
  }
  LOG_DEBUG(DEBUG,"Setting non block mode:controller_fd=%d",server->ctl->fd);
  if(setnonblock(server->ctl->fd) < 0) {
    LOG_ERROR(SEVERE,"Setting controller_fd non-block failed:%s",strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }

  setsocketoption(server->ctl->fd);

  /* Preparing unique controller socket path*/
  pid_t pid=getpid();
  char pid_str[WR_SHORT_STR_LEN];
  sprintf(sock_path,"%s_%d",WR_CTL_SOCK_PATH,pid);
  size_t len = strlen(sock_path);

  wr_string_new(server->ctl->sock_path, sock_path, len);

  FILE *tmp_sock = fopen(WR_TMP_SOCK_FILE,"w");
  if(tmp_sock) {
    fprintf(tmp_sock,"%s", server->ctl->sock_path.str);
    fclose(tmp_sock);
  }

  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path,server->ctl->sock_path.str);
  unlink(addr.sun_path);
  len = sizeof(addr.sun_family) + strlen(addr.sun_path);

#ifdef __APPLE__
  len ++;
#endif

  LOG_DEBUG(4,"About to bind..socket path = %s",addr.sun_path);
  if(bind(server->ctl->fd, (struct sockaddr *)&addr, len) < 0) {
    LOG_ERROR(SEVERE,"bind() error on socket path=%s:%s",server->ctl->sock_path.str,strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }
  LOG_DEBUG(4,"Getting ready to listen on socket path=%s",addr.sun_path);
  if(listen(server->ctl->fd, WR_CTL_CONN_POOL) < 0) // TODO: Accept connections only from workers
  {
    LOG_ERROR(SEVERE,"listen() error on socket path=%s:%s",server->ctl->sock_path.str,strerror(errno));
    close_fd(server->ctl->fd);
    return -1;
  }
  return 0;
}


/********************************************************
 *     Control Function Definition                *
 ********************************************************/
wr_ctl_t* wr_ctl_new(wr_svr_t* server) {
  LOG_FUNCTION
  wr_ctl_t* ctl = wr_malloc(wr_ctl_t);
  if(ctl == NULL) {
    LOG_DEBUG(SEVERE, "Error Control object allocation failed. Returning ... ");
    return NULL;
  }
  ctl->svr = server;
  ctl->w_read.active = 0;
  ctl->wkr = NULL;
  ctl->ctl_nbytes = 0;
  //ctl->msg_size = 0;
  ctl->fd = -1;
  return ctl;
}

void wr_ctl_free(wr_ctl_t* ctl) {
  LOG_FUNCTION
  LOG_DEBUG(4,"fd = %d ",ctl->fd);
  if(ctl) {
    if(ctl->fd > 0) {
      LOG_DEBUG(DEBUG, "closing fd()");
      close(ctl->fd);
    }
    if(ctl->w_read.active) {
      LOG_DEBUG(DEBUG,"stopping read watcher");
      ev_io_stop(ctl->svr->ebb_svr.loop, &ctl->w_read);
    }
    if(ctl->wkr) {
      wr_wkr_t *worker = ctl->wkr;
      // Need to stop ev_io so that all the pending call related to worker turns out to void
      if(worker->watcher.active != 0) {
        ev_io_stop(worker->ctl->svr->ebb_svr.loop, &worker->watcher);
      }
      worker->ctl = NULL;
      //if head is waiting for PING reply, and worker got killed inbetween, we need to stop time watcher
      ev_timer_stop(worker->loop, &worker->t_wait);
      //wr_recreate_worker(worker);
      wr_req_t * req = worker->req;
      //we are killing worker in mid of some processing, render 500 to corresponding req
      if(req) {
        LOG_ERROR(SEVERE,"Worker %d Hangup. Killing it. Req id = %d, Connection id = %d, Request Path is %s",
                  worker->id,
                  req->id, req->conn->id, req->req_uri.str);
        req->resp_buf_len = 0;
        wr_conn_err_resp(req->conn, WR_HTTP_STATUS_500);

      }
      wr_app_t *app = worker->app;
      LOG_ERROR(SEVERE,"wr_ctl_free: Remove worker with pid %d.", ctl->wkr->pid);
      if(ctl->wkr->state & WR_WKR_ACTIVE)
        wr_wkr_remove(ctl->wkr, 1);
      else
        wr_wkr_free(ctl->wkr);

      //create new worker if required
      if(app && app->in_use &&
          (TOTAL_WORKER_COUNT(app) < app->conf->min_worker ||
           app->msg_que->q_count > app->high_ratio ) ) {
        wr_app_wkr_add(app);
      }
    }
    free(ctl);
  }
}

/** Initialize controller */
int wr_ctl_init(wr_svr_t* server) {
  LOG_FUNCTION
  int rv;

  /* Start listening for workers control */
  server->ctl->uds = server->conf->uds;

  if(server->ctl->uds) {
    // Start listening on UNIX domain socket
    rv = wr_ctl_init_on_uds(server);
    if(rv < 0) {
      LOG_ERROR(SEVERE,"Controller initialization failed.");
      wr_string_free(server->ctl->sock_path);
      return rv;
    }
  } else {
    // Start listening on Internet socket
    rv = wr_ctl_init_on_inet_sock(server);
    if(rv < 0) {
      LOG_ERROR(SEVERE,"Controller initialization failed.");
      return rv;
    }
  }

  //Initialize worker accept watcher
  server->ctl->w_req = wr_malloc(ev_io);
  server->ctl->w_req->data = server;
  ev_io_init(server->ctl->w_req ,wr_ctl_accept_cb, server->ctl->fd,EV_READ);
  ev_io_start(server->ebb_svr.loop,server->ctl->w_req);
  return 0;
}

/********************************************************/

/************** Server controler definition **********/
/** Create Server Control object */
wr_svr_ctl_t* wr_svr_ctl_new() {
  LOG_FUNCTION
  wr_svr_ctl_t* ctl = wr_malloc(wr_svr_ctl_t);
  if(!ctl) {
    LOG_ERROR(WARN,"control object allocation failed. Returning ...");
    return NULL;
  }

  ctl->fd = -1;
  ctl->port = -1;
  wr_string_null(ctl->sock_path);
  ctl->w_req = NULL;
  ctl->uds = -1;

  return ctl;
}

/** Destroy Server control object */
void wr_svr_ctl_free(wr_svr_ctl_t *ctl) {
  LOG_FUNCTION
  if(ctl->fd > 0)
    close(ctl->fd);
  if(ctl->w_req)
    free(ctl->w_req);

  if(ctl->sock_path.str) {
    unlink(ctl->sock_path.str);
    wr_string_free(ctl->sock_path);
  }
  free(ctl);
}

void wr_ctl_resp_write(wr_ctl_t *ctl) {
  LOG_FUNCTION
  if(ctl->scgi) {
    scgi_build(ctl->scgi);
    LOG_DEBUG(DEBUG,"sending control signal response");
    ev_io_start(ctl->svr->ebb_svr.loop, (&ctl->w_write));
  }
}

/**********************************************************/
