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
#include <wr_string.h>
#include <wr_macro.h>

/** Create new string list */
wr_str_list_t* wr_string_list_new() {
  wr_str_list_t  *list = wr_malloc(wr_str_list_t);
  if(list) {
    list->front = NULL;
    list->rear = NULL;
    list->len = 0;
    return list;
  }
  return NULL;
}

/** Append string to String list */
int wr_string_list_add(wr_str_list_t* list,const char* str, size_t len) {
  wr_str_arr_t* arr = wr_malloc(wr_str_arr_t);
  if(arr == NULL)
    return -1;

  wr_string_new(arr->str, str, len);
  arr->next = NULL;
  list->len += len;
  if(list->front == NULL) {
    list->front = list->rear = arr;
  } else {
    list->rear->next = arr;
    list->rear = arr;
  }
  return 0;
}

/** Fetch string from String list */
void wr_string_list_remove(wr_str_list_t *list) {
  if(list && list->front) {
    wr_str_arr_t* arr = list->front;
    list->front = list->front->next;
    list->len -= arr->str.len;
    if(list->front == NULL) {
      list->rear = NULL;
    }
    wr_string_arr_free(arr);
    arr = NULL;
  }
}

void wr_string_list_free(wr_str_list_t *list) {
  if(list) {
    wr_str_arr_t* arr = list->front, *next;
    while(arr) {
      next = arr->next;
      wr_string_arr_free(arr);
      arr = next;
    }
    list->front = list->rear = NULL;
    list->len = 0;
    free(list);
  }
}

/** Create buffer list */
wr_buffer_list_t* wr_buffer_list_new(){
  wr_buffer_list_t  *list = wr_malloc(wr_buffer_list_t);
  if(list) {
    list->front = NULL;
    list->rear = NULL;
  }
  return list;
}

/** Add buffer into buffer list */
int wr_buffer_list_add(wr_buffer_list_t *list, wr_buffer_t *buffer){
  if(buffer == NULL)
    return -1;

  buffer->next = NULL;
  if(list->front == NULL) {
    list->front = list->rear = buffer;
  } else {
    list->rear->next = buffer;
    list->rear = buffer;
  }
  return 0; 
}

/** Fetch buffer from buffer list */
wr_buffer_t* wr_buffer_list_remove(wr_buffer_list_t *list){
  if(list && list->front) {
    wr_buffer_t* buffer = list->front;
    list->front = list->front->next;
    if(list->front == NULL) {
      list->rear = NULL;
    }
    return buffer;
  }
  return NULL;
}

/** Free buffer list */
void wr_buffer_list_free(wr_buffer_list_t *list){
   if(list) {
    wr_buffer_t* buffer = list->front, *next;
    while(buffer) {
      next = buffer->next;
      wr_buffer_free(buffer);
      buffer = next;
    }
    list->front = list->rear = NULL;
    free(list);
  }
}
