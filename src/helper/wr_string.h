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
#ifndef WR_STRING_H_
#define WR_STRING_H_

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "wr_macro.h"

#define wr_tolower(c)      ((c >= 'A' && c <= 'Z') ? (c | 0x20) : c)
#define wr_toupper(c)      ((c >= 'a' && c <= 'z') ? (c & ~0x20) : c)

typedef struct {
  size_t   len;
  char    *str;
}wr_str_t;

#define wr_string_is_empty(_str) _str.str == NULL
#define wr_string_new(_str,str1,_len) _str.len = _len; _str.str = (char*) malloc(sizeof(char)*(_len+1)); memcpy(_str.str, str1, _len); _str.str[_len] = 0
#define wr_string_null(_str) _str.len = 0; _str.str = NULL
#define wr_string_append(_str, str1, _len)  char *str2 =(char*) realloc(_str.str,sizeof(char)*(_str.len+_len+1));\
        if(str2){memcpy(str2+_str.len, str1, _len); _str.len+=_len;str2[_str.len]=0;_str.str=str2;}
#define wr_string_free(_str) if(_str.str) free(_str.str); _str.len = 0; _str.str = NULL
#define wr_string_dump(_str,_str1) _str.len = _str1.len;_str.str = (char*) malloc(sizeof(char)*(_str.len+1)); memcpy(_str.str, _str1.str, _str.len); _str.str[_str.len] = 0

typedef struct {
  wr_str_t  key;
  wr_str_t  value;
}wr_keyval_t;

typedef struct wr_str_arr_s    wr_str_arr_t;
struct wr_str_arr_s {
  wr_str_t      str;
  wr_str_arr_t    *next;
};

#define wr_string_arr_free(_arr)   wr_string_free(_arr->str); free(_arr)

typedef struct {
  wr_str_arr_t    *front;
  wr_str_arr_t    *rear;
  size_t        len;
}wr_str_list_t;

#define wr_string_list_is_empty(_list)  _list->front == NULL

wr_str_list_t* wr_string_list_new();
int wr_string_list_add(wr_str_list_t*,const char*, size_t);
void wr_string_list_remove(wr_str_list_t*);
void wr_string_list_free(wr_str_list_t*);

typedef struct wr_buffer_s wr_buffer_t;
struct wr_buffer_s{
  char         *str;
  size_t       len;
  size_t       size;
  wr_buffer_t  *next;
};

#define wr_buffer_new(_buf) _buf = wr_malloc(wr_buffer_t); _buf->len = _buf->size = 0; _buf->str = NULL
#define wr_buffer_create(_buf,_size) _buf->len = 0; _buf->size = _size; _buf->str = (char*) malloc(sizeof(char)*(_size+1))
#define wr_buffer_null(_buf) _buf->len = 0; if(_buf->str) free(_buf->str); _buf->str = NULL; _buf->size = 0
#define wr_buffer_add(_buf, _str, _len) memcpy(_buf->str + _buf->len, _str, wr_min(_len, _buf->size - _buf->len)); _buf->len += wr_min(_len, _buf->size-_buf->len)
#define wr_buffer_free(_buf) wr_buffer_null(_buf); free(_buf); _buf = NULL
#define wr_buffer_set_zero(_buf) memset(_buf->str, 0, _buf->size)

typedef struct {
  wr_buffer_t    *front;
  wr_buffer_t    *rear;
}wr_buffer_list_t;

#define wr_buffer_list_is_empty(_list)  _list->front == NULL

wr_buffer_list_t* wr_buffer_list_new();
int wr_buffer_list_add(wr_buffer_list_t *list, wr_buffer_t *buffer);
wr_buffer_t* wr_buffer_list_remove(wr_buffer_list_t*);
void wr_buffer_list_free(wr_buffer_list_t*);

#define file_print(file, format, ...) do { FILE *f=fopen(file,"a+"); if(f){fprintf(f, format, __VA_ARGS__); fclose(f);} } while (0)

#define file_write(file, buf, len) do { FILE *f=fopen(file,"a+"); if(f){fwrite(buf, sizeof(char), len, f); fclose(f);} } while (0)

#endif /*WRR_STRING_H_*/
