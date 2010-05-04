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
 *                 SCGI module
 *****************************************************************************/

/**
 * Create and parse SCGI reuest
 * SCGI request are used to serialized HTTP request/response
 */

#ifndef WR_SCGI_H_
#define WR_SCGI_H_

#include <stdio.h>

#define SCGI_CONTENT_LENGTH "CONTENT_LENGTH"

typedef struct scgi_header_s scgi_header_t;

/** SCGI request type */
typedef enum scgi_type_e{
  SCGI_TYPE_NONE = 0,
  SCGI_TYPE_PARSE,
  SCGI_TYPE_BUILD
}scgi_type_t;

/** SCGI Request structure */
typedef struct{
  char *header, *body;
  size_t header_size, header_length, header_offset;
  size_t length, body_length, start_offset, bytes_sent;
  scgi_header_t *header_list;
  short index;
  scgi_type_t type;
}scgi_t;

/** SCGI Request header structure */
struct scgi_header_s {
  size_t field_offset, value_offset;
  size_t field_length, value_length;
  scgi_header_t *next;
};

/** Create new SCGI request */
scgi_t* scgi_new();

/** Add header value pair to SCGI request */
int scgi_header_add(scgi_t* scgi, const char* field, size_t field_len, const char* value, size_t value_len);

/** Add request body */
int scgi_body_add(scgi_t* scgi, const char *body, size_t length);

/** Add hedear field */
int scgi_header_field_add(scgi_t *scgi, const char *field, size_t field_len, short index);

/** Add hedear value */
int scgi_header_value_add(scgi_t *scgi, const char *value, size_t value_len, short index);

/** Add CONTENT_LENGTH field */
void scgi_content_length_add(scgi_t* scgi, size_t length);

/** Build  SCGI request */
int scgi_build(scgi_t* scgi);

/** Send SCGI request on socket */
int scgi_send(scgi_t* scgi, int fd);

/** Parse SCGI request */
scgi_t* scgi_parse(const char *buffer, size_t length);

/** Free SCGI request */
void scgi_free(scgi_t* scgi);

/** Print SCGI request */
void scgi_print(scgi_t *scgi);

/** Get header value */
const char* scgi_header_value_get(scgi_t* scgi, const char *field);

/** Get complete header */
scgi_header_t* scgi_header_get(scgi_t* scgi, const char *field);

#endif /*WR_SCGI_H_*/
