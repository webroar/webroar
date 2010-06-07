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
#ifndef WKR_HTTP_REQUEST_H_
#define WKR_HTTP_REQUEST_H_

#include <wr_helper.h>
#include <errno.h>
#include <ev.h>


typedef struct http_req_s    http_req_t;

/******* HTTP Request  ******/
struct http_req_s {
  char          buf[STR_SIZE10KB];    /**< Request buffer */
  size_t        bytes_read;
  scgi_t        *scgi;    /**< Parsed SCGI request */
  FILE          *file;          /**< File pointer */
  char          file_name[STR_SIZE64];      /**< File name */
  size_t        scgi_header_len;    /**< Header packet length */
  size_t        req_len;        /**< Content length */
};

http_req_t* http_req_new();
void http_req_free(http_req_t**);
void http_req_set(http_req_t*);
int http_req_body_read(http_req_t *, char *, int);
void http_req_header_cb(struct ev_loop*, struct ev_io*, int);

#endif /*WKR_HTTP_REQUEST_H_*/
