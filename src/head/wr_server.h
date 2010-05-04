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
#ifndef WR_SERVER_H_
#define WR_SERVER_H_

#include <wr_configurator.h>
#include <ebb.h>

typedef struct wr_app_s           wr_app_t;
typedef struct wr_svr_ctl_s       wr_svr_ctl_t;
typedef struct wr_req_resolver_s  wr_req_resolver_t;
typedef struct wr_ctl_s           wr_ctl_t;
typedef struct wr_ctl_msg_s       wr_ctl_msg_t;

typedef void (*wr_ctl_signal_cb) (wr_ctl_t*, const wr_ctl_msg_t*);

/** Server structure */
typedef struct {
  ebb_server         ebb_svr;    /**< Ebb server */

  ebb_server         secure_ebb_svr;    /**< Ebb server */
#ifdef HAVE_GNUTLS
#endif

  wr_app_t*        apps;  /**< Application list */
  wr_app_t*        default_app;
  wr_app_t*        static_app;
  wr_svr_ctl_t*    ctl;    /**< Server control pointer */
  char             err_msg[STR_SIZE1KB];    /**< Error message */
  wr_req_resolver_t *resolver;
  short            is_running;  /**< Keep alive flag */

  /**< Callback functions */
  wr_ctl_signal_cb on_app_add;
  wr_ctl_signal_cb on_app_remove;
  wr_ctl_signal_cb on_app_reload;
  wr_ctl_signal_cb on_wkr_add;
  wr_ctl_signal_cb on_wkr_remove;
  wr_ctl_signal_cb on_wkr_ping;
  wr_ctl_signal_cb on_wkr_add_error;
}wr_svr_t;

/** Initialize Server */
int wr_svr_init(wr_svr_t**);
/** Destroy Server */
void wr_svr_free(wr_svr_t*);

#endif /*WR_SERVER_H_*/
