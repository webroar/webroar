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
 *          Implementation of CONFIGURATOR module
 *****************************************************************************/

#include <wr_configurator.h>
#include <wr_config.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <pwd.h>

/*********************************************************
 *     Private function definitions
 **********************************************************/

static void wr_host_name_free(wr_host_name_t *host) {
  LOG_FUNCTION
  wr_host_name_t *next;
  while(host) {
    next = host->next;
    wr_string_free(host->name);
    free(host);
    host = next;
  }
}

/** Destroy application configuration */
void wr_conf_app_free(wr_app_conf_t* app) {
  LOG_FUNCTION
  wr_app_conf_t* next;

  // Iterate applications and destroy each application
  while(app) {
    next = app->next;
    wr_string_free(app->name);
    wr_string_free(app->path);
    wr_string_free(app->env);
    wr_string_free(app->type);
    wr_string_free(app->baseuri);
    wr_host_name_free(app->host_name_list);
    free(app);
    app = next;
  }
}

/** Create new application configuration with default values inherited from server configuration */
static inline wr_app_conf_t* wr_app_conf_new(wr_svr_conf_t *server) {
  LOG_FUNCTION
  wr_app_conf_t* app = wr_malloc(wr_app_conf_t);
  app->log_level = server->log_level;
  app->min_worker = server->min_worker;
  app->max_worker = server->max_worker;
  app->cgid = -1;
  app->cuid = -1;
  wr_string_null(app->name);
  wr_string_null(app->path);
  wr_string_null(app->baseuri);
  wr_string_null(app->env);
  wr_string_null(app->type);
  app->analytics = FALSE;
  app->host_name_list = NULL;
  app->next = NULL;
  return app;
}

/** Create new configuration with default values */
static inline wr_conf_t* wr_conf_new() {
  LOG_FUNCTION
  wr_conf_t         *conf;

  conf = wr_malloc(wr_conf_t);
  if(conf == NULL) {
    return NULL;
  }
  conf->server = wr_malloc(wr_svr_conf_t);
  if(conf->server == NULL) {
    free(conf);
    return NULL;
  }

  //Setting default values, can be override by specifying into config.yml
  //conf->no_of_application = 0;
  // Check for POSIX system and set UDS flag
#ifdef AF_UNIX
  conf->uds = 1;
#else
  conf->uds = 0;
#endif
  //conf->uds = WR_CONF_UDS;

  conf->server->port = WR_DEFAULT_SVR_PORT;
  conf->server->min_worker = WR_MIN_WKR;
  conf->server->max_worker = WR_MAX_WKR;
  conf->server->log_level = SEVERE;
  conf->server->flag = 0;
  conf->server->ctl_port = 0;
  wr_string_null(conf->server->sock_path);
#ifdef HAVE_GNUTLS

  wr_string_null(conf->server->certificate);
  wr_string_null(conf->server->key);
  conf->server->ssl_port = WR_DEFAULT_SSL_PORT;
#endif

  wr_string_null(conf->wr_root_path);
  wr_string_null(conf->wkr_exe_path);
  wr_string_null(conf->admin_panel_path);
  wr_string_null(conf->ruby_lib_path);
  wr_string_null(conf->config_file_path);

  conf->apps = NULL;

  return conf;
}

/** Initialize configuration path variables */
static inline void wr_init_path(wr_conf_t *conf, const char *root_path) {

  LOG_FUNCTION
  size_t len;
  char str[WR_LONG_LONG_STR_LEN];

  // set WebROaR root fodler path
  len = strlen(root_path);
  wr_string_new(conf->wr_root_path, root_path, len);

  // Set configuration file path
  len = sprintf(str,"%s%sconf%s%s",
                root_path, WR_PATH_SEPARATOR,
                WR_PATH_SEPARATOR,WR_CONF_FILE);
  wr_string_new(conf->config_file_path, str, len);

  // Set the 'webroar-worker' file path
  len = sprintf(str,"%s%s%s%s%s",root_path, WR_PATH_SEPARATOR,
                WR_BIN_DIR, WR_PATH_SEPARATOR,
                WR_WKR_BIN);
  wr_string_new(conf->wkr_exe_path, str, len);

  // Set ruby lib folder path
  len = sprintf(str,"%s%s%s%s%s",
                root_path, WR_PATH_SEPARATOR,
                WR_SRC_DIR, WR_PATH_SEPARATOR,
                WR_RUBY_LIB_DIR);
  wr_string_new(conf->ruby_lib_path, str, len);

  // Set Admin Panel folder path
  len = sprintf(str,"%s%s%s%s%s",
                root_path, WR_PATH_SEPARATOR,
                WR_SRC_DIR, WR_PATH_SEPARATOR,
                WR_ADMIN_PANEL_DIR);
  wr_string_new(conf->admin_panel_path, str, len);
}

/** Validate YAML tokens */
static inline char* wr_validate_string(const char* str) {
  int count, len, is_blank, is_comment;

  if(str == NULL)
    return NULL;

  //Set flags
  is_blank = 1;
  is_comment = 0;
  len = strlen(str);
  for(count = 0; count < len ; count++) {
    //check for blank value
    if(str[count] != ' ') {
      is_blank = 0;
    }
    //check for comment '#' character
    if(str[count] == '#') {
      is_comment = 1;
      break;
    }
  }
  if(is_comment || is_blank) {
    LOG_ERROR(SEVERE,"Invalid token.");
    return NULL;
  }
  return (char*)str;
}

/** Set Server Configuration */
static inline int wr_conf_server_set(wr_conf_t * conf, node_t *root) {
  LOG_FUNCTION
  wr_svr_conf_t  *server = conf->server;
  char *str;

  // Set server listening port
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_PORT));
  if(str)
    server->port = atoi(str);

  if(server->port < 0 || server->port > 65536) {
    LOG_ERROR(SEVERE,"Valid port should be a number between 1 and 65536. Server can not start.");
    printf("Valid port should be a number between 1 and 65536. Server can not start.\n");
    return -1;
  }

  // Set min_worker
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_MIN_WKR));
  if(str) {
    server->min_worker = atoi(str);
    if(server->min_worker > WR_ALLOWED_MAX_WORKERS) {
      LOG_ERROR(SEVERE, "Server Specification: Minimum workers should be a number between 1 and %d. Server can not start.", WR_ALLOWED_MAX_WORKERS);
      printf("Server Specification: Minimum workers should be a number between 1 and %d. Server can not start.\n", WR_ALLOWED_MAX_WORKERS);
      return -1; 
    }
  }
  
  // Set max_worker
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_MAX_WKR));
  if(str) {
    server->max_worker = atoi(str);
    if(server->max_worker > WR_ALLOWED_MAX_WORKERS) {
      LOG_ERROR(SEVERE, "Server Specification: Maximum workers should be a number between 1 and %d. Server can not start.", WR_ALLOWED_MAX_WORKERS);
      printf("Server Specification: Maximum workers should be a number between 1 and %d. Server can not start.\n", WR_ALLOWED_MAX_WORKERS);
      return -1; 
    }
  }
  
  if(server->min_worker > server->max_worker) {
    LOG_ERROR(SEVERE,"Server Specification: Min worker value is greater than Max worker value. Server can not start.");
    printf("Server Specification: Min worker value is greater than Max worker value. Server can not start.\n");
    return -1;
  }

  // Set logging level
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_LOG_LEVEL));
  if(str)
    server->log_level = get_log_severity(str);

  // Set access log flag
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_ACCESS_LOG));

  if(str && strcmp(str,"enabled")==0 ) {
    server->flag |= WR_SVR_ACCESS_LOG;
  }

  //check ssl support
  str = wr_validate_string(get_node_value(root, WR_CONF_SVR_SSL_SUPPORT));
  if(str && strcmp(str,"enabled")==0 ) {
    server->flag |= WR_SVR_SSL_SUPPORT;
  }

#ifdef HAVE_GNUTLS

  if(server->flag&WR_SVR_SSL_SUPPORT) {
  	size_t len;
    struct stat buff;
    // Set certificate path
    str = wr_validate_string(get_node_value(root, WR_CONF_SVR_SSL_CERTIFICATE));
    if(str) {
      if(stat(str,&buff)!=0) {
        LOG_ERROR(SEVERE,"SSL certificate file path(%s) invalid. Server can not run on SSL.",str);
        printf("SSL certificate file path(%s) invalid. Server can not run on SSL.\n",str);
        server->flag &= (!WR_SVR_SSL_SUPPORT);
      } else {
        len = strlen(str);
        wr_string_new(server->certificate, str, len);
      }
    } else {
      LOG_ERROR(SEVERE,"Certificate file path is missing. Server can not run on SSL.");
      printf("Certificate file path is missing. Server can not run on SSL.\n");
      server->flag &= (!WR_SVR_SSL_SUPPORT);
    }

    // Set certificate path
    str = wr_validate_string(get_node_value(root, WR_CONF_SVR_SSL_KEY));
    if(str) {
      if(stat(str,&buff)!=0) {
        LOG_ERROR(SEVERE,"SSL key file path(%s) invalid. Server can not run on SSL.",str);
        printf("SSL key file path(%s) invalid. Server can not run on SSL.\n",str);
        server->flag &= (!WR_SVR_SSL_SUPPORT);
      } else {
        len = strlen(str);
        wr_string_new(server->key, str, len);
      }
    } else {
      LOG_ERROR(SEVERE,"SSL key file path is missing. Server can not run on SSL.");
      printf("SSL key file path is missing. Server can not run on SSL.\n");
      server->flag &= (!WR_SVR_SSL_SUPPORT);
    }

    // Set server listening port
    str = wr_validate_string(get_node_value(root, WR_CONF_SVR_SSL_PORT));
    if(str) {
      server->ssl_port = atoi(str);
      if(server->ssl_port < 0 || server->ssl_port > 65536) {
        LOG_ERROR(SEVERE,"Given SSL port is invalid. Valid port should be a number between 1 and 65536. Server can not run on SSL.");
        printf("Given SSL port is invalid. Valid port should be a number between 1 and 65536. Server can not run on SSL.\n");               
        server->flag &= (!WR_SVR_SSL_SUPPORT);
      }
    } else {
      server->ssl_port = WR_DEFAULT_SSL_PORT;
    }
  }

#endif

  return 0;
}

static int wr_validate_app_host_name(const char *host_name, char *err_msg) {
  LOG_FUNCTION
  int down_level = 1, label_len, i;
  char *label = NULL;
  char tmp_host[256];
  size_t len;

  if(!host_name) {
    return -1;
  }
  len = strlen(host_name);

  //wr_string_new(tmp_host, host_name, len);

  //Checking generic validation for domain name
  //whole domain name may not exceed total length of 253
  if(len > 253) {
    if(err_msg)
      sprintf(err_msg+strlen(err_msg), "Length of host name %s exceeds 253\n", host_name);
    LOG_ERROR(WARN,"Length of host name %s exceeds 253", host_name);
    goto err_ret;
  }
  strncpy(tmp_host, host_name, len);
  tmp_host[len] = 0;
  //there should be a label between two consicutive dot(.)
  if(strstr(tmp_host,"..")) {
    if(err_msg)
      sprintf(err_msg+strlen(err_msg), "Host name %s have consecutive dots. Please enter it again.\n",host_name);      
    LOG_ERROR(WARN,"Host name %s have consecutive dots. Please enter it again",host_name);
    goto err_ret;
  }
  // there can be wildcard(*) at start or at end.
  // following condition check for * at end
  label = strstr(tmp_host+1,"*");
  if(label && label[1] != 0) {
    if(err_msg)
      sprintf(err_msg+strlen(err_msg), "%s - Hostname can only have the wildcard character either at start or at end. Please enter it again.\n",host_name);
    LOG_ERROR(WARN, "%s - Hostname can only have the wildcard character either at start or at end. Please enter it again.",host_name);
    goto err_ret;
  }
  label = NULL;

  label = strtok(tmp_host, ".");
  while(label) {
    down_level++;
    //Subdivision can go down 127 levels. Each label can contain up to 63 octets.
    label_len = strlen(label);
    if((label_len <1 || label_len > 63) || down_level > 127) {
      if(err_msg)
        sprintf(err_msg+strlen(err_msg),"Host name %s - either label length exceeds 63 characters or Subdivision exceeds 127 levels\n", host_name);
      LOG_ERROR(WARN,"Host name %s - either label length exceeds 63 characters or Subdivision exceeds 127 levels", host_name);
      goto err_ret;
    }
    //Check against LDH(Letters, Digits, Hypen)
    for(i=0;i<label_len;i++) {
      char c = label[i];
      if(label_len == 1 && c == '*') {
        break;
      }
      if(!((c >= 'a' && c<= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || (c == '-') || (c == '*'))) {
        if(err_msg)
          sprintf(err_msg+strlen(err_msg),"Hostname can contain only letters in upper or lower case, digits, hyphen and dot(.) to separate the labels. Host name-%s contains invalid character-%c.\n",host_name,c);
        LOG_ERROR(WARN,"Hostname can contain only letters in upper or lower case, digits, hyphen and dot(.) to separate the labels. Host name-%s contains invalid character-%c.",host_name,c);
        goto err_ret;
      }
    }
    label = strtok(NULL,".");
  }
  //wr_string_free(tmp_host);
  return 0;

err_ret:
  //wr_string_free(tmp_host);
  return -1;
}

static int wr_app_host_name_set(wr_app_conf_t *app, char *host_names, char *err_msg) {
  LOG_FUNCTION
  char *host = NULL;
  wr_host_name_t *hosts = NULL, *tmp_host = NULL;
  int rv;
  size_t len;

  if(!app || !host_names) {
    return -1;
  }

  host = strtok(host_names, " ");
  while(host) {

    if(host[0]=='~') {
      rv = wr_validate_app_host_name(host+1, err_msg);
    } else {
      rv = wr_validate_app_host_name(host, err_msg);
    }

    if(rv != 0)
      return -1;

    len = strlen(host);
    tmp_host = wr_malloc(wr_host_name_t);
    if(tmp_host == NULL)
      return -1;

    tmp_host->next = NULL;
    tmp_host->type = WR_HOST_TPE_INVALID;
    //storing plain name, removing any '*', and '~'
    if(host[1] == '*') {
      if(host[len-1] == '*') {
        tmp_host->type = WR_HOST_TYPE_WILDCARD_IN_START_END;
        wr_string_new(tmp_host->name, host+2, len-3);
      } else {
        tmp_host->type = WR_HOST_TYPE_WILDCARD_IN_START;
        wr_string_new(tmp_host->name, host+2, len-2);
      }
      LOG_DEBUG(DEBUG, "Host name = %s", tmp_host->name.str);
    } else if(host[len-1] == '*') {
      tmp_host->type = WR_HOST_TYPE_WILDCARD_IN_END;
      wr_string_new(tmp_host->name, host+1, len-2);
      LOG_DEBUG(DEBUG, "Host name = %s", tmp_host->name.str);
    } else {
      tmp_host->type = WR_HOST_TYPE_STATIC;
      if(host[0] == '~') {
        wr_string_new(tmp_host->name, host+1, len-1);
      } else {
        wr_string_new(tmp_host->name, host, len);
      }
      LOG_DEBUG(DEBUG, "Host name = %s", tmp_host->name.str);
    }

    if(app->host_name_list == NULL) {
      app->host_name_list = hosts = tmp_host;
    } else {
      hosts->next = tmp_host;
    }

    host = strtok(NULL, " ");
  }
  return 0;
}

/** Create and fill application configuration */
static inline wr_app_conf_t* wr_app_conf_set (wr_conf_t* conf, node_t* app_node, char* err_msg) {
  LOG_FUNCTION
  wr_app_conf_t *app = NULL;
  struct stat buff;
  char *str, *app_name;
  short free_app_obj = 0;
  size_t len;

  // Create application configuration with default values
  app = wr_app_conf_new(conf->server);

  if(!app) {
    return NULL;
  }

  //Set application name
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_NAME));
  len = strlen(str);  
  if(str && len > 0 && len < WR_CONF_MAX_LEN_APP_NAME) {    
    wr_string_new(app->name, str, len);
    LOG_DEBUG(DEBUG, "Application Name = %s", app->name.str);
    app_name = str;
  } else if(len > WR_CONF_MAX_LEN_APP_NAME) {
    LOG_ERROR(WARN, "Application name is too long. Maximum is %d characters", WR_CONF_MAX_LEN_APP_NAME);
    printf("Application name is too long. Maximum is %d characters\n", WR_CONF_MAX_LEN_APP_NAME);
    if(err_msg)
      sprintf(err_msg,"\n Application name is too long. Maximum is %d characters", WR_CONF_MAX_LEN_APP_NAME);
    wr_conf_app_free(app);
    return NULL;
  } else {
    LOG_ERROR(SEVERE,"Application name is missing");
    printf("Application name is missing.\n");
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication name is missing.");
    wr_conf_app_free(app);
    return NULL;
  }

  // Set application path
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_PATH));
  if(str && strlen(str) > 0) {
    //Check existence of application path
    if(stat(str,&buff)!=0) {
      LOG_ERROR(SEVERE,"Application path: %s does not exists. Application %s not started.",str,app_name);
      printf("Application path: %s does not exists. Application %s not started.\n",str,app_name);
      if(err_msg)
        sprintf(err_msg+strlen(err_msg),"\nApplication path: %s does not exists. Application %s not started.",str,app_name);
      //wr_conf_app_free(app); return NULL;
      free_app_obj = 1;
    }
    len = strlen(str);
    wr_string_new(app->path, str, len);
    LOG_DEBUG(DEBUG, "Application Path = %s", app->path.str);
  } else {
    LOG_ERROR(SEVERE,"Application path for %s is missing. Application not started.", app_name);
    printf("Application path for %s is missing. Application not started\n", app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication path for %s is missing. Application not started", app_name);
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application type
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_TYPE));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    wr_string_new(app->type, str, len);
    LOG_DEBUG(DEBUG, "Application Type = %s", app->type.str);
  } else {
    LOG_ERROR(SEVERE,"Application type for %s is missing", app_name);
    printf("Application type for %s is missing\n", app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"Application type is missing.");
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application analytics
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_ANALYTICS));
  if(str && strlen(str) > 0) {
    LOG_DEBUG(DEBUG,"App analytics = %s", str);
    if(strcmp(str,WR_ANALYTICS_ON)==0) {
      app->analytics = TRUE;
    }
  } else {
    LOG_ERROR(SEVERE,"Application analytics for %s is missing. Application not started.",app_name);
    printf("Application analytics for %s is missing. Application not started.\n",app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication analytics for %s is missing. Application not started.",app_name);
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application base uri
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_BASE_URI));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    wr_string_new(app->baseuri, str, len);
    LOG_DEBUG(DEBUG, "Application Baseuri = %s", app->baseuri.str);
  }

  // Set Host names (used for multiple host deployment and application identifiaction)
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_HOST_NAMES));
  if(str && strlen(str) > 0) {
    wr_app_host_name_set(app, str, err_msg);
  }

  // Set application user & group id
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_USER));
  if(str && strlen(str) > 0) {
    struct passwd *user_info=NULL;
    user_info = getpwnam(str);
    // Check for user existence
    if(user_info) {
      app->cuid = user_info->pw_uid;
      app->cgid = user_info->pw_gid;
    } else {
      LOG_ERROR(SEVERE,"Application run_as_user for %s is invalid. Application not started.",app_name);
      printf("Application run_as_user for %s is invalid. Application not started.\n",app_name);
      if(err_msg)
        sprintf(err_msg+strlen(err_msg),"\nApplication run_as_user for %s is invalid. Application not started.",app_name);
      //wr_conf_app_free(app); return NULL;
      free_app_obj = 1;
    }
  } else {
    LOG_ERROR(SEVERE,"Application run_as_user for %s is missing. Application not started.",app_name);
    printf("Application run_as_user for %s is missing. Application not started.\n",app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication run_as_user for %s is missing. Application not started.",app_name);
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  if(app->baseuri.str == NULL && app->host_name_list == NULL) {
    LOG_ERROR(SEVERE,"Please specify host_name or baseuri for the application %s.",app_name);
    printf("Please specify host_name or baseuri for the application %s.\n",app_name);              
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nPlease specify host_name or baseuri for the application %s.",app_name);
    free_app_obj = 1;
  }

  if(app->baseuri.str && app->host_name_list) {
    LOG_ERROR(SEVERE,"Please specify either host_name or baseuri(not both) for the application %s.",app_name);
    printf("Please specify either host_name or baseuri(not both) for the application %s.\n",app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nPlease specify either host_name or baseuri(not both) for the application %s.",app_name);
    free_app_obj = 1;
  }

  // Set application environment
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_ENV));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    wr_string_new(app->env, str, len);
    LOG_DEBUG(DEBUG, "Application environment = %s", app->env.str);
  } else {
    len = strlen(WR_DEFAULT_ENV);
    wr_string_new(app->env, WR_DEFAULT_ENV, len);
  }

  // Set min_worker
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_MIN_WKR));
  if(str && strlen(str) > 0) {
    app->min_worker = atoi(str);
    if(app->min_worker > WR_ALLOWED_MAX_WORKERS) {
      LOG_ERROR(SEVERE, "Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.", app_name, WR_ALLOWED_MAX_WORKERS);
      printf("Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.\n", app_name, WR_ALLOWED_MAX_WORKERS);
      if(err_msg)
        sprintf(err_msg + strlen(err_msg), "Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.", app_name, WR_ALLOWED_MAX_WORKERS);
      free_app_obj = 1; 
    }
  }

  // Set max_worker
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_MAX_WKR));
  if(str && strlen(str) > 0) {
    app->max_worker = atoi(str);
    if(app->max_worker > WR_ALLOWED_MAX_WORKERS) {
      LOG_ERROR(SEVERE, "Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.", app_name, WR_ALLOWED_MAX_WORKERS);
      printf("Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.\n", app_name, WR_ALLOWED_MAX_WORKERS);
      if(err_msg)
        sprintf(err_msg + strlen(err_msg), "Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.", app_name, WR_ALLOWED_MAX_WORKERS);
      free_app_obj = 1; 
    }
  }

  if(free_app_obj & 1) {
    wr_conf_app_free(app);
    return NULL;
  }
  
  // Check min_worker should be less than or equal to max_worker
  if(app->min_worker > app->max_worker) {
    LOG_ERROR(SEVERE,"Application(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.",app_name, app->min_worker, app->max_worker);
    printf("Application(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.\n",app_name, app->min_worker, app->max_worker);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.",app_name, app->min_worker, app->max_worker);
    wr_conf_app_free(app);
    return NULL;
  }

  // Set logging level
  str = wr_validate_string(get_node_value(app_node->child, WR_CONF_APP_LOG_LEVEL));
  if(str && strlen(str) > 0)
    app->log_level = get_log_severity(str);
  return app;
}

/** Iterate application nodes and construct application configuration structure */
static inline int wr_iterate_app_node(wr_conf_t *conf, node_t *root) {
  wr_app_conf_t *app, *prev_app;
  node_t* app_nodes;

  LOG_DEBUG(DEBUG,"iterate_application_node()");
  //Fetch Application Specification nodes
  app_nodes = get_nodes(root, WR_CONF_APP_SPEC);

  // Iterate application nodes
  while(app_nodes) {
    if(app_nodes->child) {
      // Create & fill application configuration structure
      app = wr_app_conf_set(conf,  app_nodes, NULL);

      if(app) {
        //return -1;
        // Set application configuration to configuration structure
        if(conf->apps) {
          prev_app->next = app;
        } else {
          conf->apps = app;
        }
        prev_app = app;
      }
    }
    app_nodes = NODE_NEXT(app_nodes);
  }
  return 0;
}

/** Validate application baseuri for duplication. Also removes every such application object. */
static inline int wr_remove_app_with_dup_baseuri(wr_conf_t *conf) {
  LOG_FUNCTION
  wr_app_conf_t *app=conf->apps, *next,*tmp_app;
  int rv = 0;

  if(app == NULL) {
    LOG_INFO("No applications currently deployed on the server.");
    return -1;
  }

  // Iterate application nodes to compare with admin-panel baseuri
  // It's possible, an app without baseuri, if host_name present to identify the application.
  while(app) {
    next = app->next;
    if(app->baseuri.str) {
      LOG_DEBUG(DEBUG, "Comparing baseuit %s ",app->baseuri.str)  ;
      // Compare each application baseuri with admin-panel baseuri
      if(strcmp(app->baseuri.str, WR_ADMIN_PANEL_BASE_URL)==0) {
        LOG_ERROR(SEVERE,"'%s' base-uri is reserved for 'Admin Panel'. Application %s not started", WR_ADMIN_PANEL_BASE_URL,app->name.str);
        printf("'%s' base-uri is reserved for 'Admin Panel'. Application %s not started\n", WR_ADMIN_PANEL_BASE_URL,app->name.str);
        rv = -1;
        wr_app_conf_remove(conf, app->name.str);
      } else {
        tmp_app = next;
        while(tmp_app) {
          if(tmp_app->baseuri.str && strcmp(app->baseuri.str, tmp_app->baseuri.str)==0) {
            LOG_ERROR(SEVERE,"Base-uri '%s' is repeated for more than one application.", app->baseuri.str);
            printf("Base-uri '%s' is repeated for more than one application.\n",app->baseuri.str);
            rv = -1;
            wr_app_conf_remove(conf, tmp_app->name.str);
            tmp_app = next = app->next;
          } else {
            tmp_app = tmp_app->next;
          }
        }
      }
    }
    app = next;
  }

  return rv;
}

static inline int wr_chk_host_within_list(wr_host_name_t *list) {
  LOG_FUNCTION

  wr_host_name_t *tmp=NULL;

  while(list) {
    tmp = list->next;
    while(tmp) {
      if(list->name.len == tmp->name.len && strncmp(list->name.str, tmp->name.str, tmp->name.len) == 0) {
        return -1;
      }
      tmp = tmp->next;
    }
    list = list->next;
  }
  return 0;
}

static inline int wr_chk_host_lists(wr_host_name_t *list1, wr_host_name_t *list2) {
  LOG_FUNCTION

  while(list1) {
    while(list2) {
      if(list1->name.len == list2->name.len && strncmp(list1->name.str, list2->name.str, list1->name.len)==0) {
        return -1;
      }
      list2 = list2->next;
    }
    list1 = list1->next;
  }
  return 0;
}

/** Removes Application object on repeated host_name. */
static inline int wr_remove_app_with_dup_host(wr_conf_t *conf) {
  LOG_FUNCTION
  wr_app_conf_t *app=conf->apps, *tmp_app = NULL;
  short rv = 0;

  if(app == NULL) {
    LOG_INFO("No applications currently deployed on the server.");
    printf("No applications currently deployed on the server.\n");
    return 0;
  }
  // It's possible, an app without host_name_list, if baseuri present to identify the application.

  while(app) {
    tmp_app = app->next;
    if(app->host_name_list) {
      if(wr_chk_host_within_list(app->host_name_list)!=0) {
        LOG_ERROR(WARN,"Host names are repeated in Application '%s'. Application would not start.", app->name.str);
        printf("Host names are repeated in Application '%s'. Application would not start.\n", app->name.str);
        wr_app_conf_remove(conf, app->name.str);
        app = tmp_app;
        rv = -1;
        continue;
      }

      while(tmp_app) {
        if(tmp_app->host_name_list) {
          if(wr_chk_host_lists(app->host_name_list, tmp_app->host_name_list) !=0) {
            LOG_ERROR(WARN,"Host names are repeated in '%s' and '%s'. Applications would not start.", app->name.str, tmp_app->name.str);
            printf("Host names are repeated in '%s' and '%s'. Applications would not start.\n", app->name.str, tmp_app->name.str);
            wr_app_conf_remove(conf, app->name.str);
            wr_app_conf_remove(conf, tmp_app->name.str);
            rv = -1;
            break;
          }
        }
        tmp_app = tmp_app->next;
      }
      if(tmp_app) {
        app = conf->apps;
        continue;
      }
    }
    app = app->next;
  }
  return rv;
}

/** Read Admin Panel */
static inline wr_app_conf_t* wr_conf_admin_panel_read(wr_conf_t* conf) {
  LOG_FUNCTION
  struct passwd *user_info=NULL;
  size_t len;

  user_info = getpwnam("root");
  // Check for user privilege
  if(user_info) {
    if(geteuid() == user_info->pw_uid && getegid() == user_info->pw_gid) {
      wr_app_conf_t* app = wr_app_conf_new(conf->server);

      if(app ==NULL) {
        return NULL;
      }

      // Set Admin base uri to 'admin-panel'
      len = strlen(WR_ADMIN_PANEL_BASE_URL);
      wr_string_new(app->baseuri,WR_ADMIN_PANEL_BASE_URL,len);

      //Set user & group id
      app->cgid = user_info->pw_gid;
      app->cuid = user_info->pw_uid;

      // Set application environment to production
      len = strlen("production");
      wr_string_new(app->env,"production",len);

      //Set max_worker & min_processsor to 1
      app->max_worker = 1;
      app->min_worker = 1;

      // Set application name
      len = strlen(WR_ADMIN_PANEL_APP_NAME);
      wr_string_new(app->name,WR_ADMIN_PANEL_APP_NAME,len);

      // Set Admin Panel path
      wr_string_dump(app->path,conf->admin_panel_path);

      // Set application type to rails
      len = strlen("rails");
      wr_string_new(app->type,"rails",len);
      return app;
    }
  }
  return NULL;
}

/** Create application configuration for static content server */
static inline wr_app_conf_t* wr_conf_static_server_read(wr_conf_t* conf) {
  LOG_FUNCTION
  struct passwd *user_info=NULL;
  size_t len;

  user_info = getpwnam("root");
  // Check for user privilege
  if(user_info) {
    if(geteuid() == user_info->pw_uid && getegid() == user_info->pw_gid) {
      wr_app_conf_t* app = wr_app_conf_new(conf->server);

      if(app == NULL) {
        return NULL;
      }

      // Set application name
      len = strlen(WR_STATIC_FILE_SERVER_NAME);
      wr_string_new(app->name,WR_STATIC_FILE_SERVER_NAME,len);
      
      //Set user & group id
      app->cgid = user_info->pw_gid;
      app->cuid = user_info->pw_uid;

      // Set all other parameter to app name
      wr_string_dump(app->env,app->name);
      wr_string_dump(app->baseuri,app->name);
      wr_string_dump(app->path,app->name);
      wr_string_dump(app->type,app->name);      

      //Set max_worker & min_processsor
      app->max_worker = WR_STATIC_SVR_MAX_WKR;
      app->min_worker = WR_STATIC_SVR_MIN_WKR;
      
      return app;
    }
  }
  return NULL;
}
/***********************************************************
 *     Configurator API definitions
 ************************************************************/

/** Remove specified application from configuraion */
int wr_app_conf_remove(wr_conf_t* conf, const char *app_name) {
  LOG_FUNCTION
  wr_app_conf_t* app = conf->apps, *tmp_app = NULL;

  LOG_DEBUG(DEBUG, "Removing application %s", app_name);
  // Iterate application nodes
  while(app) {
    if(strcmp(app_name, app->name.str) == 0) //Compare application name
      break;
    tmp_app = app;
    app = app->next;
  }
  if(app) {
    // Set application configuraion links
    if(tmp_app) {
      tmp_app->next = app->next;
    } else {
      conf->apps = app->next;
    }
    app->next = NULL;
    //Destroy application configuration
    LOG_DEBUG(DEBUG, "Removed application %s", app->name.str);
    wr_conf_app_free(app);
    return 0;
  } else
    return -1;
}

/** Replace the application configuration */
int wr_conf_app_replace(wr_conf_t *conf, wr_app_conf_t *app_conf){
  LOG_FUNCTION
  wr_app_conf_t *app = conf->apps, *tmp_app = NULL;

  while(app) {
    if(strcmp(app_conf->name.str, app->name.str)==0)
      break;
    tmp_app = app;
    app = app->next;
  }

  if(app){
    app_conf->next = app->next;
    if(tmp_app){
      tmp_app->next = app_conf;
    }else{
      conf->apps = app_conf;
    }
    app->next = NULL;
    wr_conf_app_free(app);
  }else{
    LOG_ERROR(WARN, "Appliation '%s' is not found", app_conf->name.str);
    app_conf->next = conf->apps;
    conf->apps = app_conf;
  }
  return 0;
}

/** Remove the existing application specification if exists.
 *  And add the new application configuration. */
wr_app_conf_t* wr_conf_app_update(wr_conf_t* conf, const char *app_name, char* err_msg) {
  LOG_FUNCTION
  wr_app_conf_t *app = conf->apps, *tmp_app = NULL;

  while(app) {
    if(strcmp(app_name, app->name.str)==0)
      break;
    tmp_app = app;
    app = app->next;
  }

  if(app){
    if(tmp_app){
      tmp_app->next = app->next;
    }else{
      conf->apps = app->next;
    }
    app->next = NULL;
    //wr_conf_app_free(app);
  }else{
    if(err_msg)
      sprintf(err_msg, "Appliation '%s' is not found", app_name);
  }

  return wr_conf_app_read(conf, app_name, err_msg);
}

/** Read specified application and construct application configuration */
wr_app_conf_t* wr_conf_app_read(wr_conf_t* conf, const char *app_name, char* err_msg) {
  LOG_FUNCTION
  //Parse configuration file
  node_t *root , *app_nodes = NULL;
  wr_app_conf_t *app = NULL, *tmp;
  char *str;

  app = conf->apps;

  while(app) {
    if(strcmp(app->name.str, app_name) == 0) {
      if(err_msg)
        sprintf(err_msg, "Appliation '%s' is already exists", app_name);
      return NULL;
    }
    app = app->next;
  }

  app = NULL;

  if(strcmp(app_name, WR_ADMIN_PANEL_APP_NAME) == 0) {
    app = wr_conf_admin_panel_read(conf);

    if(app) {
      //Set application configuration into configuration data structure
      app->next = conf->apps;
      conf->apps = app;
    } else {
      if(err_msg)
        strcpy(err_msg, "Could not read Admin Panel");
    }
    return app;
  }

  root = yaml_parse(conf->config_file_path.str);

  if(!root) {
    LOG_ERROR(SEVERE, "Config file found with erroneous entries. Please correct it.");
    strcpy(err_msg, "Config file found with erroneous entries. Please correct it.");
    return NULL;
  }

  //  if(validate_application_baseuri_for_uniqueness(root, err_msg)!=0){
  //    node_free(root);
  //    return NULL;
  //  }
  //Fetch Application Specification nodes
  app_nodes = get_nodes(root, WR_CONF_APP_SPEC);

  // Iterate application nodes
  while(app_nodes) {
    if(app_nodes->child) {
      str = wr_validate_string(get_node_value(app_nodes->child, WR_CONF_APP_NAME));
      // Compare application name
      if(str && strcmp(str, app_name)==0) {
        app = wr_app_conf_set(conf, app_nodes, err_msg);
        break;
      }
    }
    app_nodes = NODE_NEXT(app_nodes);
  }

  node_free(root);

  if(app) {
    // checking uniqueness for host name. While setting application object, we are parsing raw string of host_names
    // into host_name_list. We can easily check for uniqueness once host_name_list is ready.
    if(app->host_name_list){
      if(wr_chk_host_within_list(app->host_name_list)!=0) {
        LOG_ERROR(WARN,"Checking hosts within list is failed.");
        wr_conf_app_free(app);
        return NULL;
      }

      tmp = conf->apps;
      while(tmp) {
        if(tmp->host_name_list) {
          if(wr_chk_host_lists(app->host_name_list, tmp->host_name_list)!=0) {
            LOG_ERROR(WARN,"Checking host lists is failed.");
            wr_conf_app_free(app);
            return NULL;
          }
        }
        tmp = tmp->next;
      }
    }
    //Set application configuration into configuration data structure
    app->next = conf->apps;
    conf->apps = app;
  }
  return app;
}

/** Destroy configuration object */
void wr_conf_free(wr_conf_t* conf) {
  LOG_FUNCTION
  //Destroy server_configuration
  if(conf->server) {
    wr_string_free(conf->server->sock_path);
#ifdef HAVE_GNUTLS

    wr_string_free(conf->server->certificate);
    wr_string_free(conf->server->key);
#endif

    free(conf->server);
  }
  //Destroy application_configuration list
  wr_conf_app_free(conf->apps);

  // Destroy configuration structure
  wr_string_free(conf->wr_root_path);
  wr_string_free(conf->ruby_lib_path);
  wr_string_free(conf->wkr_exe_path);
  wr_string_free(conf->admin_panel_path);
  wr_string_free(conf->config_file_path);
  free(conf);
}

/** Read configuration file and fill configuration object */
wr_conf_t* wr_conf_read(const char* root_path) {
  LOG_FUNCTION
  node_t *root;
  wr_conf_t* conf = NULL;

  //Create configuration structure
  conf =  wr_conf_new();
  if(conf == NULL) {
    LOG_ERROR(SEVERE,"Configuration object could not be allocated.");
    printf("Configuration object could not be allocated.\n");
    return NULL;
  }

  // Initialize various paths based on webroar_root path
  wr_init_path(conf, root_path);

  // Get parsed nodes
  LOG_DEBUG(4,"YAML file path %s", conf->config_file_path.str);
  root = yaml_parse(conf->config_file_path.str);

  if(!root) {
    LOG_ERROR(SEVERE, "Config file found with erroneous entries. Please correct it.");
    printf("Config file found with erroneous entries. Please correct it.\n");
    wr_conf_free(conf);
    return NULL;
  }

  // Set server_configuration parameters
  // Set server_configuration parameters
  if(wr_conf_server_set(conf, root)!=0)
    goto conf_err;

  // Set application_configuration list
  wr_iterate_app_node(conf, root);

  wr_remove_app_with_dup_baseuri(conf);

  wr_remove_app_with_dup_host(conf);

  //configuration_print(configuration);
  node_free(root);

  return conf;

conf_err:
  wr_conf_free(conf);
  return NULL;

}

/** Display configuration object */
void wr_conf_display(wr_conf_t* conf) {
  LOG_FUNCTION
  wr_app_conf_t *app = conf->apps;

  //printf("No of Applications : %d\n", conf->no_of_application);

  // Display Server specification
  if(conf->server) {
    printf("Server log level : %d\n", conf->server->log_level);
    printf("Server port : %d\n", conf->server->port);
    printf("Server min worker : %d\n", conf->server->min_worker);
    printf("Server max worker : %d\n", conf->server->max_worker);
    printf("Access log flag : %d\n", conf->server->flag&WR_SVR_ACCESS_LOG);
#ifdef HAVE_GNUTLS

    printf("Server SSL certificate : %s\n", conf->server->certificate.str);
    printf("Server SSL key : %s\n", conf->server->key.str);
    printf("Server SSL port : %d\n", conf->server->ssl_port);
#endif

  }

  // Display application specification
  while(app) {
    printf("Application log level : %d\n", app->log_level);
    printf("Environment  : %s\n", app->env.str);
    printf("Application min worker : %d\n", app->max_worker);
    printf("Application max worker : %d\n", app->min_worker);
    printf("Application name : %s\n", app->name.str);
    printf("Application path : %s\n", app->path.str);
    printf("Application type : %s\n", app->type.str);
    printf("Application analytics : %d\n", app->analytics);
    printf("Application baseuri : %s\n", app->baseuri.str);
    if(app->host_name_list) {
      wr_host_name_t* host=app->host_name_list;
      printf("Host Name List :- \n");
      while(host) {
        printf("%s, ", host->name.str);
        host = host->next;
      }
      printf("\n");
    }
    app = app->next;
  }
}

/** Add Admin Panel configuration */
int wr_conf_admin_panel_add(wr_conf_t* conf) {
  LOG_FUNCTION
  wr_app_conf_t* app = wr_conf_admin_panel_read(conf);

  if(app != NULL) {
    app->next = conf->apps;
    conf->apps = app;
    return 0;
  } else {
    printf("'Admin Panel' could not be started. To start 'Admin Panel' run server with root privileges.\n");
  }

  return -1;
}

/** Add the configuration for static content server */
int wr_conf_static_server_add(wr_conf_t* conf) {
  LOG_FUNCTION
  wr_app_conf_t* app = wr_conf_static_server_read(conf);

  if(app != NULL) {
    app->next = conf->apps;
    conf->apps = app;
    return 0;
  }

  return -1;
}
