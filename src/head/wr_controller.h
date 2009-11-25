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
#ifndef WR_CONTROLER_H_
#define WR_CONTROLER_H_

#include<wr_worker.h>

/** Application control message structure */
typedef struct {
  wr_str_t  app_name;    /**< Application name */
}wr_app_ctl_msg_t;

/** Worker control message structure */
typedef struct {
  wr_str_t app_name;        /* Application name */
  wr_str_t uds;          /* UDS flag */
  wr_str_t port;        /* Control port */
  wr_str_t sock_path;  /* Control sock path */
  wr_str_t pid;          /* Process id */
}wr_wkr_ctl_msg_t;

/** Control Message types */
typedef enum{
  WR_CTL_MSG_NONE,
  WR_CTL_MSG_APPLICATION_RELOAD,
  WR_CTL_MSG_APPLICATION_ADD,
  WR_CTL_MSG_APPLICATION_REMOVE,
  WR_CTL_MSG_WORKER_ADD,
  WR_CTL_MSG_WORKER_REMOVE,
  WR_CTL_MSG_WORKER_PING,
  WR_CTL_MSG_TYPE_ERROR
}wr_ctl_msg_type_t;

/** Control Message */
struct wr_ctl_msg_s {
  //  wr_ctl_msg_type_t type;    // Control message type
  union{
    wr_app_ctl_msg_t app;    // Application control message
    wr_wkr_ctl_msg_t wkr;      // Worker control message
  }msg;
  //  scgi_t  *resp;    /* Control message response */
};
/*************************************************/

/******* Control ****************************/
struct wr_ctl_s {
  int                fd;              /* Control fd */
  ev_io              w_read;      /* Control request watcher */
  wr_svr_t           *svr;    /* Pointer to wr_server_t */
  wr_wkr_t           *wkr;    /* Pointer to wr_processsor_t */
  char               msg[WR_MSG_SIZE];
  size_t             ctl_nbytes;
  wr_ctl_msg_type_t  type;

  ev_io              w_write;
  scgi_t            *scgi;
  //size_t             resp_nbytes;
};
/** Create new control structure */
wr_ctl_t* wr_ctl_new(wr_svr_t*);
/** Destroy control */
void wr_ctl_free(wr_ctl_t*);
/** Initialize controller */
int wr_ctl_init(wr_svr_t*);
/** Write resonse to control signal */
void wr_ctl_resp_write(wr_ctl_t*);

/** Server Control structure */
struct wr_svr_ctl_s {
  int       fd;        /**< Control socket fd */
  int       uds;      /**< Flag for Unix Domain Socket */
  int       port;      /**< Control port */
  wr_str_t  sock_path;    /**< Control socket path */
  ev_io*     w_req;      /**< Accept worker connect request watcher */
};

/** Cleate new Server Control */
wr_svr_ctl_t* wr_svr_ctl_new();
/** Destoy Server Control */
void wr_svr_ctl_free(wr_svr_ctl_t*);

/**************************/

#endif /*WR_CONTROLER_H_*/
