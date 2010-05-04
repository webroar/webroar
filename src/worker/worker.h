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
/******************************************************************************
 *           worker API declaration
 *****************************************************************************/

#ifndef WORKER_H_
#define WORKER_H_

#include <wkr_static.h>

typedef struct wkr_s       wkr_t;
typedef struct wkr_tmp_s   wkr_tmp_t;
typedef struct wkr_ctl_s     wkr_ctl_t;

/****** Worket temporary structure ****/
struct wkr_tmp_s {
  wr_str_t path;      /**< Application path */
  wr_str_t env;        /**< Application environment */
  wr_str_t type;      /**< Application type */
  wr_str_t name;      /**< Application name */
  wr_str_t resolver;    /**< Application baseuri */
  wr_str_t root_path;    /**< WebROaR root path */
  char    profiler;      /**< Analytics flag */
  wr_str_t ctl_path;    /**< Server control path/port */
  wr_str_t log_file;         /**< Log file name */
  wr_str_list_t *env_var;   /**< Environment variable array */
  short   gid;              /**< Process group id */
  short   uid;              /**< Process user id */
  short    keep_alive;      /**< HTTP connection keep alive flag */
  short   is_uds;
  short   is_static;        /**< Worker to serve static files only */
};

wkr_tmp_t* wkr_tmp_new();
void wkr_tmp_free(wkr_tmp_t**);

/********** Worker Control structure *********/
struct wkr_ctl_s {
  int       fd;
  ev_io      w_read;
  char      msg[STR_SIZE1KB];
  size_t    msg_size;
  size_t    bytes_read;
  ev_io     w_write;
  ev_timer  t_ack;
  //size_t    bytes_write;
  scgi_t*      scgi;
  int       error;
};

wkr_ctl_t* wkr_ctl_new();
void wkr_ctl_free(wkr_ctl_t**);
int send_ack_ctl_msg(wkr_t* w);
int send_err_ctl_msg(wkr_t* w);

/********** Worker structure *********/
struct wkr_s {
  /** Listen request from Head */
  int           listen_fd;
  int           listen_port;
  wr_str_t      sock_path;
  ev_io         w_accept;
  struct ev_loop      *loop;

  /** Request */
  int           req_fd;  /**< Socket fd */
  ev_io         w_req;  /**< watcher */
  short         is_uds;

  wkr_ctl_t     *ctl;
  wkr_tmp_t     *tmp;
  http_t        *http;
};

wkr_t* worker_new(struct ev_loop *, wkr_tmp_t*);
void worker_free(wkr_t**);
void worker_accept_requests(wkr_t*);
int worker_connect(wkr_t*);
void start_idle_watcher();
void stop_idle_watcher();
void sigproc();

#endif /*WORKER_H_*/
