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
#ifndef WR_ACCESS_LOG_H_
#define WR_ACCESS_LOG_H_

#define WR_ACCESS_LOG_FILE      "/var/log/webroar/access.log"
#define WR_REQ_USER_AGENT     "HTTP_USER_AGENT"
#define WR_REQ_REFERER       "HTTP_REFERER"

#include <wr_request.h>

int wr_access_log(wr_req_t*);


#endif /*WR_ACCESS_LOG_H_*/
