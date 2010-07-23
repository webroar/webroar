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
#ifndef WKR_STATIC_H_
#define WKR_STATIC_H_

#include <wkr_http_response.h>
#if defined(W_ZLIB) && defined(W_REGEX)
#include <regex.h>
#endif

#define MAP_SIZE 36
#define DEFAULT_CONTENT_TYPE "javascript|css|xml|text"

typedef struct static_file_s{
    char ext[10];
    char mime_type[50];
    long int expires;
    struct static_file_s *next;
}static_file_t;

typedef struct static_server_s{
  struct stat     buf;
  const char      *path, *encoding, *user_agent, *modify;
  wr_buffer_t     *buffer;  // Buffer to
  static_file_t   *map[MAP_SIZE + 1];
#if defined(W_ZLIB) && defined(W_REGEX) 
  regex_t         *r_user_agent, *r_content_type;
#endif
}static_server_t;

static_server_t * static_server_new(void *worker);
void static_server_free(static_server_t *stat);

/* Serve the static file content */
void static_file_process(void *http);

#endif /*WKR_STATIC_H_*/
