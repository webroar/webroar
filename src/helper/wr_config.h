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
#ifndef WR_CONFIG_H_
#define WR_CONFIG_H_

#include<wr_string.h>
#include<wr_macro.h>
#include<wr_logger.h>
#include<wr_scgi.h>
#include<wr_yaml_parser.h>

#define TRUE  1
#define FALSE 0

#define STR_SIZE16    16
#define STR_SIZE32    32
#define STR_SIZE64    64
#define STR_SIZE128   128
#define STR_SIZE256   256
#define STR_SIZE512   512
#define STR_SIZE1KB   1024
#define STR_SIZE10KB  10240

#define SERVER_ACCESS_LOG   1
#define SERVER_SSL_SUPPORT  2
#define SERVER_UDS_SUPPORT  4
#define SERVER_KEEP_ALIVE   8
#define SERVER_ADMIN_PANEL  16
#define SERVER_ANALYZER   	32  // For future use

typedef struct config_server_s{
  
  struct control{
    wr_str_t    sock_path;
    wr_u_short  conn_pool;
  }Control;
  
  struct file{
    wr_str_t    log;
    wr_str_t    pid;
    wr_str_t    config;
    wr_str_t    sock;
    wr_str_t    high_rss;
    wr_str_t    worker_bin;
    wr_str_t    internal_config;
  }File;
  
  struct dir{
    wr_str_t    admin_panel;
    wr_str_t    root;
  }Dir;
  
  struct worker{
    wr_u_short  max;
    wr_u_short  pending;
    wr_u_short  add_trials;
    wr_u_short  add_wait;
    wr_u_short  add_timeout;
    wr_u_short  kill_timeout;
    wr_u_short  idle_time;
    wr_u_short  ping_timeout;
    wr_u_short  ping_trials;
  }Worker;
  
#ifdef HAVE_GNUTLS
  struct ssl{
    wr_u_int    port;
    wr_str_t    certificate;
    wr_str_t    key;
  }SSL;
#endif
  
  wr_str_t    name;
  wr_str_t    version;
  wr_u_int    port;

  LOG_SEVERITY log_level;
  wr_u_short  flag; // To store different bit level flags like access_log, ssl_support, uds support
  wr_u_short  stack_trace;
  
}config_server_t;


typedef struct config_request_s{
  wr_u_short    prefix_hash;
  wr_u_short    conn_pool;
  wr_u_long     max_body_size;
  wr_u_int      max_uri_size;
  wr_u_short    max_path_size;
  wr_u_short    max_frag_size;
  wr_u_short    max_query_size;
  wr_u_short    max_field_size;
  wr_u_long     max_value_size;
  wr_u_long     max_header_size;
  wr_u_short    max_header_count;
  
  struct header{
  #ifdef L_DEBUG
    wr_str_t      conn_id;
    wr_str_t      req_id;
  #endif
    wr_str_t      file_path;
    wr_str_t      resp_code;
    wr_str_t      resp_content_len;
  }Header;
  
}config_request_t;

typedef enum config_host_type_s{
  HOST_TPE_INVALID                 = 0,
  HOST_TYPE_STATIC                 = 1,
  HOST_TYPE_WILDCARD_IN_START      = 2,
  HOST_TYPE_WILDCARD_IN_END        = 4,
  HOST_TYPE_WILDCARD_IN_START_END  = 8,
}config_host_type_t;

typedef struct config_host_list_s  config_host_list_t;
struct config_host_list_s {
  wr_str_t            name;
  config_host_type_t  type;
  config_host_list_t  *next;
};

typedef struct config_application_list_s config_application_list_t;
struct config_application_list_s {
  wr_str_t        name;       /**< Application name */
  wr_str_t        baseuri;    /**< Application baseuri */
  wr_str_t        path;    /**< Application path */
  wr_u_short      min_worker; /**< Minimum number of workers required */
  wr_u_short      max_worker; /**< Maximum number of workers */
  LOG_SEVERITY    log_level;  /**< Logging level */
  
  scgi_t          *scgi;
  config_host_list_t          *host_name_list;
  config_application_list_t   *new;
  config_application_list_t   *next;
};


typedef struct config_application_s{
  
  struct application_default{
    wr_u_short  max_workers;
    wr_u_short  min_workers;
    wr_str_t    env;
  }Default;
  
  struct admin_panel{
    wr_str_t   name;
    wr_str_t   base_uri;
  }Admin_panel;
  
  struct static_server{
    wr_str_t    name;
    wr_u_short  min_workers;
    wr_u_short  max_workers;
  }Static_server;
  
  wr_str_t    analytics_on;
  wr_u_int    msg_queue_size;
  wr_u_short  max_req_ratio;
  wr_u_short  min_req_ratio;
  wr_u_short  high_load;
  wr_u_short  low_load;
  wr_u_short  max_hosts;
  
  config_application_list_t *list;
  
}config_application_t;

typedef struct config_worker_s{
  
  struct worker_file{
    wr_str_t    config;
    wr_str_t    mime_type;
    wr_str_t    internal_config;
    wr_str_t    app_loader;
  }File;
  
  struct worker_header{
    wr_str_t    file_path;
    wr_str_t    conn_id;
    wr_str_t    req_id;
    wr_str_t    resp_code;
    wr_str_t    resp_content_len;
  }Header;
  
  struct server{
    wr_str_t    name;
    wr_str_t    version;
  }Server;
  
  struct compress{
    wr_u_long lower_limit;
    wr_u_long upper_limit;
  }Compress;
  
  wr_str_t    static_server;
  wr_str_t    sock_path;
  wr_u_short  stack_tace;
  wr_u_long   max_body_size;
  
}config_worker_t;

typedef struct config_s{
  config_server_t       Server;
  config_request_t      Request;
  config_worker_t       Worker;
  config_application_t  Application;
}config_t;

config_t* wr_server_config_init(const char* root_path);
config_t* wr_worker_config_init(const char* root_path);

void wr_server_config_free(config_t *Config);
void wr_worker_config_free(config_t *Config);
void wr_application_list_free(config_application_list_t* list);

void wr_set_numeric_value(node_t *root, const char *path, void *value, wr_u_short flag);
  
#endif /*WR_CONFIG_H_*/
