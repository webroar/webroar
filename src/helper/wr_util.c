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
 *           Utility function implementation
 *****************************************************************************/

#include <wr_util.h>

#include <string.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <fcntl.h>
#include <wr_logger.h>
#include <time.h>

#define HEX2DEC(c) ((c >= '0' && c <= '9') ? (c - '0') : \
                   ((c >= 'a' && c <= 'f') ? (c -'a' + 10) : \
                   (c - 'A' + 10)))

/** Set socket fd to nonblocking mode */
int setnonblock(int fd) {
  int flags;

  flags = fcntl(fd, F_GETFL);
  if (flags < 0)
    return flags;
  flags |= O_NONBLOCK;
  if (fcntl(fd, F_SETFL, flags) < 0)
    return -1;

  return 0;
}

/** Set socket opetions */
void setsocketoption(int fd) {
  int flags = 1;
  struct linger ling = {
                         0, 0
                       };
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *)&flags, sizeof(flags));
  setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (void *)&flags, sizeof(flags));
  setsockopt(fd, SOL_SOCKET, SO_LINGER, (void *)&ling, sizeof(ling));
  setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (void *)&flags, sizeof(flags));
}

/** Close socket fd */
void close_fd(int fd) {
  if(fd>0)
    close(fd);
}

/** Create URI hash using djb2 string hash function*/
/** http://www.cse.yorku.ca/~oz/hash.html */
unsigned long uri_hash(char *str) {
  unsigned long hash = 5381;
  int c;
  c = *str++;
  while (c != 0 && c != '/') {
    hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    c = *str++;
  }
  return hash;
}

/** Create URI hash based on length */
unsigned long uri_hash_len(char *str, int length) {
  unsigned long hash = 5381;
  int i;
  for( i = 0; i < length && str[i] != 0 && str[i] != '/' ; i++) {
    hash = ((hash << 5) + hash) + str[i]; /* hash * 33 + c */
  }
  return hash;
}

/** Decode the URI */
/**
 * Function take pointer to a string, and returns new unescaped string
 * Unescaping is done according to rfc2396), some character is encoded as character triplet, 
 * containing percent character(%) followed by two hexadecimal digits representating that character.
 * Decoding %xy by x*16+y
 */
wr_str_t uri_decode(char *s, size_t len) {
  char *t;
  wr_str_t decoded_str;
  int x = 0, y = 0;

  wr_string_new(decoded_str, s, len);
  t = decoded_str.str;

  while ( *s && (*s)!= '?' ) {
    if (*s == '%') {
      if (x = *(++s)) {
        if (y = *(++s)) {
          *(t++) = ((HEX2DEC(x) << 4) | HEX2DEC(y));
          s++;
        }
      }
    }else {
      *(t++) = *(s++);
    }
  }
  *t = '\0';
  decoded_str.len = strlen(decoded_str.str);
  return decoded_str;
}

/** Get current date */
time_t get_time(char *date, size_t len){
  time_t t = time(NULL);
  if(date){
    strftime(date, len, "%a, %d %b %Y %H:%M:%S %Z", gmtime(&t));
  }
  return t;
}

/** Convert HTTP date into C time_t structure */
time_t httpdate_to_c_time(const char *httpdate){
  struct tm tm_info;
  
  if (!strptime(httpdate, "%A, %d %B %Y %H:%M:%S", &tm_info)) {
    //LOG_DEBUG(DEBUG,"Counld not parse httpdate %s.", httpdate);
    return -1;
  }
  return mktime(&tm_info);
}

/** Convert C 'time_t' to HTTP date */
void time_to_httpdate(time_t time, char *date, size_t len){
  if(date){
    strftime(date, len, "%a, %d %b %Y %H:%M:%S %Z", gmtime(&time));
  }
}

int get_timestamp(char *str) {
  LOG_FUNCTION
  struct tm *tm_struct = NULL;
  time_t time_value = 0;
  time_value = time(NULL);
  tm_struct = localtime(&time_value);
  if(tm_struct == NULL) {
    LOG_ERROR(SEVERE, "Error detected in localtime()");
    return -1; 
  }  
  sprintf(str, "%d-%d-%d-%d-%d-%d", tm_struct->tm_year + 1900, tm_struct->tm_mon, tm_struct->tm_mday, tm_struct->tm_hour, tm_struct->tm_min, tm_struct->tm_sec);  
  return 0;
}
