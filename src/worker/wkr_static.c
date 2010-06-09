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

#ifdef W_ZLIB
#include <zlib.h>
#endif

extern config_t *Config;

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

typedef void (*resp_fun_t) (http_t*);

typedef struct {
  wr_u_short code;
  char phrase[56];
  char message[128];
  resp_fun_t fun;
} http_status_t;

void http_resp_200(http_t*);
void http_resp_304(http_t*);
void http_resp_403(http_t*);
void http_resp_404(http_t*);

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

/**************************************
 *    Private Functions 
 *************************************/

/** Searches path backward and returns pointer to the first character of extension */
char* get_file_ext(const char *path) {
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
void set_expires_time(static_server_t * s, char *ext, long int expires) {
  int index;
  char tmp_ext[STR_SIZE64], *p;
  strcpy(tmp_ext, ext);
  p = tmp_ext;
  while(*p){
    *p = wr_tolower(*p);
    p++;
  }

  if(*tmp_ext >= '0' && *tmp_ext <= '9'){
    index = (*tmp_ext) - '0';
  }else if(*tmp_ext >= 'a' && *tmp_ext <= 'z'){
    index = (*tmp_ext) - 'a' + 10;
  }else{
    LOG_ERROR(WARN, "Extension %s is not supported", tmp_ext);
    return;
  }

  if (index >= 0 && index < MAP_SIZE) {
    static_file_t *e = s->map[index];
    while (e) {
      if (strcmp(e->ext, tmp_ext) == 0) {
        //HTTP/1.1 servers SHOULD NOT send Expires dates more than one year in the future. 
        e->expires = expires;
        break;
      }
      e = e->next;
    }
  }
}

/* Get mime-type */
static_file_t* get_mime_type(static_server_t *s) {
  char *ext = get_file_ext(s->path);
  char tmp_ext[STR_SIZE64], *p;
  strcpy(tmp_ext, ext);
  p = tmp_ext;
  while(*p){
    *p = wr_tolower(*p);
    p++;
  }

  if (tmp_ext) {
    int index;
    if(*tmp_ext >= '0' && *tmp_ext <= '9'){
      index = (*tmp_ext) - '0';
    }else if(*tmp_ext >= 'a' && *tmp_ext <= 'z') {
      index = (*tmp_ext) - 'a' + 10;
    }else {
      index = MAP_SIZE;
      LOG_ERROR(WARN, "Extension %s is not supported", tmp_ext);
    }
    
    if (index >= 0 && index < MAP_SIZE) {
      static_file_t *e = s->map[index];
      while (e) {
        if (strcmp(e->ext, tmp_ext) == 0) {
          return e;
        }
        e = e->next;
      }
    }
  }
  return s->map[MAP_SIZE];
}

/** Get response code */
short get_resp_code(static_server_t *s) {
  LOG_FUNCTION
  time_t modify_tm;
  
  if (s->path == NULL) {
    LOG_ERROR(WARN, "Requested file path is NULL.");
    return HTTP_STATUS_404;
  }

  if (stat(s->path, &(s->buf))) {
    LOG_ERROR(WARN, "Requested file %s does not exist.", s->path);
    return HTTP_STATUS_404;
  }

  if (S_ISDIR(s->buf.st_mode) != 0) {
    LOG_ERROR(WARN, "%s is a directory.", s->path)
    return HTTP_STATUS_404;
  }

  if (strstr(s->path, "..")) {
    LOG_ERROR(WARN, "Requested file path %s is forbidden.", s->path);
    return HTTP_STATUS_403;
  }
  // Compare 'If-Modified-Since' time with file modication time
  if (s->modify) {
    // Assume 'If-Modified-Since' date zone is GMT        
    modify_tm = httpdate_to_c_time(s->modify) - timezone;
    long int diff = difftime(s->buf.st_mtime, modify_tm);
    if (diff <= 0) {
      return HTTP_STATUS_304;
    }
  }
  return HTTP_STATUS_200;
}

long int get_default_expires(node_t *root) {
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

/** Read 'mime_type.yml' file and create dictionary for supported Content-Type. */
int create_dictionary(static_server_t *s, const char *mapping_file, long int expires) {
  node_t *root = yaml_parse(mapping_file), *node;
  static_file_t *ext;
  int index;

  // Initialize map with NULL value
  for (index = 0; index < MAP_SIZE; index++) {
    s->map[index] = NULL;
  }

  if (root == NULL) {
    LOG_ERROR(SEVERE, "Could not read the file %s", mapping_file);
    return -1;
  }

  node = get_nodes(root, "File Extensions");

  if (root == NULL || node->child == NULL) {
    LOG_ERROR(SEVERE, "Could not read 'File Extensions' from the file %s", mapping_file);
    return -1;
  }

  node = node->child;

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
      ext->next = s->map[index];
      s->map[index] = ext;
    }else {
      LOG_ERROR(WARN, "Mapping index out of bound for extension = %s", ext->ext);
      free(ext);
    }
    node = node->next;
  }
  node_free(root);

  // Set default mime type
  ext = wr_malloc(static_file_t);
  strcpy(ext->ext, "txt");
  strcpy(ext->mime_type, "text/plain");
  ext->expires = expires;
  ext->next = NULL;
  s->map[MAP_SIZE] = ext;

  return 0;
}

void set_expires_by_type(static_server_t *s, node_t *root) {
  node_t *node = get_nodes(root, EXPIRES_BY_TYPE);
  long int expires;
  char *types, *expires_str, *type;
  while (node) {
    types = get_node_value(node, EXPIRES_BY_TYPE_EXT);
    expires_str = get_node_value(node, EXPIRES_BY_TYPE_EXPIRES);
    expires = atol(expires_str);
    type = strtok(types, " ,");
    while (type != NULL) {
      set_expires_time(s, type, expires);
      type = strtok(NULL, " ,");
    }
    node = NODE_NEXT(node);
  }
}


#ifdef W_ZLIB

/** Compress file */
/* Compress file if its size is >10kb and < 1mb and its mime-type has either
 * text or xml */

int file_compress(http_t *h, static_file_t *ext){
  LOG_FUNCTION  
  h->stat->encoding = scgi_header_value_get(h->req->scgi, "HTTP_ACCEPT_ENCODING");
  h->stat->user_agent = scgi_header_value_get(h->req->scgi, "HTTP_USER_AGENT");
  
  if(h->stat->buf.st_size >= Config->Worker.Compress.lower_limit 
     && h->stat->buf.st_size <= Config->Worker.Compress.upper_limit
     && h->stat->encoding && strstr(h->stat->encoding,"deflate")){

#ifdef W_REGEX
     if(h->stat->r_content_type){
      if(regexec(h->stat->r_content_type, ext->mime_type, 0, NULL, 0) !=0 )   return FALSE;
     }else if(strstr(ext->mime_type, "text") == NULL && strstr(ext->mime_type, "xml") == NULL){
      // Encode assets having Content-Type either 'text' or 'xml'. 
      return FALSE;
     }
     
     if(h->stat->r_user_agent && h->stat->user_agent){
      if(regexec(h->stat->r_user_agent, h->stat->user_agent, 0, NULL, 0) !=0 )   return FALSE;
     }
#else
    // Encode assets having Content-Type either 'text' or 'xml'.
    if(strstr(ext->mime_type, "text") == NULL && strstr(ext->mime_type, "xml") == NULL){
      return FALSE;
    }
#endif

    wr_u_int read;
    FILE *file;
    wr_buffer_create(h->stat->buffer, h->stat->buf.st_size);
    file = fopen(h->stat->path, "r");

    if(file == NULL) return FALSE;
    
    while(h->stat->buffer->len < h->stat->buf.st_size){
      read = fread(h->stat->buffer->str + h->stat->buffer->len, sizeof(char), 
                  h->stat->buf.st_size - h->stat->buffer->len, file);
      if(read < 0){
        fclose(file);
        wr_buffer_null(h->stat->buffer);
        return FALSE;
      }
      h->stat->buffer->len += read;      
    } 
    
    fclose(file);

    //zlib states that the source buffer must be at least 0.1 times larger than 
    //the source buffer plus 12 bytes to cope with the overhead of zlib data streams
    wr_buffer_create(h->resp->resp_body, h->stat->buf.st_size + h->stat->buf.st_size*0.1 + 12);
    h->resp->resp_body->len = h->resp->resp_body->size;
    //now compress the data
    if(compress2((Bytef*)h->resp->resp_body->str, (uLongf*)&h->resp->resp_body->len,
                (const Bytef*)h->stat->buffer->str, (uLongf)h->stat->buffer->len, Z_DEFAULT_COMPRESSION) != Z_OK){
      wr_buffer_null(h->stat->buffer);
      wr_buffer_null(h->resp->resp_body);
      return FALSE;
    }
    wr_buffer_null(h->stat->buffer);

    return TRUE;
  }
  return FALSE; 
} 

#endif

void http_resp_200(http_t *h) {
  LOG_FUNCTION
  char str[STR_SIZE512], expire_date[STR_SIZE64] = "", current_date[STR_SIZE64] = "", modify_date[STR_SIZE64] = "";
  int len;
  int ret_val;
  time_t t;
  
  static_file_t *ext = get_mime_type(h->stat);
  LOG_DEBUG(DEBUG,"File extension = %s, mimetype = %s, expires = %d ", ext->ext, ext->mime_type, ext->expires);
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  
  t = get_time(current_date, STR_SIZE64);
  time_to_httpdate(h->stat->buf.st_mtime, modify_date, STR_SIZE64);
  
#ifdef W_ZLIB
  ret_val = file_compress(h, ext);
  if(ret_val == FALSE){
#endif
    h->resp->resp_body->len = h->stat->buf.st_size;
    #ifdef _POSIX_C_SOURCE
      h->resp->file = open(h->stat->path, O_RDONLY);
    #else
      h->resp->file = fopen(h->stat->path, "r");
    #endif
#ifdef W_ZLIB
  }
#endif

  if (ext->expires > 0) {
    t += ext->expires;
    time_to_httpdate(t, expire_date, STR_SIZE64);
    len = sprintf(str, "HTTP/1.1 200 OK\r\nDate: %s\r\nServer: %s-%s\r\nLast-Modified: %s\r\nExpires: %s\r\nConnection: %s\r\n%sContent-Type: %s\r\nContent-Length: %d\r\n\r\n",
            current_date, Config->Worker.Server.name.str, Config->Worker.Server.version.str, modify_date, expire_date,
            (conn_header ? conn_header : CONNECTION_CLOSE),
            (ret_val == TRUE ? "Content-Encoding: deflate\r\n" : ""),
            ext->mime_type, h->resp->resp_body->len);
  }else {
    len = sprintf(str, "HTTP/1.1 200 OK\r\nDate: %s\r\nServer: %s-%s\r\nLast-Modified: %s\r\nConnection: %s\r\n%sContent-Type: %s\r\nContent-Length: %d\r\n\r\n",
             current_date, Config->Worker.Server.name.str, Config->Worker.Server.version.str, modify_date,
            (conn_header ? conn_header : CONNECTION_CLOSE),
            (ret_val == TRUE ? "Content-Encoding: deflate\r\n" : ""), 
            ext->mime_type, h->resp->resp_body->len);
  }

  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_200].code;
}

void http_resp_304(http_t *h) {
  LOG_FUNCTION
  char str[STR_SIZE512], expire_date[STR_SIZE64] = "", current_date[STR_SIZE64] = "";
  int len;
  time_t t;
  static_file_t *ext = get_mime_type(h->stat);
  LOG_DEBUG(DEBUG,"File extension = %s, mimetype = %s, expires = %d ", ext->ext, ext->mime_type, ext->expires);
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);

  t = get_time(current_date, STR_SIZE64);
  if (ext->expires > 0) {
    t = t + ext->expires;
    time_to_httpdate(t, expire_date, STR_SIZE64);
    len = sprintf(str, "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nServer: %s-%s\r\nExpires: %s\r\nConnection: %s\r\n\r\n",
            current_date, Config->Worker.Server.name.str, Config->Worker.Server.version.str, expire_date, 
            (conn_header ? conn_header : CONNECTION_CLOSE));
  }else {
    len = sprintf(str, "HTTP/1.1 304 Not Modified\r\nDate: %s\r\nServer: %s-%s\r\nConnection: %s\r\n\r\n",
            current_date, Config->Worker.Server.name.str, Config->Worker.Server.version.str, (conn_header ? conn_header : CONNECTION_CLOSE));
  }

  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_304].code;
}

void http_resp_403(http_t *h) {
  LOG_FUNCTION
  char str[STR_SIZE512], current_date[STR_SIZE64];
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  int len;

  get_time(current_date, STR_SIZE64);
  
  len = sprintf(str, HTTP_RESP_ERR_BODY,
          http_status[HTTP_STATUS_403].phrase, http_status[HTTP_STATUS_403].phrase + 4,
          http_status[HTTP_STATUS_403].message, Config->Worker.Server.name.str, Config->Worker.Server.version.str);
  wr_buffer_create(h->resp->resp_body, len);
  wr_buffer_add(h->resp->resp_body, str, len);

  len = sprintf(str, HTTP_RESP_ERR_HEADERS,
          current_date, http_status[HTTP_STATUS_403].phrase, Config->Worker.Server.name.str, Config->Worker.Server.version.str,
          (conn_header ? conn_header : CONNECTION_CLOSE), len);
  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_403].code;
}

void http_resp_404(http_t *h) {
  LOG_FUNCTION
  char str[STR_SIZE512], current_date[STR_SIZE64];
  const char *conn_header = scgi_header_value_get(h->req->scgi, HTTP_HEADER_CONNECTION);
  int len;
  
  get_time(current_date, STR_SIZE64);

  len = sprintf(str, HTTP_RESP_ERR_BODY,
          http_status[HTTP_STATUS_404].phrase, http_status[HTTP_STATUS_404].phrase + 4,
          http_status[HTTP_STATUS_404].message, Config->Worker.Server.name.str, Config->Worker.Server.version.str);
  wr_buffer_create(h->resp->resp_body, len);
  wr_buffer_add(h->resp->resp_body, str, len);

  len = sprintf(str, HTTP_RESP_ERR_HEADERS,
          current_date, http_status[HTTP_STATUS_404].phrase, Config->Worker.Server.name.str, Config->Worker.Server.version.str,
          (conn_header ? conn_header : CONNECTION_CLOSE), len);
  wr_string_new(h->resp->header, str, len);
  h->resp->resp_code = http_status[HTTP_STATUS_404].code;
}

void send_static_worker_pid() {
  LOG_FUNCTION
  node_t *root = NULL;  
  
  // Read pid queue related configuration
  
  root = yaml_parse(Config->Worker.File.internal_config.str);
  if(root == NULL) {
    LOG_ERROR(SEVERE, "Could not parse server_internal_config.yml file. PID can not be sent to analyzer");
    return;  
  } else {
    char *host = NULL, *port = NULL, *queue_name = NULL;
    wr_msg_queue_server_t *msg_queue_server = NULL;
    wr_msg_queue_conn_t *msg_queue_conn = NULL;
    char msg_value[STR_SIZE32];
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
    rv = sprintf(msg_value, "%s:%d", Config->Worker.static_server.str, getpid());
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


/* Initialize extension and mime-type map */
int static_module_init(static_server_t *s) {
  LOG_FUNCTION
  node_t *root;
  long int expires;
  
  root = yaml_parse(Config->Worker.File.config.str);
  if (root == NULL) {
    LOG_ERROR(SEVERE, "Could not read config.yml file");
    return FALSE;
  }
  expires = get_default_expires(root);
  
  if (create_dictionary(s, Config->Worker.File.mime_type.str, expires) != 0) {
    node_free(root);
    return FALSE;
  }

  set_expires_by_type(s, root);

  node_free(root);
  
  send_static_worker_pid();
  return TRUE;
}

/* Free extension and mime-type map */
void static_module_free(static_server_t *s) {
  LOG_FUNCTION
  int i;
  static_file_t *ext, *next_ext;

  for (i = 0; i <= MAP_SIZE; i++) {
    ext = s->map[i];
    while (ext) {
      next_ext = ext->next;
      free(ext);
      ext = next_ext;
    }
  }
}

/**************************************
 *    Public Functions 
 *************************************/

/** Create new static server */ 
static_server_t * static_server_new(void* ptr){  
  LOG_FUNCTION

  wkr_t* w = (wkr_t*)ptr;

  static_server_t *s = wr_malloc(static_server_t);
  if(s == NULL) return NULL;

#ifdef W_ZLIB
  if(w->tmp->lower_limit > 0)
    Config->Worker.Compress.lower_limit = w->tmp->lower_limit;

  if(w->tmp->upper_limit > 0)
    Config->Worker.Compress.upper_limit = w->tmp->upper_limit;

#ifdef W_REGEX
  s->r_content_type = NULL;
  if(!wr_string_is_empty(w->tmp->r_content_type)){
    int err_no;
    s->r_content_type = wr_malloc(regex_t);
    // #define REG_EXTENDED 1
    if((err_no = regcomp(s->r_content_type, w->tmp->r_content_type.str, 1))!=0){ /* Compile the regex */
      size_t length;
      char *buffer;
      length = regerror (err_no, s->r_content_type, NULL, 0);
      buffer = malloc(length);
      regerror (err_no, s->r_content_type, buffer, length);
      LOG_ERROR(SEVERE, "%s", buffer); /* Print the error */
      LOG_ERROR(SEVERE, "Now Static Workers allow encoding for only 'text' and 'xml' Content-Type.");
      free(buffer);
      regfree(s->r_content_type);
      if((err_no = regcomp(s->r_content_type, "text|xml", 1))!=0){
        regfree(s->r_content_type);
        free(s->r_content_type);
        s->r_content_type = NULL;
      }
    }
  }

  s->r_user_agent = NULL;
  // Do not apply validation on User-Agent if it is not given or it is '.*'(allow all).
  if(!wr_string_is_empty(w->tmp->r_user_agent) && strcmp(w->tmp->r_user_agent.str,".*") != 0){
    int err_no;
    s->r_user_agent = wr_malloc(regex_t);
    if((err_no = regcomp(s->r_user_agent, w->tmp->r_content_type.str, 1))!=0){ /* Compile the regex */
      size_t length;
      char *buffer;
      length = regerror (err_no, s->r_user_agent, NULL, 0);
      buffer = malloc(length);
      regerror (err_no, s->r_user_agent, buffer, length);
      LOG_ERROR(SEVERE, "%s", buffer); /* Print the error */
      LOG_ERROR(SEVERE, "Now Static Workers serves encoded assets to all User-Agent.");
      free(buffer);
      regfree(s->r_user_agent);
      free(s->r_user_agent);
      s->r_user_agent = NULL;
    }
  }
#endif

#endif  

  if(static_module_init(s) == FALSE){
    free(s);
    return NULL;
  }
  wr_buffer_new(s->buffer);

  return s;
}

/** Delete static server */
void static_server_free(static_server_t *s){
  if(s){
    if(s->buffer) wr_buffer_free(s->buffer);
    static_module_free(s);

#if defined(W_ZLIB) && defined(W_REGEX) 
  if(s->r_user_agent){
    regfree(s->r_user_agent);
    free(s->r_user_agent);
  }
  if(s->r_content_type){
    regfree(s->r_content_type);
    free(s->r_content_type);
  }
#endif

    free(s);
  }
}

/* Serve static file content */
void static_file_process(void *http) {
  LOG_FUNCTION
  http_t *h = (http_t*) http;
  wkr_t *w = h->wkr;
  short resp_code;

  h->stat->path = scgi_header_value_get(h->req->scgi, Config->Worker.Header.file_path.str);
  h->stat->modify = scgi_header_value_get(h->req->scgi, HTTP_HEADER_IF_MODIFIED_SINCE);

  LOG_DEBUG(DEBUG, "Path = %s", h->stat->path);
  resp_code = get_resp_code(h->stat);
  http_status[resp_code].fun(h);
  http_req_set(h->req);
  http_resp_process(h->resp);

  ev_io_init(&(w->w_req), http_resp_scgi_write_cb, w->req_fd, EV_WRITE);
  ev_io_start(w->loop, &w->w_req);
}
