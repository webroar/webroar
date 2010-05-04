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
#ifndef WR_WORKER_H_
#define WR_WORKER_H_

#include <wr_resolver.h>

//typedef struct wr_ctl_s   wr_ctl_t;

/** Worker states */
typedef enum{
  WKR_STATE_CONNECTING = 100,
  WKR_STATE_ACTIVE = 200,
  WKR_STATE_INACTIVE = 201,
  WKR_STATE_PINGING = 202,
  WKR_STATE_EXPIRED = 203,
  WKR_STATE_ERROR = 401,
  WKR_STATE_TIMEDOUT = 402,
  WKR_STATE_ERROR_ACK = 403,
  WKR_STATE_HANGUP = 404,
  WKR_STATE_DISCONNECTING = 501
}wr_wkr_state_t;

/** Worker actions */
typedef enum{
  WKR_ACTION_ADD,
  WKR_ACTION_ADD_TIMEOUT,
  WKR_ACTION_ADD_ERROR,
  WKR_ACTION_REMOVE,
  WKR_ACTION_PING,
  WKR_ACTION_PING_TIMEOUT,
  WKR_ACTION_PING_REPLAY,
  WKR_ACTION_REQ_PROCESSED,
  WKR_ACTION_REQ_PROCESSING,
  WKR_ACTION_ERROR
}wr_wkr_action_t;

/** Worker states */
/*typedef enum{
  WR_WKR_CLEAR = 0,
  WR_WKR_ACTIVE = 1,    //worker is active to service an application
  WR_WKR_ERROR = 2,
  WR_WKR_CONNECTING = 4,
  WR_WKR_REMOVING = 8,
  WR_WKR_DISCONNECT = 16,
  WR_WKR_PING_SENT = 32,    //Sent PING when worker found idle for certain time
  WR_WKR_PING_REPLIED = 64,    //PING replied, indicating worker is live
  WR_WKR_HANG = 128,
  WR_WKR_OLD = 256
}wr_wkr_state_t;*/

/** Worker structure */
struct wr_wkr_s {
  wr_u_short      id;    /**< Worker index/id */
  wr_wkr_state_t  state;      /**< Worker state */
  wr_u_short      pid;    /**< Worker id */
  struct ev_loop  *loop;

  int         fd;      /**< Socket fd */
  ev_io       watcher;  /**< watcher */

  ev_timer     t_wait;   /**< idle watcher for worker */
  wr_u_short   trials_done;  /**< Number of time we want to send PING before killing */

  wr_ctl_t    *ctl;      /**< Pointer to control structure */
  wr_req_t    *req;
  wr_app_t    *app;  /**< Application pointer*/
};

/** Create new worker */
wr_wkr_t* wr_wkr_new(wr_ctl_t*);
/** Destroy worker */
void wr_wkr_free(wr_wkr_t*);
/** Remove worker */
int wr_wkr_remove(wr_wkr_t*, int);
/** Create the Worker */
int wr_wkr_create(wr_svr_t*, config_application_list_t*);
/** Dispatch the request to Worker process */
void wr_wkr_dispatch_req(wr_req_t*);
/** Handle connect request from Worker */
//int wr_wkr_connect(wr_ctl_msg_t*,  wr_ctl_t*);
/** This would get called when worker reply to PING */
//void wr_wkr_ping_reply(wr_wkr_t*);
/** Worker add callback */
void wr_wkr_add_cb(wr_ctl_t*, const wr_ctl_msg_t*);
/** Worker remove callback */
void wr_wkr_remove_cb(wr_ctl_t*, const wr_ctl_msg_t*);
/** Worker Add error callback */
void wr_wkr_add_error_cb(wr_ctl_t*, const wr_ctl_msg_t*);
/** Worker ping callback */
void wr_wkr_ping_cb(wr_ctl_t*, const wr_ctl_msg_t*);

/**************************/

#endif /*WR_WORKER_H_*/
