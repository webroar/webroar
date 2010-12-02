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
#ifndef WKR_HTTP_RESPONSE_H_
#define WKR_HTTP_RESPONSE_H_

#include <wkr_http_request.h>

typedef struct http_resp_s    http_resp_t;

/******* HTTP Response  ******/
struct http_resp_s {
  wr_u_short         resp_code;
  size_t            bytes_write;
  scgi_t    *scgi;
  wr_buffer_t       *resp_body;
  int content_encoding;
  wr_str_t          header;
#ifdef _POSIX_C_SOURCE
  int              file;
#else  
  FILE              *file;
#endif
  
};

http_resp_t* http_resp_new();
void http_resp_free(http_resp_t**);
void http_resp_set(http_resp_t*);
int http_resp_process(http_resp_t*);
void http_resp_scgi_write_cb(struct ev_loop*, struct ev_io*, int);


#endif /*WKR_HTTP_RESPONSE_H_*/
