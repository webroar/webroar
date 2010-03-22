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
#ifndef WR_REQUEST_H_
#define WR_REQUEST_H_

#include <wr_connection.h>

#define WR_RESP_BUF_SIZE    1024*64

/** Request structure */
struct wr_req_s {
  ebb_request    *ebb_req;    /**< Ebb request */
  wr_conn_t     *conn;  /**< Pointer to Connection */
  wr_app_t       *app;      /**< Application pointer */
  wr_wkr_t       *wkr;      /**< Worker pointer */
  wr_u_int       id;            /**< req id */

  /**< flags */
  short     conn_err;
  short     using_wkr;

  /**< variable used by the request */
  FILE           *upload_file;        /**< File pointer to store request body */
  wr_buffer_t    *upload_file_name;  /**< File name */

  wr_str_t      req_uri, req_path, req_query_str, req_fragment;

  size_t        bytes_sent;
  scgi_t  *scgi;    /**< SCGI request */

  /**< variable used by the response */
  char         resp_buf[WR_RESP_BUF_SIZE];  /**< Buffer to read processed response from 'webroar-worker' */
  size_t         resp_buf_len;  /**< Response buffer length */
  wr_u_short    resp_code;
  size_t        resp_body_len;
  size_t        bytes_received;
};

/** Create new Request */
wr_req_t* wr_req_new(wr_conn_t*);
/** Destroy Request */
void wr_req_free(wr_req_t*);
/** Add Request body */
int wr_req_body_add(wr_req_t*, const char*, size_t);
/** Invalid request */
void wr_req_invalid(wr_conn_t *, wr_resp_status_t);
/** Allocates and initializes ab ebb_request */
ebb_request* wr_new_req_cb(ebb_connection*);
/**************************/

/** Dispatch a pending message to free worker */
#define WR_APP_MSG_DISPATCH(app, req, worker) \
  void *_w=NULL,*_r=NULL;\
  if(app->q_messages->q_count > 0 && app->q_free_workers->q_count > 0){\
    WR_QUEUE_FETCH(app->q_free_workers, _w)\
    WR_QUEUE_FETCH(app->q_messages, _r)}\
  req = (wr_req_t*) _r;\
  worker = (wr_wkr_t*) _w;


/**** Private macros */
#define WR_EBB_REQ_PATH         "REQUEST_PATH"
#define WR_EBB_REQ_PATH_LEN       12
#define WR_EBB_QUERY_STR         "QUERY_STRING"
#define WR_EBB_QUERY_STR_LEN       12
#define WR_EBB_REQ_URI         "REQUEST_URI"
#define WR_EBB_REQ_URI_LEN       11
#define WR_EBB_FRAGMENT           "FRAGMENT"
#define WR_EBB_FRAGMENT_LEN        8
#define WR_EBB_CHUNKED            "CHUNKED"
#define WR_EBB_CHUNKED_LEN          7
#define WR_EBB_REQ_METHOD        "REQUEST_METHOD"
#define WR_EBB_REQ_METHOD_LEN      14
#define WR_EBB_REQ_METHOD_COPY      "COPY"
#define WR_EBB_REQ_METHOD_COPY_LEN    4
#define WR_EBB_REQ_METHOD_DELETE    "DELETE"
#define WR_EBB_REQ_METHOD_DELETE_LEN  6
#define WR_EBB_REQ_METHOD_GET      "GET"
#define WR_EBB_REQ_METHOD_GET_LEN    3
#define WR_EBB_REQ_METHOD_HEAD      "HEAD"
#define WR_EBB_REQ_METHOD_HEAD_LEN    4
#define WR_EBB_REQ_METHOD_LOCK      "LOCK"
#define WR_EBB_REQ_METHOD_LOCK_LEN    4
#define WR_EBB_REQ_METHOD_MKCOL    "MKCOL"
#define WR_EBB_REQ_METHOD_MKCOL_LEN  5
#define WR_EBB_REQ_METHOD_MOVE      "MOVE"
#define WR_EBB_REQ_METHOD_MOVE_LEN    4
#define WR_EBB_REQ_METHOD_OPTIONS    "OPTIONS"
#define WR_EBB_REQ_METHOD_OPTIONS_LEN  7
#define WR_EBB_REQ_METHOD_POST      "POST"
#define WR_EBB_REQ_METHOD_POST_LEN    4
#define WR_EBB_REQ_METHOD_PROPFIND    "PROPFIND"
#define WR_EBB_REQ_METHOD_PROPFIND_LEN  8
#define WR_EBB_REQ_METHOD_PROPPATCH    "PROPPATCH"
#define WR_EBB_REQ_METHOD_PROPPATCH_LEN  9
#define WR_EBB_REQ_METHOD_PUT      "PUT"
#define WR_EBB_REQ_METHOD_PUT_LEN    3
#define WR_EBB_REQ_METHOD_TRACE    "TRACE"
#define WR_EBB_REQ_METHOD_TRACE_LEN  5
#define WR_EBB_REQ_METHOD_UNLOCK    "UNLOCK"
#define WR_EBB_REQ_METHOD_UNLOCK_LEN  6
#define WR_EBB_SVR_PORT          "SERVER_PORT"
#define WR_EBB_SVR_PORT_LEN        11
#define WR_EBB_HTTP_CLI_IP        "REMOTE_ADDR"
#define WR_EBB_HTTP_CLI_IP_LEN      11
#define WR_EBB_HTTP_VER        "HTTP_VERSION"
#define WR_EBB_HTTP_VER_LEN      12

#ifdef HAVE_GNUTLS
#define WR_EBB_HTTPS_HEADER    "HTTPS"
#define WR_EBB_HTTPS_HEADER_LEN  5
#endif

#endif /*WR_REQUEST_H_*/
