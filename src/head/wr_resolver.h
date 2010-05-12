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
#ifndef WR_RESOLVER_H_
#define WR_RESOLVER_H_

#include <wr_application.h>

typedef struct wr_host_list_s   wr_host_list_t;
/** Host name resolution **/
/**
 * List keeping host name in following order
 * Full static host name
 * Host name start with '*'
 * Host name end with '*'
 * Host name start and end with '*'
 */
struct wr_host_list_s {
  config_host_list_t      *host;
  wr_app_t        *app;
  wr_host_list_t     *next;
};

/** Baseuri resolution structure */
typedef struct wr_baseuri_s    wr_baseuri_t;
struct wr_baseuri_s {
  wr_u_long     baseuri_hash;
  wr_app_t    *app;
  wr_baseuri_t *next;
};

struct wr_req_resolver_s {
  wr_host_list_t  *hosts;
  wr_baseuri_t    *baseuris;
};

wr_req_resolver_t* wr_req_resolver_new();
int wr_req_resolver_add(wr_svr_t*, wr_app_t*);
int wr_req_resolver_remove(wr_svr_t*, wr_app_t*);
int wr_req_resolve_http_req(wr_svr_t*, wr_req_t*);
void wr_req_resolver_free(wr_req_resolver_t*);

#endif /*WR_RESOLVER_H_*/
