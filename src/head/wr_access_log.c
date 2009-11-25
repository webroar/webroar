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

#include <stdio.h>
#include<time.h>
#include <wr_access_log.h>

static inline  void get_date_time(char *str_time, int str_time_len) {
  struct tm   *now      =NULL;
  time_t       time_value  =0;

  time_value  = time(NULL);
  now        =localtime(&time_value);

  strftime(str_time, str_time_len, "%d/%b/%Y:%T %z", now);
}

int wr_access_log(wr_req_t* req) {

  if(!req)
    return -1;

  FILE *fp = NULL;
  fp = fopen(WR_ACCESS_LOG_FILE, "a+");

  if(fp) {
    char str_time[32];
    get_date_time(str_time, 32);
    const char *method = scgi_header_value_get(req->scgi, WR_EBB_REQ_METHOD);
    const char *uri = scgi_header_value_get(req->scgi, WR_EBB_REQ_URI);
    const char *http_version = scgi_header_value_get(req->scgi, WR_EBB_HTTP_VER);
    const char *referer = scgi_header_value_get(req->scgi, WR_REQ_REFERER);
    const char *user_agent = scgi_header_value_get(req->scgi, WR_REQ_USER_AGENT);


    fprintf(fp,"%s - - [%s] \"%s %s %s\" %d %d \"%s\" \"%s\"\r\n",
            req->conn->ebb_conn->ip ,
            str_time,
            (method?method:"-"),
            (uri?uri:"-"),
            (http_version?http_version:"-"),
            req->resp_code,
            req->resp_body_len,
            (referer?referer:"-"),
            (user_agent?user_agent:"-"));
    fclose(fp);
  } else {
    return -1;
  }

  return 0;
}
