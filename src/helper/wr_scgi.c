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
 *             Implementation of SCGI module
 *****************************************************************************/

#include <wr_scgi.h>
#include <wr_string.h>
#include <stdlib.h>
#include <string.h>

#include <wr_logger.h>

#define SCGI_START_OFFSET 40
#define SCGI_CONTENT_LENGTH_LEN    14

#define SCGI_HEADER_BLOCK_SIZE 2048

/** SCGI parser states */
enum statue_e{
  STATE_INVALID = -1,
  STATE_NONE = 0,
  STATE_HEADER_LENGTH = 1,
  STATE_HEADER,
  STATE_VALUE,
  STATE_BODY,
  STATE_DONE
};

/** Create new SCGI request */
scgi_t* scgi_new(){
  scgi_t* scgi = (scgi_t*) malloc (sizeof(scgi_t));
  if(scgi){
    size_t lenght = (SCGI_HEADER_BLOCK_SIZE > (SCGI_START_OFFSET + 2) ? SCGI_HEADER_BLOCK_SIZE : (SCGI_START_OFFSET + 2));
    scgi->body = NULL;
    scgi->header = (char*) malloc(sizeof(char) * lenght);
    scgi->header_size = lenght - 2;
    scgi->header_list = NULL;
    scgi->body_length = 
    scgi->header_length =
    scgi->bytes_sent =
    scgi->length = 0;
    scgi->index = -1;
    scgi->header_offset = scgi->start_offset = SCGI_START_OFFSET;
    scgi_header_add(scgi, "SCGI", 4, "1", 1);
    scgi->type = SCGI_TYPE_NONE;
  }
  return scgi;
}

/** Check header memory */
int scgi_memory_check(scgi_t *scgi, size_t required_len){
  if(required_len > scgi->header_size){
    size_t length = scgi->header_size + SCGI_HEADER_BLOCK_SIZE;
    while(required_len > length){
      length += SCGI_HEADER_BLOCK_SIZE;
    }
    
    char *buffer = (char*) realloc(scgi->header, sizeof(char) * (length + 2));
    if(!buffer) return -1;
    scgi->header_size = length;
    scgi->header = buffer;
  }
  return 0;
}

/** Add special header value pair to SCGI request */
int scgi_header_add(scgi_t* scgi, const char* field, size_t field_len, const char* value, size_t value_len){

  if(!scgi || !field)
    return -1;
  
  scgi_header_t *header;
  size_t required_len = scgi->header_offset + field_len + value_len + 2;
  
  if(scgi_memory_check(scgi, required_len) != 0) return -1;
  
  header = (scgi_header_t*) malloc(sizeof(scgi_header_t));
  // Add field
  header->field_offset = scgi->header_offset;
  header->field_length = field_len;
  memcpy(scgi->header + scgi->header_offset, field, field_len);
  scgi->header_offset += field_len;
  scgi->header[scgi->header_offset++] = 0;
  // Add value
  header->value_offset = scgi->header_offset;
  header->value_length = value_len;
  memcpy(scgi->header + scgi->header_offset, value, value_len);
  scgi->header_offset += value_len;
  scgi->header[scgi->header_offset++] = 0;
  
  header->next = scgi->header_list;
  scgi->header_list = header;
  
  //LOG_DEBUG(DEBUG, "%s:%s", scgi->header + header->field_offset, scgi->header + header->value_offset);
  
  return 0;
}

/** Add special header content length to SCGI request */
void scgi_content_length_add(scgi_t* scgi, size_t length){
  char value[16];
  size_t value_len = sprintf(value, "%d", length);
    
  scgi->header[scgi->start_offset - 1] = 0;
  scgi->start_offset = SCGI_START_OFFSET - value_len - 1;
  memcpy(scgi->header + scgi->start_offset, value, value_len);
  scgi->header[scgi->start_offset - 1] = 0;
  scgi->start_offset -= (SCGI_CONTENT_LENGTH_LEN + 1);
  memcpy(scgi->header + scgi->start_offset, SCGI_CONTENT_LENGTH, SCGI_CONTENT_LENGTH_LEN);
}

/** Add request body */
int scgi_body_add(scgi_t* scgi, const char *body, size_t length){

  if(!body || !scgi)
    return -1;

  char *buffer = (char*) realloc(scgi->body, sizeof(char)*(scgi->body_length + length + 1));
  if(buffer){
    memcpy(buffer + scgi->body_length, body, length);
    scgi->body_length += length;
    scgi->body = buffer;
  }else{
    return -1;
  }
  
  return 0;
}

/** Add hedear field */
int scgi_header_field_add(scgi_t *scgi, const char *field, size_t field_len, short index){
  size_t i;
  if(!scgi || !field || index < scgi->index) return -1;
  if(scgi->index == index){
    if(scgi->header_list->value_offset != 0) return -1;
    if(scgi_memory_check(scgi, scgi->header_offset + field_len) != 0) return -1;
    memcpy(scgi->header + scgi->header_offset -1, field, field_len);
    i = scgi->header_offset -1;
    scgi->header_offset += field_len;
    scgi->header[scgi->header_offset -1] = 0;
    scgi->header_list->field_length += field_len;
  }else{
    scgi->index = index;
    if(scgi_memory_check(scgi, scgi->header_offset + field_len +1) != 0) return -1;
    scgi_header_t *header = (scgi_header_t*) malloc(sizeof(scgi_header_t));
    header->field_offset = scgi->header_offset;
    header->field_length = field_len;
    memcpy(scgi->header + scgi->header_offset, field, field_len);
    i = scgi->header_offset;
    scgi->header_offset += (field_len + 1);
    scgi->header[scgi->header_offset -1] = 0;
    header->value_offset = header->value_length = 0;
    header->next = scgi->header_list;
    scgi->header_list = header;
  }
  for( ; i < scgi->header_offset ; i++) {
    scgi->header[i] = (scgi->header[i]=='-' ? '_' : wr_toupper(scgi->header[i]));
  }
  return 0;
}

/** Add hedear value */
int scgi_header_value_add(scgi_t *scgi, const char *value, size_t value_len, short index){
  if(!scgi || !value || index != scgi->index) return -1;
  if(scgi->header_list->value_offset == 0){
    if(scgi_memory_check(scgi, scgi->header_offset + value_len + 1) != 0) return -1;
    scgi->header_list->value_offset = scgi->header_offset;
    memcpy(scgi->header + scgi->header_offset, value, value_len);
    scgi->header_list->value_length = value_len;
    scgi->header_offset += (value_len + 1);
    scgi->header[scgi->header_offset - 1] = 0;
  }else{
    if(scgi_memory_check(scgi, scgi->header_offset + value_len) != 0) return -1;
    memcpy(scgi->header + scgi->header_offset -1, value, value_len);
    scgi->header_list->value_length += value_len;
    scgi->header_offset += value_len;
    scgi->header[scgi->header_offset - 1] = 0;
  }
  return 0;
}

/** Build  SCGI request */
int scgi_build(scgi_t* scgi){
  char length_str[16];
  size_t length;

  if(!scgi)
    return -1;

  scgi->type = SCGI_TYPE_BUILD;
  // Add content length, if not added.
  if(scgi->start_offset == SCGI_START_OFFSET){
    scgi_content_length_add(scgi, scgi->body_length);
  }
  scgi->header_length = scgi->header_offset - scgi->start_offset;
  length = sprintf(length_str, "%d:", scgi->header_length);
  scgi->start_offset -= length;
  memcpy(scgi->header + scgi->start_offset, length_str, length);
  //scgi->header_offset ++;
  scgi->header[scgi->header_offset] = ',';
  scgi->header_offset ++;
  scgi->length = scgi->header_offset - scgi->start_offset + scgi->body_length;
  
  return 0;
}

/** Send SCGI request on socket */
int scgi_send(scgi_t* scgi, int fd){
  char *buffer;
  size_t sent, header_bytes = scgi->header_offset - scgi->start_offset;
  
  if(scgi->bytes_sent >= scgi->length) return 1;
  
  if(scgi->bytes_sent >= header_bytes){
    if(!scgi->body) return 1;
    sent = scgi->bytes_sent - header_bytes;
    buffer = scgi->body + sent;
    sent = scgi->body_length - sent;
  }else{
    buffer = scgi->header + scgi->start_offset + scgi->bytes_sent;
    sent = header_bytes - scgi->bytes_sent;
  }
  sent = send(fd, buffer, sent, 0);
  if(sent > 0) scgi->bytes_sent += sent;
  return sent;
}

/** Destroy SCGI request */
void scgi_free(scgi_t* scgi){  
  if(scgi) {
    scgi_header_t *header, *next;
    header = scgi->header_list;
    while(header){
      next = header->next;
      free(header);
      header = next;
    }
    
    if(scgi->body && scgi->type != SCGI_TYPE_PARSE) free(scgi->body);
    if(scgi->header && scgi->type != SCGI_TYPE_PARSE) free(scgi->header);
    
    free(scgi);
  }
  scgi = NULL;
}

/** Parse SCGI request */
scgi_t* scgi_parse(const char *buffer, size_t length){
  int state;
  scgi_t* scgi = NULL;
  size_t field_offset, value_offset, field_len, value_len;
  char *body = NULL;
  int i;
  
  if(length <=0 )
    return NULL;
  
  scgi = (scgi_t*) malloc (sizeof(scgi_t));
  if(!scgi)
    return NULL;
  
  scgi->body = NULL;
  scgi->header_list = NULL;
  scgi->body_length = scgi->header_length = scgi->bytes_sent =
  scgi->header_offset = scgi->start_offset = 0;
  scgi->index = -1;
  scgi->type = SCGI_TYPE_PARSE;
  
  field_len = value_len = field_offset = value_offset = 0;

  scgi->length = scgi->header_size = length;
  scgi->header = buffer;
  
  for(i = 0, state = STATE_HEADER_LENGTH; i < length; i++) {
    switch(state) {
    case STATE_HEADER_LENGTH:

      if(buffer[i] == ':') {
        scgi->header_offset = i + 1;
        state = STATE_HEADER;
        field_offset = i + 1;
      } else if(buffer[i] < '0' || buffer[i] > '9') {
        state = STATE_INVALID;
      }

      break;
    case STATE_HEADER:  // Process header state
      field_len ++;
      if(!buffer[i]) {
        state = STATE_VALUE;
        value_offset = i + 1;
      } else if(buffer[i] == ',') {
        scgi->header_length = i - scgi->header_offset;
        scgi->header_offset = i;
        if(i == length -1 )
          state = STATE_DONE;
        else {
          state = STATE_BODY;
          body = buffer + i + 1;
        }
      }
      break;
    case STATE_VALUE:  // Process value state
      value_len ++;
      if(!buffer[i]) {
        scgi_header_t *header = (scgi_header_t*) malloc (sizeof(scgi_header_t));
        field_len--; value_len--;
        header->field_offset = field_offset;
        header->field_length = field_len;
        header->value_offset = value_offset;
        header->value_length = value_len;
        header->next = scgi->header_list;
        scgi->header_list = header;
        state = STATE_HEADER;
        field_offset = i + 1;
        field_len = value_len = 0;
        //LOG_DEBUG(DEBUG, "Header %s:%s", buffer + header->field_offset, buffer + header->value_offset);
      }
      break;
    case STATE_BODY:  // Process request body
      if(i != (length - 1)) {
        scgi->body_length = buffer + length - body;
        scgi->body = body;
        i = length;
      }
      state = STATE_DONE;
      break;
    case STATE_INVALID:
      i = length;
      break;
    }
  }

  if(state == STATE_DONE) {
    return scgi;
  }

  scgi_free(scgi);
  return NULL;
}

/** Print SCGI headers */
void scgi_header_print(scgi_t *scgi, scgi_header_t *header){
  if(header){
    scgi_header_print(scgi, header->next);
    printf("%s -> %s\n", scgi->header + header->field_offset, scgi->header + header->value_offset);
  }    
}

/** Display SCGI request */
void scgi_print(scgi_t *scgi){
  if(!scgi){
    printf("SCGI request is empty.\n");
    return;
  }
  scgi_header_t *header =  scgi->header_list;
  printf("\nTotal SCGI length = %d", scgi->length);
  if(scgi->type == SCGI_TYPE_BUILD){
    size_t offset = strlen(scgi->header + scgi->start_offset) + scgi->start_offset + 1;  
    printf("\n%s -> %s\n", scgi->header + scgi->start_offset, scgi->header + offset);
  }else{
    printf("\n%d:", scgi->header_length);
  }
  
  scgi_header_print(scgi, header);
  
  printf(",");
  if(scgi->body){
      printf("\n%s", scgi->body);
  }
  printf("\n");
  
}

/** Get SCGI header value */
const char* scgi_header_value_get(scgi_t* scgi, const char *field){
  if(!scgi || !field)
    return NULL;
  
  scgi_header_t* header = scgi->header_list;
  int field_len = strlen(field);

  while(header) {
    if(field_len == header->field_length && strncmp(scgi->header + header->field_offset, field, field_len) == 0) {
      return scgi->header + header->value_offset;
    }
    header = header->next;
  }
  return NULL;
}

scgi_header_t* scgi_header_get(scgi_t* scgi, const char *field){
  if(!scgi || !field)
    return NULL;
  
  scgi_header_t* header = scgi->header_list;
  int field_len = strlen(field);

  while(header) {
    if(field_len == header->field_length && strncmp(scgi->header + header->field_offset, field, field_len) == 0) {
      return header;
    }
    header = header->next;
  }
  return NULL;
}
