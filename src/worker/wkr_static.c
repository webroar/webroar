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

#include <worker.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <fcntl.h>


#include "wkr_static.h"

#define MAP_SIZE 36
#define DEFAULT_EXPIRES "Headers/expires"
#define EXPIRES_BY_TYPE "Headers/expires_by_type"
#define EXPIRES_BY_TYPE_EXT "expires_by_type/ext"
#define EXPIRES_BY_TYPE_EXPIRES "expires_by_type/expires"
#define HTTP_HEADER_IF_MODIFIED_SINCE "HTTP_IF_MODIFIED_SINCE"
#define HTTP_HEADER_CONNECTION "HTTP_CONNECTION"

#define CONNECTION_CLOSE "Close"
#define CONNECTION_KEEP_ALIVE "Keep-Alive"

#define WR_MSG_QUEUE_SERVER_HOST "starling/host"
#define WR_MSG_QUEUE_SERVER_PORT "starling/port"
#define WR_PID_MSG_QUEUE_NAME "starling/pid_queue_name"

typedef enum {
  HTTP_STATUS_200 = 0,
  HTTP_STATUS_304,
  HTTP_STATUS_403,
  HTTP_STATUS_404
} resp_status_t;

typedef void (*resp_fun_t) (http_t*, const char*, struct stat *);

typedef struct {
  wr_u_short code;
  char phrase[56];
  char message[128];
  resp_fun_t fun;
} http_status_t;

void http_resp_200(http_t*, const char*, struct stat *);
void http_resp_304(http_t*, const char*, struct stat *);
void http_resp_403(http_t*, const char*, struct stat *);
void http_resp_404(http_t*, const char*, struct stat *);

static http_status_t http_status [] = {
  {200, "200 OK", "", http_resp_200},
  {304, "304 Not Modified", "", http_resp_304},
  {403, "403 Forbidden", "The requested page is forbidden.", http_resp_403},
  {404, "404 Not Found", "The requested page could not be found.", http_resp_404}
};

#define HTTP_RESP_ERR_HEADERS "HTTP/1.1 %s\r\n\
Date: %s\r\n\
Server: %s-%s\r\n\
Content-Type: text/html\r\n\
Connection: %s\r\n\
Content-Length: %d\r\n\r\n"

#define HTTP_RESP_ERR_BODY "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\r\n\
<html><head>\r\n\
<title>%s</title>\r\n\
</head><body>\r\n\
<h1>%s</h1>\r\n\
<p>%s</p>\r\n\
<br><hr>%s-%s\
</body></html>"

// Static mapping object
static static_file_t* map[MAP_SIZE + 1];

/**************************************
 *    Private Functions 
 *************************************/

/** Searches path backward and returns pointer to the first character of extension */
static char* get_file_ext(const char *path) {
  int len = strlen(path);
  char *ext = path + len;
  while (len) {
    if (*(--ext) == '.') {
      return ext + 1;
    }
    len--;
  }
  return NULL;
}

/** Set expires time based on file type */
static void set_expires_time(char *ext, long int expires) {
  int index;
  if(*ext >= '0' && *ext <= '9'){
    index = (*ext) - '0';
  }else if(*ext >= 'a' && *ext <= 'z'){
    index = (*ext) - 'a' + 10;
  }else{
    LOG_ERROR(WARN, "Extension %s is not supported", ext);
    return;
  }

  if (index >= 0 && index < MAP_SIZE) {
    static_file_t *e = map[index];
    while (e) {
      if (strcmp(e->ext, ext) == 0) {
        e->expires = expires;
        break;
      }
      e = e->next;
    }
  }
}

/* Get mime-type */
static static_file_t* get_mime_type(const char *path) {
  char *ext = get_file_ext(path);
  char *str;
  if (ext) {
    str = ext;
    while ((*str)) {
      (*str++) = ((*str) >= 'A' && (*str) <= 'Z' ? (*str) + 'a' - 'A' : (*str));
    }
    int index;
    if(*ext >= '0' && *ext <= '9'){
      index = (*ext) - '0';
    }else if(*ext >= 'a' && *ext <= 'z'){
      index = (*ext) - 'a' + 10;
    }else{
      index = MAP_SIZE;
      LOG_ERROR(WARN, "Extension %s is not supported", ext);
    }
    
    if (index >= 0 && index < MAP_SIZE) {
      static_file_t *e = map[index];
      while (e) {
        if (strcmp(e->ext, ext) == 0) {
          return e;
        }
        e = e->next;
      }
    }
  }
  return map[MAP_SIZE];
}

/** Get response code */
static short get_resp_code(http_t *h, const char *path, struct stat *buf) {
  LOG_FUNCTION
  const char *modify = scgi_header_value_get(h->req->scgi, HTTP_HEADER_IF_MODIFIED_SINCE);
  time_t modify_tm;
  
  if (path == NULL) {
    LOG_ERROR(WARN, "Requested file path is NULL.");
    return HTTP_STATUS_404;
  }

  if (stat(path, buf)) {
    LOG_ERROR(WARN, "Requested file %s does not exist.", path);
    return HTTP_STATUS_404;
  }

  if (S_ISDIR(buf->st_mode) != 0) {
    LOG_ERROR(WARN, "%s is a directory.", path)
    return HTTP_STATUS_404;
  }

  if (strstr(path, "..")) {
    LOG_ERROR(WARN, "Requested file path %s is forbidden.", path);
    return HTTP_STATUS_403;
  }
  // Compare 'If-Modified-Since' time with file modication time
  if (modify) {
    // Assume 'If-Modified-Since' date zone is GMT        
    modify_tm = httpdate_to_c_time(modify) - timezone;
    long int diff = difftime(buf->st_mtime, modify_tm);
    if (diff <= 0) {
      return HTTP_STATUS_304;
    }
  }
  return HTTP_STATUS_200;
}

static long int get_default_expires(node_t *root) {
  char *node_value = get_node_value(root, DEFAULT_EXPIRES);

  if (node_value == NULL) {
    //return EXPIRES_DURATION;
    return 0;
  }else if (strcmp(node_value, "off") == 0) {
    return 0;
  }else {
    return atol(node_value);
  }
}

static int create_dictionary(const char *mapping_file, long int expires) {
  node_t *root = yaml_parse(mapping_file), *node;
  static_file_t *ext;
  int index, i;

  // Initialize map with NULL value
  for (i = 0; i < MAP_SIZE; i++) {
    map[i] = NULL;
  }

  if (root == NULL) {
    LOG_ERROR(SEVERE, "Could not read the file %s", mapping_file);
    return -1;
  }
  node = root;
  while (node) {
    ext = wr_malloc(static_file_t);
    strcpy(ext->ext, node->name);
    strcpy(ext->mime_type, node->value);
    ext->expires = expires;
    int index;
    if(ext->ext[0] >= '0' && ext->ext[0] <= '9'){
      index = ext->ext[0] - '0';
    }else if(ext->ext[0] >= 'a' && ext->ext[0] <= 'z'){
      index = ext->ext[0] - 'a' + 10;
    }else{
      index = MAP_SIZE;
    }
    
    if (index >= 0 && index < MAP_SIZE) {
      ext->next = map[index];
      map[index] = ext;
    }else {
      LOG_ERROR(WARN, "Mapping index out of bound for extension = %s", ext->ext);
      free(ext);
    }
    node = node->next;
  }
  node_free(root);

  // Set default mime type
  ext = wr_malloc(static_file_t);
  strcpy(ext->ext, "");
  strcpy(ext->mime_type, "text/plain");
  ext->next = NULL;
  map[MAP_SIZE] = ext;

  return 0;
}

static void set_expires_by_type(node_t *root) {
  node_t *node = get_nodes(root, EXPIRES_BY_TYPE);
  long int expires;
  char *types, *expires_str, *type;
  while (node) {
    types = get_node_value(node, EXPIRES_BY_TYPE_EXT);
    expires_str = get_node_value(node, EXPIRES_BY_TYPE_EXPIRES);
    expires = atol(expires_str);
    type = strtok(types, " ,");
    while (type != NULL) {
      set_expires_time(type, expires);
      type = strtok(NULL, " ,");
    }
    node = NODE_NEXT(node);
  }
}

void http_resp_200(http_t *h, const char *path, struct stat *buf) {
  LOG_FUNCTION
  char str[WR_LONG_LONG_STR_LEN], expire_date[WR_STR_LEN] = "", current_date[WR_STR_LEN] = "", modify_date[WR_STR_LEN] = "";
  int len;
  time_t t;
  
  static_file_t *ext = get_mime_type(path);
  LOG_DEBUG(DEBUG,"File extension = %s, mimetype = %s, expires = %d ", ext->ext, ext->mime_type, ext->expires);
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  
  t = get_time(current_date, WR_STR_LEN);
  time_to_httpdate(buf->st_mtime, modify_date, WR_STR_LEN);
  
  if (ext->expires > 0) {
    t += ext->expires;
    time_to_httpdate(t, expire_date, WR_STR_LEN);
    len = sprintf(str, "HTTP/1.1 200 OK\r\nDate: %s\r\nServer: %s-%s\r\nLast-Modified: %s\r\nExpires: %s\r\nCache-Control: max-age=%ld, public\r\nConnection: %s\r\nContent-Type: %s\r\nContent-Length: %d\r\n\r\n",
            current_date, WR_SERVER, WR_VERSION, modify_date, expire_date, ext->expires,
            (conn_header ? conn_header : CONNECTION_CLOSE), ext->mime_type, buf->st_size);
  }else {
    len = sprintf(str, "HTTP/1.1 200 OK\r\nDate: %s\r\nServer: %s-%s\r\nLast-Modified: %s\r\nCache-Control: no-cache\r\nConnection: %s\r\nContent-Type: %s\r\nContent-Length: %d\r\n\r\n",
             current_date, WR_SERVER, WR_VERSION, modify_date,
            (conn_header ? conn_header : CONNECTION_CLOSE), ext->mime_type, buf->st_size);
  }

  wr_string_new(h->resp->header, str, len);
  h->resp->resp_body->len = buf->st_size;
  h->resp->resp_code = http_status[HTTP_STATUS_200].code;
#ifdef _POSIX_C_SOURCE
  h->resp->file = open(path, O_RDONLY);
#else
  h->resp->file = fopen(path, "r");
#endif  
}

void http_resp_304(http_t *h, const char *path, struct stat *buf) {
  LOG_FUNCTION
  char str[WR_LONG_LONG_STR_LEN], expire_date[WR_STR_LEN] = "", current_date[WR_STR_LEN] = "";
  int len;
  time_t t;
  static_file_t *ext = get_mime_type(path);
  LOG_DEBUG(DEBUG,"File extension = %s, mimetype = %s, expires = %d ", ext->ext, ext->mime_type, ext->expires);
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);

  t = get_time(current_date, WR_STR_LEN);
  if (ext->expires > 0) {
    t = t + ext->expires;
    time_to_httpdate(t, expire_date, WR_STR_LEN);
    len = sprintf(str, "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nServer: %s-%s\r\nExpires: %s\r\nCache-Control: max-age=%ld, public\r\nConnection: %s\r\n\r\n",
            current_date, WR_SERVER, WR_VERSION, expire_date, ext->expires,
            (conn_header ? conn_header : CONNECTION_CLOSE));
  }else {
    len = sprintf(str, "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nServer: %s-%s\r\nCache-Control: no-cache\r\nConnection: %s\r\n\r\n",
            current_date, WR_SERVER, WR_VERSION, (conn_header ? conn_header : CONNECTION_CLOSE));
  }

  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_304].code;
}

void http_resp_403(http_t *h, const char *path, struct stat *buf) {
  LOG_FUNCTION
  char str[WR_LONG_LONG_STR_LEN], current_date[WR_STR_LEN];
  time_t t;
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  int len;

  get_time(current_date, WR_STR_LEN);
  
  len = sprintf(str, HTTP_RESP_ERR_BODY,
          http_status[HTTP_STATUS_403].phrase, http_status[HTTP_STATUS_403].phrase + 4,
          http_status[HTTP_STATUS_403].message, WR_SERVER, WR_VERSION);
  wr_buffer_create(h->resp->resp_body, len);
  wr_buffer_add(h->resp->resp_body, str, len);

  len = sprintf(str, HTTP_RESP_ERR_HEADERS,
          current_date, http_status[HTTP_STATUS_403].phrase, WR_SERVER, WR_VERSION,
          (conn_header ? conn_header : CONNECTION_CLOSE), len);
  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_403].code;
}

void http_resp_404(http_t *h, const char *path, struct stat *buf) {
  LOG_FUNCTION
  char str[WR_LONG_LONG_STR_LEN], current_date[WR_STR_LEN];
  time_t t;
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  int len;
  
  get_time(current_date, WR_STR_LEN);

  len = sprintf(str, HTTP_RESP_ERR_BODY,
          http_status[HTTP_STATUS_404].phrase, http_status[HTTP_STATUS_404].phrase + 4,
          http_status[HTTP_STATUS_404].message, WR_SERVER, WR_VERSION);
  wr_buffer_create(h->resp->resp_body, len);
  wr_buffer_add(h->resp->resp_body, str, len);

  len = sprintf(str, HTTP_RESP_ERR_HEADERS,
          current_date, http_status[HTTP_STATUS_404].phrase, WR_SERVER, WR_VERSION,
          (conn_header ? conn_header : CONNECTION_CLOSE), len);
  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_404].code;
}

void send_static_worker_pid(char *root_path) {
  LOG_FUNCTION
  node_t *root = NULL;  
  char file_name[WR_LONG_STR_LEN];
  // Read pid queue related configuration
  sprintf(file_name, "%s%s", root_path, WR_SERVER_INTERNAL_CONF_PATH);
  root = yaml_parse(file_name);
  if(root == NULL) {
    LOG_ERROR(SEVERE, "Could not parse server_internal_config.yml file. PID can not be sent to analyzer");
    return;  
  } else {
    char *host = NULL, *port = NULL, *queue_name = NULL;
    wr_msg_queue_server_t *msg_queue_server = NULL;
    wr_msg_queue_conn_t *msg_queue_conn = NULL;
    char msg_value[WR_SHORT_STR_LEN];
    int rv;
    
    host = get_node_value(root, WR_MSG_QUEUE_SERVER_HOST);
    port = get_node_value(root, WR_MSG_QUEUE_SERVER_PORT);
    queue_name = get_node_value(root, WR_PID_MSG_QUEUE_NAME);    
    if (!host || !port || !queue_name) {
      LOG_ERROR(SEVERE, "Error getting message queue configuration");
      goto err; 
    }
    msg_queue_server = wr_msg_queue_server_new(host, atoi(port));
    if (!msg_queue_server) {
      LOG_ERROR(WARN, "Error initializing message queue server object"); 
      goto err;
    }
    msg_queue_conn = wr_msg_queue_conn_new(msg_queue_server);
    if (!msg_queue_conn) {
      LOG_ERROR(WARN, "Error initializing message queue connection object");
      goto err;       
    }
    rv = wr_msg_queue_conn_open(msg_queue_conn);
    if (rv < 0) {
      LOG_ERROR(WARN, "Error establising connection with message queue server");
      goto err; 
    }
    rv = sprintf(msg_value, "%s:%d", WR_STATIC_FILE_SERVER_NAME, getpid());
    rv = wr_msg_queue_set(msg_queue_conn, queue_name, msg_value, rv);
    if (rv < 0) {
      LOG_ERROR(SEVERE, "Failed to send PID to message queue"); 
    } else {
      LOG_INFO("PID sent to queue successfully."); 
    }
err:    
    node_free(root);
    wr_msg_queue_conn_free(msg_queue_conn);
    wr_msg_queue_server_free(msg_queue_server);
    return;
  }   
}

/**************************************
 *    Public Functions 
 *************************************/

/* Initialize extension and mime-type map */
int static_module_init(char *root_path) {
  LOG_FUNCTION
  node_t *root;
  char *node_value;
  char file_name[100];
  long int expires;

  sprintf(file_name, "%s%s", root_path, WR_CONF_PATH);
  root = yaml_parse(file_name);
  if (root == NULL) {
    LOG_ERROR(SEVERE, "Could not read config.yml file");
    return -1;
  }
  expires = get_default_expires(root);

  sprintf(file_name, "%s%s", root_path, WR_MIME_TYPE_PATH);
  if (create_dictionary(file_name, expires) != 0) {
    node_free(root);
    return -1;
  }

  set_expires_by_type(root);

  node_free(root);
  
  send_static_worker_pid(root_path);
  return 0;
}

/* Free extension and mime-type map */
void static_module_free() {
  LOG_FUNCTION
  int i;
  static_file_t *ext, *next_ext;

  for (i = 0; i <= MAP_SIZE; i++) {
    ext = map[i];
    while (ext) {
      next_ext = ext->next;
      free(ext);
      ext = next_ext;
    }
  }
}

/* Serve static file content */
int static_file_process(http_t *h) {
  LOG_FUNCTION
  wkr_t *w = h->wkr;
  short resp_code;
  struct stat buf;
  const char *path = scgi_header_value_get(h->req->scgi, WR_HTTP_FILE_PATH);
  
  LOG_DEBUG(DEBUG, "Path = %s", path);
  resp_code = get_resp_code(h, path, &buf);
  http_status[resp_code].fun(h, path, &buf);
  http_req_set(h->req);
  http_resp_process(h->resp);

  ev_io_init(&(w->w_req), http_resp_scgi_write_cb, w->req_fd, EV_WRITE);
  ev_io_start(w->loop, &w->w_req);
}
