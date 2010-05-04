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

#include <wr_string.h>
#include <wr_macro.h>
#include <wr_logger.h>

// Default max_worker
#define WR_MAX_WKR 8
// Default min_worker
#define WR_MIN_WKR 4
// Default request listining port
#define WR_DEFAULT_SVR_PORT 3000

// Maximum value allowed for number of workers
#define WR_ALLOWED_MAX_WORKERS 20

#define WR_MAX_PENDING_WKR 10
#define WR_MAX_ADD_TIMEOUT_COUNTER 3
#define WR_WKR_ADD_WAIT_TIME 1800.

#ifdef HAVE_GNUTLS
// Default SSL listining port
#define WR_DEFAULT_SSL_PORT 443
#endif

// Default application environment
#define WR_DEFAULT_ENV "production"
// Admin Panel base uri
#define WR_ADMIN_PANEL_BASE_URL "/admin-panel"
// Admin Panel base uri
#define WR_ADMIN_PANEL_APP_NAME "Admin Panel"
// Parameter value to enable application analytics
#define WR_ANALYTICS_ON "enabled"

// Appliction to serve static files
#define WR_STATIC_FILE_SERVER_NAME "static-worker"
// Minimum number of worker to serve static content
#define WR_STATIC_SVR_MIN_WKR 4
// Maximum number of worker to serve static content
#define WR_STATIC_SVR_MAX_WKR 8
#define WR_HTTP_FILE_PATH        "FILE_PATH"
#define WR_HTTP_FILE_PATH_LEN      9

#define RESP_CODE               "RESP_CODE"
#define RESP_CONTENT_LENGTH   "RESP_CONTENT_LEN"
#define SCGI_CONTENT_LENGTH "CONTENT_LENGTH"

/** Folder and file related macros */
// Server control sock path
#define WR_CTL_SOCK_PATH "/tmp/webroar_controller_sock"
// 'webroar-worker' request listining sock path
#define WR_WKR_SOCK_PATH "/tmp/webroar_worker_sock"
// Server log file name
#define WR_LOG_FILE "webroar.log"
// Server configuration file name
#define WR_CONF_FILE "config.yml"
// Path seperator
#define WR_PATH_SEPARATOR "/"
// Ruby library folder  name
#define WR_RUBY_LIB_DIR "ruby_lib"
// Admin Panel folder name
#define WR_ADMIN_PANEL_DIR "admin_panel"
// Source folder name
#define WR_SRC_DIR "src"
// Executable directory name
#define WR_BIN_DIR "bin"
// File to store Server control port or sock path
#define WR_TMP_SOCK_FILE  "/tmp/webroar.sock"
// File to store process pid having high resident memory
#define WR_HIGH_RSS_PID_FILE  "/var/run/high_rss.pid"
// Executable file name used to create workers
#define WR_WKR_BIN "webroar-worker"
// File to store Server process id
#define WR_PID_FILE  "/var/run/webroar.pid"
#define WR_SERVER "WebROaR"
#define WR_VERSION "0.3.2"
#define WR_MIME_TYPE_PATH "/conf/mime_type.yml"
#define WR_CONF_PATH "/conf/config.yml"
#define WR_SERVER_INTERNAL_CONF_PATH "/conf/server_internal_config.yml"

/** Private macros */
/** Application level macros */
// Pending request queue size
#define WR_MSG_QUE_SIZE 2048
// Ratio of pending request and active worker required to add worker
#define WR_MAX_REQ_RATIO 1
// Ratio of pending request and active worker required to remove worker
#define WR_MIN_REQ_RATIO 3
// Number of seconds with ratio higher than WR_MAX_REQ_RATIO to add worker.
#define WR_HIGH_LOAD_LIMIT 2.
// Number of seconds with ratio lower than WR_MIN_REQ_RATIO to remove worker.
#define WR_LOW_LOAD_LIMIT 600.
// Number of seconds to wait for add signal from worker after incrementing the active worker count
#define WR_WKR_ADD_TIMEOUT 25.
// Number of seconds to wait for response before killing worker.
#define WR_WKR_KILL_TIMEOUT 10.

// Number of seconds worker can remain idle, before sending PING.
#define WR_WKR_IDLE_TIME 60.
// Number of seconds head should wait for PING reply.
#define WR_PING_WAIT_TIME 15.
// Number of time head should try sending PING before killing worker.
#define WR_PING_TRIALS 2

//Number of seconds head would wait before closing the connection for kepp-alive request
#define WR_SVR_KEEP_ALIVE       1
#define WR_SVR_KEEP_ALIVE_TIME   15.

// Request body more than this size sholud store in file
#define WR_REQ_BODY_MAX_SIZE 1024*64
// Bufffer size to store request headers in 'webroar-worker'
#define WR_BUF_SIZE (1024 * 10)

#define WR_TINY_STR_LEN            16
#define WR_SHORT_STR_LEN          32
#define WR_STR_LEN                64
#define WR_LONG_STR_LEN            128
#define WR_LONG_LONG_STR_LEN      512
#define WR_FILE_PATH_LEN          1024

#define WR_DEFAULT_PREFIX_HASH    5381
#define WR_MSG_SIZE              1024

#define WR_REQ_CONN_POOL         10
#define WR_CTL_CONN_POOL        5

/** Request size limitation **/
#define WR_MAX_REQ_URI_LEN            12288    /* 12*1024 */
#define WR_MAX_REQ_PATH_LEN          1024
#define WR_MAX_REQ_FRAG_LEN      1024
#define WR_MAX_REQ_QRY_STR_LEN      10240    /* 10*1024 */
#define WR_MAX_REQ_FIELD_NAME_LEN      256      /*  */
#define WR_MAX_REQ_FIELD_VALUE_LEN      81920    /* 80*1024 */
#define WR_MAX_REQ_HEADER_LEN        112640  /* (1024 * (80 + 32)) */
#define WR_MAX_REQ_HEADER_NO          40

#define WR_STACKTRACE_SIZE 50

#ifdef L_DEBUG
#define WR_CONN_ID      "CONNECTION_ID"
#define WR_CONN_ID_LEN    19
#define WR_REQ_ID        "REQ_ID"
#define WR_REQ_ID_LEN      12
#endif

#define WR_MAX_HOST_NAMES 16

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
    wr_str_t    name;
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
  wr_str_t        path;       /**< Application path */
  wr_str_t        env;        /**< Application environment */
  wr_str_t        type;       /**< Application type {rails, merb etc.}*/
  wr_u_short      analytics;  /**< analytics flag {enabled/disabled} */
  wr_str_t        baseuri;    /**< Application baseuri */
  wr_u_short      min_worker; /**< Minimum number of workers required */
  wr_u_short      max_worker; /**< Maximum number of workers */
  LOG_SEVERITY    log_level;  /**< Logging level */
  short           cuid;       /**< User id */
  short           cgid;       /**< Group id */
  
  config_host_list_t          *host_name_list;
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

#endif /*WR_CONFIG_H_*/
