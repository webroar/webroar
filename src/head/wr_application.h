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
#ifndef WR_APPLICATION_H_
#define WR_APPLICATION_H_

#include <wr_server.h>

#define WR_MAX_PENDING_WKR 10
#define TOTAL_WORKER_COUNT(app) (app->pending_wkr + WR_QUEUE_SIZE(app->wkr_que))

typedef struct wr_req_s      wr_req_t;
typedef struct wr_wkr_s      wr_wkr_t;
//typedef struct wr_ctl_msg_s  wr_ctl_msg_t;

/** Application structure */
struct wr_app_s {
  //  wr_u_long      app_baseuri_hash;    /**< Hash value of application base uri */
  wr_u_short     pending_wkr;  /**< Total number of pending workers */
  wr_queue_t     *msg_que;      /**< Pending message queue */
  wr_queue_t     *wkr_que;      /**< List of workers */
  wr_queue_t     *free_wkr_que;  /**< List of free workers */
  wr_app_conf_t  *conf;  /**< Application configuration parameters */
  wr_app_t       *next;
  wr_svr_t       *svr;        /**< Server pointer */
  wr_ctl_t       *ctl;

  short          low_ratio;
  short          high_ratio;
  short          in_use;
  wr_u_short     last_wkr_pid[WR_MAX_PENDING_WKR];    /**< PID of the last worker */

  ev_timer       t_add;          /**< Timer to add worker */
  ev_timer       t_remove;      /**< Timer to remove worker */
  ev_timer       t_add_timeout;      /**< Timer to wait for add signal from worker */
};

/** Destroy application */
void wr_app_free(wr_app_t*);
/** Display application structure */
void wr_app_print(wr_app_t*);
/** Create worker for application */
int wr_app_wkr_add(wr_app_t*);
/** Insert application based on application configuration */
//int wr_app_insert(wr_svr_t*, wr_app_conf_t*);
/** Add request message in pending queue */
int wr_app_message_insert(wr_svr_t*, wr_req_t*);
/** Check load balance to add the worker */
int wr_app_chk_load_to_add_wkr(wr_app_t*);
/** Check load balance to remove the worker */
int wr_app_chk_load_to_remove_wkr(wr_app_t*);
/** Add newly created worker to application */
int wr_app_wrk_insert(wr_svr_t *, wr_wkr_t*, const wr_ctl_msg_t*);
/** Remove application from application list */
int wr_app_remove(wr_svr_t*, const char* app_name);
/** Initialize the applications */
void wr_app_init(wr_svr_t*);
/** Allication add callback */
void wr_app_add_cb(wr_ctl_t*, const wr_ctl_msg_t*);
/** Allication remove callback */
void wr_app_remove_cb(wr_ctl_t*, const wr_ctl_msg_t*);
/** Allication reload callback */
void wr_app_reload_cb(wr_ctl_t*, const wr_ctl_msg_t*);

/**************************/

#endif /*WR_APPLICATION_H_*/
