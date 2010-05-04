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

#define TOTAL_WORKER_COUNT(app) (WR_QUEUE_SIZE(app->q_pending_workers) + WR_QUEUE_SIZE(app->q_workers))

typedef struct wr_req_s      wr_req_t;
typedef struct wr_wkr_s      wr_wkr_t;

typedef int wr_pending_wkr_t;

typedef enum{
  WR_APP_NEW,
  WR_APP_ACTIVE,
  WR_APP_RESTART,
  WR_APP_RESTARTING,
  WR_APP_DESTROY
}wr_app_state_t;

/** Application structure */
struct wr_app_s {

  wr_queue_t     *q_pending_workers; /**< Pending worker queue */
  wr_queue_t     *q_workers;      /**< List of workers */
  wr_queue_t     *q_free_workers;  /**< List of free workers */

  wr_queue_t     *q_messages;      /**< Pending message queue */

  config_application_list_t  *conf;        /**< Application configuration parameters */
  wr_svr_t       *svr;        /**< Server pointer */
  wr_ctl_t       *ctl;

  short          low_ratio;    /** Ratio to remove the worker */
  short          high_ratio;   /** Ratio to add the worker */

  wr_app_state_t state;       /** Application status flag */
  
  short          timeout_counter; /**< Worker add timeout counter */
  
  ev_timer       t_add;          /**< Timer to add worker */
  ev_timer       t_remove;      /**< Timer to remove worker */
  ev_timer       t_add_timeout;      /**< Timer to wait for add signal from worker */

  wr_app_t       *next;
};

/** Destroy application */
void wr_app_free(wr_app_t*);
/** Display application structure */
void wr_app_print(wr_app_t*);
/** Create worker for application */
int wr_app_wkr_add(wr_app_t*);
/** Add request message in pending queue */
int wr_app_message_insert(wr_svr_t*, wr_req_t*);
/** Check load balance to add the worker */
void wr_app_chk_load_to_add_wkr(wr_app_t*);
/** Check load balance to remove the worker */
void wr_app_chk_load_to_remove_wkr(wr_app_t*);
/** Add newly created worker to application */
int wr_app_wkr_insert(wr_svr_t *, wr_wkr_t*, const wr_ctl_msg_t*);
/** Got worker add error */
int wr_app_wkr_error(wr_svr_t *, const wr_ctl_msg_t*);
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
/** Worker added to application callback */
void wr_app_wkr_added_cb(wr_app_t *app);
/** Balance worker count for an application */
void wr_app_wkr_balance(wr_app_t *app);

/**************************/

#endif /*WR_APPLICATION_H_*/
