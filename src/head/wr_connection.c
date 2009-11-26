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
#include <wr_access_log.h>

// Connection count
static unsigned int wr_conn_count = 0;

typedef struct {
  wr_u_short  code;
  char       phrase[56];
  char        message[128];
}
wr_http_status_t;

static wr_http_status_t http_status [] ={
  {100, "100 Continue", ""},
  {400, "400 Bad Request", "The request could not be understood by the server."},
  {403, "403 Forbidden", "The requested page is forbidden."},
  {404, "404 Not Found", "The requested page could not be found."},
  {405, "405 Method Not Allowed", "The request method is not allowed."},
  {411, "411 Length Required", "The request requires 'Content-Length'."},
  {413, "413 Request Entity Too Large", "The request entity is too large"},
  {414, "414 Request-URI Too Large", "The request URI is too large"},
  {500, "500 Internal Server Error", "The server is facing some error while processing the request. "},
  {501, "501 Not Implemented", "The requested method is not implemented"}
};

#define WR_RESP_BODY "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\r\n\
      <html><head>\r\n\
      <title>%s</title>\r\n\
      </head><body>\r\n\
      <h1>%s</h1>\r\n\
      <p>%s</p>\r\n\
      <br><br><hr>%s-%s\
      </body></html>"

#define WR_RESPONSE_ERR_BODY "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\r\n\
      <html><head>\r\n\
      <title>%s</title>\r\n\
      </head><body>\r\n\
      <h1>%s</h1>\r\n\
      <p>%s</p>\r\n\
      <br>error:%s<br><hr>%s-%s\
      </body></html>"

#define WR_RESP_HEADERS     "HTTP/1.1 %s\r\n\
Date: %s\r\n\
Server: %s-%s\r\n\
Content-Type: text/html\r\n\
Connection: close\r\n\
Content-Length: %d\r\n\r\n%s"

/** Private function */

/** The response was sent */
void wr_conn_after_write_cb(ebb_connection *connection) {
  LOG_FUNCTION
  wr_conn_t* conn = (wr_conn_t*) connection->data;

  LOG_DEBUG(DEBUG,"Connection = %d, Response = %d, closed = %d",
            conn->id, conn->resp_to_write, conn->is_closed);

  wr_string_list_remove(conn->resp);

  // Check for response chunk
  if(conn->resp->front && !conn->is_closed) {
    // Send next response chunck
    LOG_DEBUG(DEBUG,"Writing response to ebb");
    ebb_connection_write(conn->ebb_conn,
                         conn->resp->front->str.str,
                         conn->resp->front->str.len,
                         wr_conn_after_write_cb);
  } else if(conn->resp_to_write <= 0) {
    LOG_DEBUG(DEBUG,"response to write is less than 1 keep alive =%d", conn->keep_alive);
    if(!WR_SVR_KEEP_ALIVE || !conn->keep_alive) {
      // Close ebb_connection if there is no any pending request
      LOG_DEBUG(DEBUG,"Closing Connection %d ...", conn->id);
      ebb_connection_schedule_close(connection);
    }
  }
}

/** The connection got parser error */
void wr_conn_err_cb(ebb_connection* connection) {
  LOG_FUNCTION

  wr_conn_t* conn = (wr_conn_t*)connection->data;
  LOG_DEBUG(DEBUG,"Connection id = %d",conn->id);
  conn->keep_alive = 0;
  wr_req_invalid(conn, WR_HTTP_STATUS_400);
  //  if(conn->resp_to_write == 0)
  //    conn->resp_to_write = 1;
  //  wr_server_err_response(conn, WR_HTTP_STATUS_400);
}

/** The ebb connection goes timeout */
int wr_conn_timeout_cb(ebb_connection* connection) {
  LOG_FUNCTION
  wr_conn_t* a_conn = (wr_conn_t*) connection->data;
  LOG_DEBUG(DEBUG,"connection %d, response = %d", a_conn->id, a_conn->resp_to_write);

  if(a_conn->resp_to_write > 0 || a_conn->resp->front) {
    return EBB_AGAIN;
  }

  if(a_conn->req) {
    wr_req_free(a_conn->req);
  }
  return EBB_STOP;
}

/** The connection was closed */
void wr_conn_close_cb(ebb_connection* connection) {
  LOG_FUNCTION
  if(connection && connection->data){
    wr_conn_t* conn = (wr_conn_t*) connection->data;
    LOG_DEBUG(DEBUG,"connection %d, response %d ", conn->id, conn->resp_to_write);

    // Check for pending requests
    if(conn->resp_to_write <= 0) {
      // Destroy wr_connection
      wr_conn_free(conn);
      connection->data = NULL;
    } else {
      // Set altas_connection to closed
      LOG_DEBUG(DEBUG,"closed flag set %d", conn->id);
      conn->is_closed = 1;
      conn->keep_alive = 0;
    }
  }
}

/********************************************************
 *       Connection Function Definition      *
 ********************************************************/

/** Create new Connection */
wr_conn_t* wr_conn_new(wr_svr_t *server) {
  LOG_FUNCTION
  wr_conn_t* a_connection = wr_malloc(wr_conn_t);

  if(a_connection == NULL) {
    LOG_DEBUG(SEVERE, "Error a_connection is null. Returning ...");
    return NULL;
  }
  ebb_connection *connection = wr_malloc(ebb_connection);

  if(connection == NULL) {
    free(a_connection);
    LOG_DEBUG(SEVERE, "Error connection is null. Returning ...");
    return NULL;
  }

  ebb_connection_init(connection);

  a_connection->id = ++wr_conn_count;
  a_connection->resp_to_write = 0;
  a_connection->ebb_conn = connection;
  a_connection->svr = server;
  a_connection->resp = wr_string_list_new();
  a_connection->is_closed = FALSE;
  a_connection->keep_alive = FALSE;
  //  a_connection->con_req_err = FALSE;
  a_connection->req = NULL;
  connection->data = a_connection;
  connection->new_request = wr_new_req_cb;
  connection->on_close = wr_conn_close_cb;
  connection->on_timeout = wr_conn_timeout_cb;
  connection->on_error = wr_conn_err_cb;

  return a_connection;
}

/** Destroy Connection */
void wr_conn_free(wr_conn_t *conn) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG,"Connnection id %d", conn->id);
  if(conn) {
    if(conn->ebb_conn) {
      conn->ebb_conn->data = NULL;
      free(conn->ebb_conn);
    } else {
      LOG_DEBUG(SEVERE, "Error conn->ebb_conn is null.");
    }

    //if(conn->req && !conn->req->conn_err) wr_req_free(conn->req);
    conn->ebb_conn = NULL;
    wr_string_list_free(conn->resp);
    conn->resp = NULL;
    free(conn);
  }
}

/** Add response to Connection */
int wr_conn_resp_body_add(wr_conn_t* conn, const char* str, size_t len) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG,"Connection = %d", conn->id);

  if(!conn->is_closed) {
    if(wr_string_list_is_empty(conn->resp)) {
      wr_string_list_add(conn->resp, str, len);
      LOG_DEBUG(DEBUG, "Writing first chunk. Connection = %d",conn->id);
      ebb_connection_write(conn->ebb_conn,
                           conn->resp->front->str.str,
                           conn->resp->front->str.len,
                           wr_conn_after_write_cb);
    } else {
      LOG_DEBUG(DEBUG, "Adding next chunk in list. Connection = %d", conn->id);
      wr_string_list_add(conn->resp, str, len);
    }
  } else {
    LOG_DEBUG(DEBUG,"Check response %d", conn->resp_to_write);
    if(conn->resp_to_write == 0) {
      wr_conn_free(conn);
      conn = NULL;
    }
  }
  return 0;
}

/** Allocates and initializes an ebb_connection */
ebb_connection* wr_new_conn_cb(ebb_server* server, struct sockaddr_in* addr) {
  LOG_FUNCTION
  // Create new altas_connection
  wr_conn_t* conn = wr_conn_new(server->data);

  if(conn == NULL) {
    LOG_ERROR(WARN,"new_connection_cb() connection object allocation failed. Returning ...");
    return NULL;
  } else {
    LOG_DEBUG(DEBUG,"new_connection_cb() connection = %d", conn->id);
    // Return ebb_connection
    return conn->ebb_conn;
  }
}

/** Response generated by Server */
void wr_conn_err_resp(wr_conn_t *conn, wr_resp_status_t resp_code) {
  LOG_FUNCTION
  char response_body[WR_LONG_LONG_STR_LEN];
  char response_buff[WR_LONG_LONG_STR_LEN*2];
  size_t body_len, buff_len;

  LOG_DEBUG(DEBUG, "response code = %s",http_status[resp_code].phrase);
  conn->keep_alive = 0;

  switch(resp_code) {
  case WR_HTTP_STATUS_100:
    body_len = 0;
    buff_len = sprintf(response_buff, WR_RESP_HEADERS,
                       http_status[resp_code].phrase, WR_SERVER, WR_VERSION,
                       body_len, http_status[resp_code].message);
    break;
  case WR_HTTP_STATUS_400:
  case WR_HTTP_STATUS_403:
  case WR_HTTP_STATUS_404:
  case WR_HTTP_STATUS_405:
  case WR_HTTP_STATUS_411:
  case WR_HTTP_STATUS_413:
  case WR_HTTP_STATUS_414:
  case WR_HTTP_STATUS_500:
  case WR_HTTP_STATUS_501:
    if(conn->req && conn->req->resp_buf_len > 0) {
      body_len = sprintf(response_body, WR_RESPONSE_ERR_BODY,
                         http_status[resp_code].phrase,http_status[resp_code].phrase+4,
                         http_status[resp_code].message,
                         conn->req->resp_buf,
                         WR_SERVER, WR_VERSION);
    } else {
      body_len = sprintf(response_body, WR_RESP_BODY,
                         http_status[resp_code].phrase,http_status[resp_code].phrase+4,
                         http_status[resp_code].message,WR_SERVER, WR_VERSION);
    }
    
    char current_date[WR_STR_LEN];
    get_time(current_date, WR_STR_LEN);
    buff_len = sprintf(response_buff, WR_RESP_HEADERS,
                       http_status[resp_code].phrase, current_date,
                       WR_SERVER, WR_VERSION, body_len, response_body);
    break;
  }

  wr_conn_resp_body_add(conn, response_buff, buff_len);

  if(conn->req) {
    wr_req_t* req = conn->req;
    if(conn->svr->conf->server->flag&WR_SVR_ACCESS_LOG) {
      req->resp_body_len = body_len;
      req->resp_code = http_status[resp_code].code;
      wr_access_log(req);
    }
    //TODO temporary check
    //    conn->resp_to_write --;
    if(req->wkr) {
      if(req->using_wkr) {
        LOG_DEBUG(DEBUG,"Request is with worker, worker would use request structure.");
        req->conn_err = TRUE;
        conn->resp_to_write --;
      } else {
        LOG_DEBUG(DEBUG,"Request is with worker, but worker would not use request structure.");
        wr_req_free(req);
      }
    } else if(req->app) {
      // Remove req from application message list
      LOG_DEBUG(DEBUG,"Request is inserted into Application message queue.");
      wr_queue_remove(conn->req->app->msg_que, conn->req);
      wr_req_free(req);
    } else {
      LOG_DEBUG(DEBUG,"Request is still in parsing phase.");
      wr_req_free(req);
    }
  } else {
    conn->resp_to_write --;
  }
}
