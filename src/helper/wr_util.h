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
/******************************************************************************
 *                 Utility Functions
 *****************************************************************************/
/**
 * Small utility functions are declared here
 */

#ifndef WR_UTIL_H_
#define WR_UTIL_H_

#include <wr_string.h>
#include <time.h>

void close_fd(int fd);
void setsocketoption(int fd);
int setnonblock(int fd);

unsigned long uri_hash(char *str);
unsigned long uri_hash_len(char *str, int length);
int get_timestamp(char *);

/** Decode the URI */
wr_str_t uri_decode(char*, size_t);

/** Get current date */
time_t get_time(char *date, size_t len);

/** Convert C 'time_t' to HTTP date */
void time_to_httpdate(time_t time, char *date, size_t len);

/** Convert HTTP Date to C 'time_t' */
time_t httpdate_to_c_time(const char *httpdate);

#define URI_HASH_LEN(str, length, hash) do {\
  hash = 5381;\
  int i;\
  for( i = 0; i < length && str[i] != 0 && str[i] != '/' ; i++){\
    hash = ((hash << 5) + hash) + str[i]; /* hash * 33 + c */\
  } } while(0);

#endif //WR_UTIL_H_
