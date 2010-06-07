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
#ifndef WKR_HTTP_H_
#define WKR_HTTP_H_

#include <wkr_static.h>


typedef struct http_s    http_t;

/******* HTTP structure *********/
struct http_s {
  void          *wkr;
  http_req_t      *req;
  http_resp_t     *resp;
  static_server_t *stat;

#ifdef L_DEBUG
  wr_u_int       conn_id;
  wr_u_int       req_id;
#endif
};

http_t* http_new(void *worker);
void http_free(http_t**);
void http_req_process();

#endif /*WKR_HTTP_H_*/
