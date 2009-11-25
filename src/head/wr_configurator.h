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
#ifndef WR_CONFIGURATOR_H_
#define WR_CONFIGURATOR_H_

#include<wr_helper.h>

/** Configuration parameter macros */
#define WR_CONF_SVR_PORT           "Server Specification/port"
#define WR_CONF_SVR_MAX_WKR       "Server Specification/max_worker"
#define WR_CONF_SVR_MIN_WKR       "Server Specification/min_worker"
#define WR_CONF_SVR_LOG_LEVEL       "Server Specification/log_level"
#define WR_CONF_SVR_ACCESS_LOG     "Server Specification/access_log"

#define WR_CONF_SVR_SSL_SUPPORT    "Server Specification/SSL Specification/ssl_support"

#ifdef HAVE_GNUTLS
#define WR_CONF_SVR_SSL_CERTIFICATE   "Server Specification/SSL Specification/certificate_file"
#define WR_CONF_SVR_SSL_KEY         "Server Specification/SSL Specification/key_file"
#define WR_CONF_SVR_SSL_PORT      "Server Specification/SSL Specification/ssl_port"
#endif

#define WR_CONF_APP_SPEC           "Application Specification"
#define WR_CONF_APP_NAME           "name"
#define WR_CONF_APP_BASE_URI       "baseuri"
#define WR_CONF_APP_PATH           "path"
#define WR_CONF_APP_TYPE           "type"
#define WR_CONF_APP_ANALYTICS       "analytics"
#define WR_CONF_APP_USER           "run_as_user"
#define WR_CONF_APP_ENV           "environment"
#define WR_CONF_APP_LOG_LEVEL       "log_level"
#define WR_CONF_APP_MAX_WKR       "max_worker"
#define WR_CONF_APP_MIN_WKR       "min_worker"
#define WR_CONF_APP_HOST_NAMES    "host_names"

#define WR_CONF_MAX_LEN_APP_NAME  30
#define WR_CONF_MAX_LEN_USR_NAME  30

// using 'AF_UNIX' macro to identify UDS support.
//#define WR_CONF_UDS    1

typedef enum wr_host_type_e{
  WR_HOST_TPE_INVALID                  = 0,
  WR_HOST_TYPE_STATIC                  = 1,
  WR_HOST_TYPE_WILDCARD_IN_START      = 2,
  WR_HOST_TYPE_WILDCARD_IN_END        = 4,
  WR_HOST_TYPE_WILDCARD_IN_START_END   = 8,
}wr_host_type_t;

typedef struct wr_host_name_s  wr_host_name_t;
struct wr_host_name_s {
  wr_str_t        name;
  wr_host_type_t    type;
  wr_host_name_t   *next;
};

#define WR_SVR_ACCESS_LOG    1
#define WR_SVR_SSL_SUPPORT  2


/** server_configuration structure */
typedef struct {
  wr_u_int     port;              /**< Server port*/
  wr_u_short    min_worker;    /**< Default number of minimum workers */
  wr_u_short    max_worker;    /**< Default number of maximum workers */
  LOG_SEVERITY   log_level;  /**< Logging level */
  //If WR_CONF_UDS is 1 'contol_sock_path' has UDS sock path
  //If WR_CONF_UDS is 0 'port' has Internet socket port
  wr_u_short    ctl_port;          /**< Server control port*/
  wr_str_t      sock_path;    /**< Server control socket path in case of UNIX domain socket*/
#ifdef HAVE_GNUTLS

  wr_str_t      certificate;    /**< Certificate path */
  wr_str_t      key;        /**< Key path */
  wr_u_short    ssl_port;      /**< SSL listening port */
#endif

  short         flag;
}wr_svr_conf_t;

/** application_configuration structure */
typedef struct wr_app_conf_s  wr_app_conf_t;
struct wr_app_conf_s {
  wr_str_t      name;        /**< Application name */
  wr_str_t      path;  /**< Application path */
  wr_str_t      env;    /**< Application environment */
  wr_str_t      type;        /**< Application type {rails, merb etc.}*/
  short        analytics;      /**< analytics flag {enabled/disabled} */
  wr_str_t      baseuri;      /**< Application baseuri */
  wr_u_short     min_worker;       /**< Minimum number of workers required */
  wr_u_short    max_worker;      /**< Maximum number of workers */
  LOG_SEVERITY   log_level;    /**< Logging level */
  short        cuid;        /**< User id */
  short        cgid;        /**< Group id */
  wr_host_name_t   *host_name_list;
  wr_app_conf_t     *next;
};

typedef struct wr_conf_s  wr_conf_t;
/** Remove application_configuration from configuration */
int wr_app_conf_remove(wr_conf_t*, const char *app_name);
/** Read application configuration of specified application name */
wr_app_conf_t* wr_conf_app_read(wr_conf_t*, const char *app_name, char* err_msg);

/** configuration structure */
struct wr_conf_s {
  wr_svr_conf_t    *server;    /**< Server configuration */
  wr_app_conf_t     *apps;  /**< Application configuration */
  wr_str_t        wr_root_path;      /**< WebROaR root path */
  wr_str_t        wkr_exe_path;  /**< worker's executable path*/
  wr_str_t        ruby_lib_path;        /**< Ruby library path */
  wr_str_t        config_file_path;      /**< Configuration file path */
  wr_str_t        admin_panel_path;        /**< Admin Panel path */
  short           uds;          /**< UNIX domain socket flag(controlling flag) */
};

/** Read 'config.yml' file and fill configuration data structure */
wr_conf_t* wr_conf_read(const char* root_path);
/** Destroy configuration data structure */
void wr_conf_free(wr_conf_t*);
/** Display configuration data structure */
void wr_conf_display(wr_conf_t*);
/** Add Admin Panel to configuration data structure */
int wr_conf_admin_panel_add(wr_conf_t*);
/** Add the configuration for static content server */
int wr_conf_static_server_add(wr_conf_t*);
#endif /*WR_CONFIGURATOR_H_*/
