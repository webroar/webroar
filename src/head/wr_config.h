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

// Default max_worker
#define WR_MAX_WKR 6
// Default min_worker
#define WR_MIN_WKR 1
// Default request listining port
#define WR_DEFAULT_SVR_PORT 3000

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
#define WR_VERSION "0.2.6"
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

#endif /*WR_CONFIG_H_*/
