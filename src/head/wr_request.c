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
#include <wr_request.h>

// Reqeust count
static unsigned int wr_req_count = 0;
#define HTTP_PREFIX "HTTP_"
#define HTTP_PREFIX_LEN 5

/** Private function */

/** HTTP header received */
/**
 * Request chunks are coming into parts and libebb is operating on only current chunk and agnostic about any previous
 * chunk. Due to this we may get partial value of request header key, and header value. So it may give more than one
 * callback for the same header with partial value each time. It is our responsibility to keep trac of any such header.
 */


static inline int wr_req_path_set(wr_req_t *req) {
  LOG_FUNCTION
  // terminate request uri with 'null' character

  if(req->req_path.len) {
    // Request path is present (not absolute request uri)
    if(scgi_header_value_get(req->scgi, "HTTP_HOST") == NULL) {
      LOG_DEBUG(DEBUG,"Host is missing");
      req->resp_buf_len = sprintf(req->resp_buf,"%s","The request host is missing.");
      wr_req_invalid(req->conn, WR_HTTP_STATUS_400);
      return -1;
    }

    req->req_path.str = req->req_uri.str;
    if(req->req_query_str.len) {
      req->req_query_str.str = req->req_uri.str +  req->req_path.len +1;
    }
  } else if(req->req_uri.len) {
    /** Set request path and query string in case of absolute request uri.
     * libebb does not give on_request_path and on_query_string call back if request uri is absolure uri
     */
    // Set query string
    req->req_query_str.str = strstr(req->req_uri.str,"?");
    if(req->req_query_str.str) {
      req->req_query_str.str ++;
      req->req_query_str.len = req->req_uri.len - (req->req_query_str.str-req->req_uri.str);
    }

    // Check Query String length
    if(req->req_query_str.len > WR_MAX_REQ_QRY_STR_LEN) {
      LOG_DEBUG(DEBUG,"query str len = %d", req->req_query_str.len);
      req->resp_buf_len = sprintf(req->resp_buf,"%s","The request query string is too large.");
      wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
      return -1;
    }

    // Set host and request path
    size_t host_len;
    char *ptr = strstr(req->req_uri.str,"://");
    if(ptr) {
      ptr += 3;

      // Set request path
      req->req_path.str = strstr(ptr,"/");
      if(req->req_path.str) {
        host_len = req->req_path.str - ptr;

        if(req->req_query_str.str) {
          req->req_path.len = req->req_query_str.str - req->req_path.str -1;
        } else {
          req->req_path.len = req->req_uri.len - (req->req_path.str - req->req_uri.str);
        }

        // Check request path length
        if(req->req_path.len > WR_MAX_REQ_PATH_LEN) {
          LOG_DEBUG(DEBUG,"req path len = %d", req->req_path.len);
          req->resp_buf_len = sprintf(req->resp_buf,"%s","The request path is too large.");
          wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
          return -1;
        }
      } else {
        host_len = req->req_uri.len - (ptr - req->req_uri.str);
      }

      // Replace 'Host' header if it exist or add new 'Host' header
      wr_str_t host;
      wr_string_new(host, ptr, host_len);
      LOG_DEBUG(DEBUG,"Host = %s", host.str);
      // If HTTP_HOST is already present in the request, hide it by replacing with TTTP_HOST
      scgi_header_t *header = scgi_header_get(req->scgi, "HTTP_HOST");
      if(header){
        req->scgi->header[header->field_offset] = 'T';
      }
      // Add new HTTP_HOST header
      scgi_header_add(req->scgi, "HTTP_HOST", strlen("HTTP_HOST"), ptr, host_len);
    }

    // Drop host length from request uri lenght. Host is not passed to worker with request_uri
    req->req_uri.len = req->req_path.len + (req->req_query_str.len?req->req_query_str.len+1:0);
  }
  return 0;
}

/*
static inline void wr_req_header_add(wr_req_t * req) {
  int i = 5;

  if(req->scgi->request_headers_len+1 > WR_MAX_REQ_HEADER_LEN) {
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The number of request headers is too large.");
    wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
    return;
  }

  for( ; i < req->tmp_header.len ; i++) {
    req->tmp_header.str[i] = (req->tmp_header.str[i]=='-' ? '_' : wr_toupper(req->tmp_header.str[i]));
  }

  LOG_DEBUG(DEBUG, "%s() header=%s, value=%s", __FUNCTION__, req->tmp_header.str, req->tmp_value.str);

  scgiUEST_HEADER_SET(req->scgi,
                          req->tmp_header.str, req->tmp_header.len,
                          req->tmp_value.str, req->tmp_value.len);



  wr_string_null(req->tmp_value);
  wr_string_null(req->tmp_header);
}
*/

static int wr_req_header_length_check(wr_req_t *req, size_t length, int index){
  // Check no. of headers
  if(index >= WR_MAX_REQ_HEADER_NO) {
    req->resp_buf_len = sprintf(req->resp_buf, "%s", "The number of request header is too large.");
    return WR_HTTP_STATUS_413;
  }
  
  // Check field length
  if(req->scgi->index == index){
    if(req->scgi->header_list->field_length + length >  WR_MAX_REQ_FIELD_NAME_LEN){
      LOG_DEBUG(DEBUG,"header len = %d", req->scgi->header_list->field_length);
      req->resp_buf_len = sprintf(req->resp_buf, "%s", "The request field name is too large.");
      return WR_HTTP_STATUS_413;
    }
  }else{
    if((length + 5) > WR_MAX_REQ_FIELD_NAME_LEN){
      LOG_DEBUG(DEBUG,"header len = %d", length + 5);
      req->resp_buf_len = sprintf(req->resp_buf, "%s", "The request field name is too large.");
      return WR_HTTP_STATUS_413;
    }else{
      // Add 'HTTP_' prefix with each headers
      scgi_header_field_add(req->scgi, HTTP_PREFIX, HTTP_PREFIX_LEN, index);
    }
  }
  
  // Check request size
  if((req->scgi->header_offset + length) > WR_MAX_REQ_HEADER_LEN) {
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The request is too large.");
    return WR_HTTP_STATUS_413;
  }
  return 0;
}

void wr_req_header_field_cb(ebb_request* request, const char *at, size_t length, int header_index) {
  wr_req_t* req = (wr_req_t*) request->data;
  short status = wr_req_header_length_check(req, length, header_index);

  if(status != 0){
    wr_req_invalid(req->conn, status);
    return;
  }
  
  scgi_header_field_add(req->scgi, at, length, header_index);
 
  LOG_DEBUG(DEBUG,"field name = %s",req->scgi->header + req->scgi->header_list->field_offset);
}

static int wr_req_header_value_check(wr_req_t *req, size_t length, int index){
  // Check value length
  if(req->scgi->index == index){
    if(req->scgi->header_list->value_length + length >  WR_MAX_REQ_FIELD_VALUE_LEN){
      LOG_DEBUG(DEBUG,"value len = %d", req->scgi->header_list->value_length);
      req->resp_buf_len = sprintf(req->resp_buf, "%s", "The request field value is too large.");
      return WR_HTTP_STATUS_413;
    }
  }else{
    if(length > WR_MAX_REQ_FIELD_VALUE_LEN){
      LOG_DEBUG(DEBUG,"value len = %d", length + 5);
      req->resp_buf_len = sprintf(req->resp_buf, "%s", "The request field value is too large.");
      return WR_HTTP_STATUS_413;
    }
  }
  
  // Check request size
  if((req->scgi->header_offset + length) > WR_MAX_REQ_HEADER_LEN) {
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The request is too large.");
    return WR_HTTP_STATUS_413;
  }
  return 0;
}

/** Header value received */
void wr_req_header_value_cb(ebb_request* request, const char *at, size_t length, int header_index) {
  wr_req_t* req =(wr_req_t*) request->data;
  short status = wr_req_header_value_check(req, length, header_index);
  
  if(status != 0){
    wr_req_invalid(req->conn, status);
    return;
  }
  
  scgi_header_value_add(req->scgi, at, length, header_index);
  
  LOG_DEBUG(DEBUG,"field value = %s",req->scgi->header + req->scgi->header_list->value_offset);
}

/** HTTP Request path received */
void wr_req_path_cb(ebb_request* request, const char *at, size_t length) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;
  req->req_path.len += length;

  // Check request path length
  if(req->req_path.len > WR_MAX_REQ_PATH_LEN) {
    LOG_DEBUG(DEBUG,"req path len = %d", req->req_path.len);
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The request path is too large.");
    wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
    return;
  }
}

/** Query string received */
void wr_query_string_cb(ebb_request* request, const char *at, size_t length) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;
  req->req_query_str.len += length;

  // Check query string size
  if(req->req_query_str.len > WR_MAX_REQ_QRY_STR_LEN) {
    LOG_DEBUG(DEBUG,"query str len = %d", req->req_query_str.len);
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The request query string is too large.");
    wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
    return;
  }
}

/** Request URI received */
void wr_req_uri_cb(ebb_request* request, const char *at, size_t length) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;

  if(req->req_uri.len + length > WR_MAX_REQ_URI_LEN) {
    LOG_DEBUG(DEBUG,"req uri len = %d",__FUNCTION__, req->req_uri.len);
    req->resp_buf_len = sprintf(req->resp_buf,"%s","The request URI is too large.");
    wr_req_invalid(req->conn, WR_HTTP_STATUS_414);
    return;
  }

  if(wr_string_is_empty(req->req_uri)) {
    wr_string_new(req->req_uri, at, length);
  } else {
    wr_string_append(req->req_uri, at, length);
  }
}

/** Request fragment received */
void wr_req_fragment_cb(ebb_request* request, const char *at, size_t length) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;

  // Check request path length
  LOG_DEBUG(DEBUG,"Fragment length = %d", req->req_fragment.len + length);
  if((req->req_fragment.len + length) > WR_MAX_REQ_FRAG_LEN) {
    LOG_DEBUG(DEBUG,"req fragment len = %d", length);
    req->resp_buf_len = sprintf(req->resp_buf, "%s", "The request fragment is too large.");
    wr_req_invalid(req->conn, WR_HTTP_STATUS_413);
    return;
  }
  
  if(wr_string_is_empty(req->req_fragment)) {
    wr_string_new(req->req_fragment, at , length);
  }else{
    wr_string_append(req->req_fragment, at, length);
  }
}

/** Request body received */
void wr_req_body_cb(ebb_request* request, const char *at, size_t length) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;

  if(length > 0) {
    // Add request body into wr_req
    wr_req_body_add(req, at, length);
  }
}

/** HTTP request headers completed */
void wr_headers_complete_cb(ebb_request * request) {
  LOG_FUNCTION
  wr_req_t* req =(wr_req_t*) request->data;
  wr_conn_t* conn = req->conn;
  ebb_connection *connection = conn->ebb_conn;

  LOG_DEBUG(DEBUG,"connection = %d, req = %d", conn->id, req->id);
  if(connection == NULL) {
    LOG_DEBUG(SEVERE,"Error connection is null. returning ...");
    return;
  }

/*
  if(req->tmp_header.str && req->tmp_value.str) {
    wr_req_header_add(req);
  }
*/

  if(wr_req_path_set(req)!=0) {
    return;
  }

  LOG_DEBUG(DEBUG,"Request URI = %s, length = %d" ,req->req_path.str , req->req_uri.len);
  scgi_header_add(req->scgi, WR_EBB_REQ_URI, WR_EBB_REQ_URI_LEN, req->req_path.str, req->req_uri.len);
  if(req->req_path.str) {
    LOG_DEBUG(DEBUG,"Request path = %s, length = %d" ,req->req_path.str , req->req_path.len);
    scgi_header_add(req->scgi, WR_EBB_REQ_PATH, WR_EBB_REQ_PATH_LEN, req->req_path.str, req->req_path.len);
  }

  if(req->req_query_str.str) {
    LOG_DEBUG(DEBUG,"Request query string = %s, length = %d" ,req->req_query_str.str , req->req_query_str.len);
    scgi_header_add(req->scgi, WR_EBB_QUERY_STR, WR_EBB_QUERY_STR_LEN, req->req_query_str.str, req->req_query_str.len);
  }
  
  if(req->req_fragment.str) {
    LOG_DEBUG(DEBUG,"Request fragment = %s, length = %d" ,req->req_fragment.str , req->req_fragment.len);
    scgi_header_add(req->scgi, WR_EBB_FRAGMENT, WR_EBB_FRAGMENT_LEN, req->req_fragment.str, req->req_fragment.len);
  }

#ifdef HAVE_GNUTLS
  // Add extra field to server HTTPS requests
  // RequestHeader set X_FORWARDED_PROTO ‘https’
  if(conn->svr->secure_ebb_svr.fd == connection->server->fd) {
    scgi_header_add(req->scgi, WR_EBB_HTTPS_HEADER, WR_EBB_HTTPS_HEADER_LEN, "on", 2);
  }
#endif

  /** Add CONTENT_LENGTH header into CGI header list */
  scgi_content_length_add(req->scgi, request->content_length);

  /** Add WR_EBB_CHUNKED header into CGI header list */
  if(request->transfer_encoding == EBB_CHUNKED) {
    scgi_header_add(req->scgi, WR_EBB_CHUNKED, WR_EBB_CHUNKED_LEN, "Yes", 3);
  } else {
    scgi_header_add(req->scgi, WR_EBB_CHUNKED, WR_EBB_CHUNKED_LEN, "No", 2);
  }

  /** Add WR_EBB_REQ_METHOD header into CGI header list */
  switch(request->method) {
  case EBB_COPY :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_COPY, WR_EBB_REQ_METHOD_COPY_LEN);
    break;
  case EBB_DELETE :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_DELETE, WR_EBB_REQ_METHOD_DELETE_LEN);
    break;
  case EBB_GET       :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_GET, WR_EBB_REQ_METHOD_GET_LEN);
    break;
  case EBB_HEAD      :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_HEAD, WR_EBB_REQ_METHOD_HEAD_LEN);
    break;
  case EBB_LOCK      :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_LOCK, WR_EBB_REQ_METHOD_LOCK_LEN);
    break;
  case EBB_MKCOL     :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_MKCOL, WR_EBB_REQ_METHOD_MKCOL_LEN);
    break;
  case EBB_MOVE      :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_MOVE, WR_EBB_REQ_METHOD_MOVE_LEN);
    break;
  case EBB_OPTIONS   :
    wr_req_invalid(req->conn, WR_HTTP_STATUS_501);
    return;
    //scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_OPTIONS, WR_EBB_REQ_METHOD_OPTIONS_LEN);
    break;
  case EBB_POST      :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_POST, WR_EBB_REQ_METHOD_POST_LEN);
    break;
  case EBB_PROPFIND  :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_PROPFIND, WR_EBB_REQ_METHOD_PROPFIND_LEN);
    break;
  case EBB_PROPPATCH :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_PROPPATCH, WR_EBB_REQ_METHOD_PROPPATCH_LEN);
    break;
  case EBB_PUT       :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_PUT, WR_EBB_REQ_METHOD_PUT_LEN);
    break;
  case EBB_TRACE     :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_TRACE, WR_EBB_REQ_METHOD_TRACE_LEN);
    break;
  case EBB_UNLOCK    :
    scgi_header_add(req->scgi, WR_EBB_REQ_METHOD, WR_EBB_REQ_METHOD_LEN, WR_EBB_REQ_METHOD_UNLOCK, WR_EBB_REQ_METHOD_UNLOCK_LEN);
    break;
  }

  /* set PATH_INFO */
  //TODO: Check whether to add path info or not
  //rb_hash_aset(env, g_path_info, rb_hash_aref(env, g_request_path));

  /* Add WR_EBB_SVR_PORT header into CGI header list */
  scgi_header_add(req->scgi, WR_EBB_SVR_PORT, WR_EBB_SVR_PORT_LEN, connection->server->port, strlen(connection->server->port));

  /* Add WR_EBB_HTTP_CLI_IP header into CGI header list */
  scgi_header_add(req->scgi, WR_EBB_HTTP_CLI_IP, WR_EBB_HTTP_CLI_IP_LEN, connection->ip, strlen(connection->ip));

  /* Add WR_EBB_HTTP_VER header into CGI header list */
  wr_buffer_t *buf;
  wr_buffer_new(buf);
  wr_buffer_create(buf, WR_TINY_STR_LEN);
  buf->len = snprintf(buf->str, WR_TINY_STR_LEN, "HTTP/%d.%d", request->version_major, request->version_minor);
  scgi_header_add(req->scgi, WR_EBB_HTTP_VER, WR_EBB_HTTP_VER_LEN, buf->str, buf->len);
  wr_buffer_free(buf);

  /** Check content length */
  LOG_DEBUG(DEBUG,"Request content len = %d", request->content_length);
  if(request->content_length > WR_REQ_BODY_MAX_SIZE) {
    // Open file to write req request body
    wr_buffer_new(req->upload_file_name);
    wr_buffer_create(req->upload_file_name, WR_SHORT_STR_LEN);
    req->upload_file_name->len = sprintf(req->upload_file_name->str,"/tmp/ebb_upload_%d", req->id);
    req->upload_file = fopen(req->upload_file_name->str,"w+");
    if(req->upload_file == NULL) {
      LOG_ERROR(SEVERE,"Cannot open tmpfile %s", req->upload_file_name->str);
      wr_req_free(req);
      return;
    }
  }
  wr_req_resolve_http_req(req->conn->svr, req);
}

/** HTTP request completed */
void wr_req_complete_cb(ebb_request * request) {
  LOG_FUNCTION
  wr_req_t* req = (wr_req_t*) request->data;
  LOG_DEBUG(DEBUG,"req = %d",req->id);
  // Rewind file pointer if request body is written into file
  if(req->upload_file) {
    rewind(req->upload_file);
  }

  /*#ifdef HAVE_GNUTLS
  if(ebb_request_should_keep_alive(request))
      req->conn->resp_to_write ++;
    else
    #endif*/
  req->conn->keep_alive = ebb_request_should_keep_alive(req->ebb_req);
  req->conn->resp_to_write ++;
  scgi_build(req->scgi);
  // ebb_request parsing completed, send call back to Server
  if(req->app){
    int rv;
    WR_QUEUE_INSERT(req->app->q_messages, req, rv)
    if(rv == 0){
      wr_wkr_dispatch_req(req);
      return;
    }
  }
  LOG_ERROR(WARN,"Failed to dispatch req no %d to any application. Request PATH is %s", req->id, req->req_uri.str);
  wr_req_invalid(req->conn, WR_HTTP_STATUS_404);
}

/********************************************************
 *     Request Function Definition      *
 ********************************************************/

/** Create new Request */
wr_req_t* wr_req_new(wr_conn_t* conn) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG,"for connection = %d", conn->id);

  wr_req_t  *req = wr_malloc(wr_req_t);

  if(req == NULL) {
    LOG_DEBUG(SEVERE, "Error req is null. Returning ...");
    return NULL;
  }

  req->conn = conn;
  req->id = ++wr_req_count;

  req->app       = NULL;
  req->wkr       = NULL;

  req->upload_file      = NULL;
  req->upload_file_name = NULL;
  //  req->uri_hash    =
  req->bytes_sent      = 0;
  req->scgi    = scgi_new();

  if(req->scgi == NULL) {
    free(req);
    LOG_ERROR(WARN, "Error req->scgi is null. Returning ...");
    return NULL;
  }

  req->resp_buf_len   =
    req->bytes_received =
      req->resp_body_len = 0;
  req->resp_code = 0;

  req->conn_err = req->using_wkr = FALSE;

#ifdef L_DEBUG
  /* Adding Connection id and req id */
  wr_buffer_t *conn_id, *req_id;
  wr_buffer_new(conn_id);
  wr_buffer_new(req_id);
  wr_buffer_create(conn_id, WR_SHORT_STR_LEN);
  wr_buffer_create(req_id, WR_SHORT_STR_LEN);
  conn_id->len = snprintf(conn_id->str, conn_id->size, "%d", conn->id);
  req_id->len = snprintf(req_id->str, req_id->size, "%d", req->id);
  scgi_header_add(req->scgi, WR_CONN_ID, strlen(WR_CONN_ID), conn_id->str, conn_id->len);
  scgi_header_add(req->scgi, WR_REQ_ID, strlen(WR_REQ_ID), req_id->str, req_id->len);
  wr_buffer_free(conn_id);
  wr_buffer_free(req_id);
#endif

  wr_string_null(req->req_uri);
  wr_string_null(req->req_path);
  wr_string_null(req->req_query_str);
  wr_string_null(req->req_fragment);

  ebb_request *request = wr_malloc(ebb_request);
  if(request == NULL) {
    scgi_free(req->scgi);
    free(req);
    LOG_DEBUG(SEVERE, "Error ebb_request is null. Returning ...");
    return NULL;
  }

  ebb_request_init(request);

  //TODO: can connection have multiple requests?
  req->ebb_req = request;

  request->data = req;
  request->on_path = wr_req_path_cb;
  request->on_query_string = wr_query_string_cb;
  request->on_uri = wr_req_uri_cb;
  request->on_fragment = wr_req_fragment_cb;
  request->on_header_field = wr_req_header_field_cb;
  request->on_header_value = wr_req_header_value_cb;
  request->on_headers_complete = wr_headers_complete_cb;
  request->on_body = wr_req_body_cb;
  request->on_complete = wr_req_complete_cb;

  //TODO: Check for keep alive status & then increment 'responses_to_write'
  // Else it will be 1

  return req;
}

/** Destroy req */
void wr_req_free(wr_req_t* req) {
  LOG_FUNCTION
  if(req) {
    LOG_DEBUG(DEBUG, "Request id = %d",req->id);
    if(!req->conn_err) {
      req->conn->resp_to_write --;
      req->conn->req = NULL;

      if(req->conn->is_closed && req->conn->resp_to_write == 0) {
        wr_conn_free(req->conn);
      }
    }

    if(req->ebb_req)
      free(req->ebb_req);

    wr_string_free(req->req_uri);
    wr_string_free(req->req_fragment);
    scgi_free(req->scgi);
    if(req->upload_file) {
      fclose(req->upload_file);
      remove(req->upload_file_name->str);
      wr_buffer_free(req->upload_file_name);
    }
    free(req);
  } else {
    LOG_DEBUG(SEVERE, "Error req is null.");
  }
}

/** Add req request body */
int wr_req_body_add(wr_req_t *req, const char *at, size_t length) {
  LOG_FUNCTION
  if(req->upload_file) {
    LOG_DEBUG(DEBUG, "writing into file");
    size_t write = 0;
    while(write < length) {
      write += fwrite( at + write, sizeof(char), length - write, req->upload_file);
    }
  } else {
    LOG_DEBUG(DEBUG, "copying into buffer. len=%d", length);
    scgi_body_add(req->scgi, at, length);
  }
  return 0;
}

ebb_request* wr_new_req_cb(ebb_connection *connection) {
  LOG_FUNCTION
  // Create new wr_req
  wr_conn_t* conn = (wr_conn_t*)connection->data;
  wr_req_t* req =NULL;

  //We are not supporting pipelining, discard any 1+ request
  if(conn->resp_to_write > 0) {
    LOG_DEBUG(WARN, "Pipelining support would come soon");
    return NULL;
  }
  req = wr_req_new(conn);

  if(req == NULL) {
    LOG_ERROR(WARN, "req object allocation failed. Returning ...");
    return NULL;
  } else {
    conn->req = req;
    LOG_DEBUG(DEBUG,"request = %d, connection = %d", req->id, conn->id);
    // Return ebb_request
    return req->ebb_req;
  }
}

/** Invalid request
 * disable all the callback functions */
void wr_req_invalid(wr_conn_t *conn, wr_resp_status_t resp_code) {
  LOG_FUNCTION

  if(conn->req) {
    conn->req->resp_code = resp_code;
    conn->req->ebb_req->on_body = NULL;
    conn->req->ebb_req->on_fragment = NULL;
    conn->req->ebb_req->on_header_field = NULL;
    conn->req->ebb_req->on_header_value =NULL;
    conn->req->ebb_req->on_path = NULL;
    conn->req->ebb_req->on_query_string = NULL;
    conn->req->ebb_req->on_uri = NULL;
    conn->req->ebb_req->on_headers_complete = NULL;
    conn->req->ebb_req->on_complete = NULL;
  }
  conn->keep_alive = 0;
  LOG_DEBUG(DEBUG,"Stopping read watcher");
  ebb_connection_stop_read (conn->ebb_conn);
  //  conn->con_req_err = TRUE;
  if(conn->resp_to_write == 0)
    conn->resp_to_write = 1;
  wr_conn_err_resp(conn, resp_code);
}
