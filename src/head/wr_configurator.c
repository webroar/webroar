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

#include <wr_request.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <pwd.h>

extern config_t *Config;

#define WR_CONF_MAX_LEN_APP_NAME  30
#define WR_CONF_MAX_LEN_USR_NAME  30

/*********************************************************
 *     Private function definitions
 **********************************************************/

/** Create new application configuration with default values inherited from server configuration */
config_application_list_t* wr_config_application_new(){
  LOG_FUNCTION
  config_application_list_t* app = wr_malloc(config_application_list_t);
  app->log_level = Config->Server.log_level;
  app->min_worker = Config->Application.Default.min_workers;
  app->max_worker = Config->Application.Default.max_workers;
  wr_string_null(app->name);
  wr_string_null(app->baseuri);
  wr_string_null(app->path);
  app->scgi = NULL;
  app->host_name_list = NULL;
  app->new = NULL;
  app->next = NULL;
  return app;
}

/** Set SCGI Config request */
int wr_app_conf_req_set(config_application_list_t *app, node_t *app_node){
  LOG_FUNCTION
  char *str;
  
  app->scgi = scgi_new();

  if(!app->scgi) {
    return FALSE;
  }
  
  scgi_header_add(app->scgi, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
  scgi_header_add(app->scgi, "METHOD", strlen("METHOD"), "CONF_REQ", strlen("CONF_REQ"));
  scgi_header_add(app->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));   
  scgi_header_add(app->scgi, "NAME", strlen("NAME"), app->name.str, app->name.len);
  scgi_header_add(app->scgi, "PATH", strlen("PATH"), app->path.str, app->path.len);
  if(!wr_string_is_empty(app->baseuri))
    scgi_header_add(app->scgi, "BASE_URI", strlen("BASE_URI"), app->baseuri.str, app->baseuri.len);
 
  str = wr_validate_string(get_node_value(app_node->child, "type"));
  scgi_header_add(app->scgi, "TYPE", strlen("TYPE"), str, strlen(str));
    
  str = wr_validate_string(get_node_value(app_node->child, "analytics"));
  scgi_header_add(app->scgi, "ANALYTICS", strlen("ANALYTICS"), str, strlen(str));
  
  str = wr_validate_string(get_node_value(app_node->child, "run_as_user"));
  scgi_header_add(app->scgi, "USER", strlen("USER"), str, strlen(str));

  // Set application environment
  str = wr_validate_string(get_node_value(app_node->child, "environment"));
  if(str){
    scgi_header_add(app->scgi, "ENV", strlen("ENV"), str, strlen(str));
  }else{
    scgi_header_add(app->scgi, "ENV", strlen("ENV"), Config->Application.Default.env.str, Config->Application.Default.env.len);
  }
  
  node_t *nodes = get_nodes(app_node->child, "environment_variables/set_env");
  wr_str_t val;
  wr_string_null(val);
  while(nodes){
    str = wr_validate_string(NODE_VALUE(nodes));
    if(str){      
      if(wr_string_is_empty(val)){
        wr_string_new(val, str, strlen(str));
      }else{
        wr_string_append(val, "#", 1);
        wr_string_append(val, str, strlen(str));
      }
    }
    nodes = NODE_NEXT(nodes);
  }
  if(!wr_string_is_empty(val)){
   scgi_header_add(app->scgi, "ENV_VAR", strlen("ENV_VAR"), val.str, val.len); 
  }
  wr_string_free(val);
  scgi_build(app->scgi);
  
  return TRUE;
}

/** Set Server Configuration */
int wr_config_server_set(node_t *root) {
  LOG_FUNCTION
  char *str;

  // Set server listening port
  str = wr_validate_string(get_node_value(root, "Server Specification/port"));
  if(str)
    Config->Server.port = atoi(str);

  if(Config->Server.port < 0 || Config->Server.port > 65536) {
    LOG_ERROR(SEVERE,"Valid port should be a number between 1 and 65536. Server can not start.");
    printf("Valid port should be a number between 1 and 65536. Server can not start.\n");
    return -1;
  }

  // Set min_worker
  str = wr_validate_string(get_node_value(root, "Server Specification/min_worker"));
  if(str) {
    Config->Application.Default.min_workers = atoi(str);
    if(Config->Application.Default.min_workers > Config->Server.Worker.max) {
      LOG_ERROR(SEVERE, "Server Specification: Minimum workers should be a number between 1 and %d. Server can not start.", Config->Server.Worker.max);
      printf("Server Specification: Minimum workers should be a number between 1 and %d. Server can not start.\n", Config->Server.Worker.max);
      return -1; 
    }
  }
  
  // Set max_worker
  str = wr_validate_string(get_node_value(root, "Server Specification/max_worker"));
  if(str) {
    Config->Application.Default.max_workers = atoi(str);
    if(Config->Application.Default.max_workers > Config->Server.Worker.max) {
      LOG_ERROR(SEVERE, "Server Specification: Maximum workers should be a number between 1 and %d. Server can not start.", Config->Server.Worker.max);
      printf("Server Specification: Maximum workers should be a number between 1 and %d. Server can not start.\n", Config->Server.Worker.max);
      return -1; 
    }
  }
  
  if(Config->Application.Default.min_workers > Config->Application.Default.max_workers) {
    LOG_ERROR(SEVERE,"Server Specification: Min worker value is greater than Max worker value. Server can not start.");
    printf("Server Specification: Min worker value is greater than Max worker value. Server can not start.\n");
    return -1;
  }

  // Set logging level
  str = wr_validate_string(get_node_value(root, "Server Specification/log_level"));
  if(str)
    Config->Server.log_level = get_log_severity(str); 
    
  // Set access log flag
  str = wr_validate_string(get_node_value(root, "Server Specification/access_log"));

  if(str && strcmp(str,"enabled")==0 ) {
    Config->Server.flag |= SERVER_ACCESS_LOG;
  }

  //check ssl support
  str = wr_validate_string(get_node_value(root, "Server Specification/SSL Specification/ssl_support"));
  if(str && strcmp(str,"enabled")==0 ) {
    Config->Server.flag |= SERVER_SSL_SUPPORT;
  }

#ifdef HAVE_GNUTLS

  if(Config->Server.flag & SERVER_SSL_SUPPORT) {
  	size_t len;
    struct stat buff;
    // Set certificate path
    str = wr_validate_string(get_node_value(root, "Server Specification/SSL Specification/certificate_file"));
    if(str) {
      if(stat(str,&buff)!=0) {
        LOG_ERROR(SEVERE,"SSL certificate file path(%s) invalid. Server can not run on SSL.",str);
        printf("SSL certificate file path(%s) invalid. Server can not run on SSL.\n",str);
        Config->Server.flag &= (!SERVER_SSL_SUPPORT)
      } else {
        len = strlen(str);
        wr_string_new(Config->Server.SSL.certificate, str, len);
      }
    } else {
      LOG_ERROR(SEVERE,"Certificate file path is missing. Server can not run on SSL.");
      printf("Certificate file path is missing. Server can not run on SSL.\n");
      Config->Server.flag &= (!SERVER_SSL_SUPPORT)
    }

    // Set certificate path
    str = wr_validate_string(get_node_value(root, "Server Specification/SSL Specification/key_file"));
    if(str) {
      if(stat(str,&buff)!=0) {
        LOG_ERROR(SEVERE,"SSL key file path(%s) invalid. Server can not run on SSL.",str);
        printf("SSL key file path(%s) invalid. Server can not run on SSL.\n",str);
        Config->Server.flag &= (!SERVER_SSL_SUPPORT)
      } else {
        len = strlen(str);
        wr_string_new(Config->Server.SSL.key, str, len);
      }
    } else {
      LOG_ERROR(SEVERE,"SSL key file path is missing. Server can not run on SSL.");
      printf("SSL key file path is missing. Server can not run on SSL.\n");
      Config->Server.flag &= (!SERVER_SSL_SUPPORT)
    }

    // Set server listening port
    str = wr_validate_string(get_node_value(root, "Server Specification/SSL Specification/ssl_port"));
    if(str) {
      Config->Server.SSL.port = atoi(str);
      if(Config->Server.SSL.port < 0 || Config->Server.SSL.port > 65536) {
        LOG_ERROR(SEVERE,"Given SSL port is invalid. Valid port should be a number between 1 and 65536. Server can not run on SSL.");
        printf("Given SSL port is invalid. Valid port should be a number between 1 and 65536. Server can not run on SSL.\n");               
        Config->Server.flag &= (!SERVER_SSL_SUPPORT)
      }
    }
  }

#endif

  return 0;
}

int wr_validate_app_host_name(const char *host_name, char *err_msg) {
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
  strcpy(tmp_host, host_name);
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

int wr_app_host_name_set(config_application_list_t *app, char *host_names, char *err_msg) {
  LOG_FUNCTION
  char *host = NULL, *host_array[Config->Application.max_hosts];
  config_host_list_t *hosts = NULL, *tmp_host = NULL;
  int rv, counter = 0, no_of_hosts = 0;
  size_t len;

  if(!app || !host_names) {
    return -1;
  }

  /* Tokenizing all the hostnames here, as in wr_validate_app_host_name() individual hostname is again tokenizing for further validations.
   * Call to second strtok for tokenizing of new string, before completion of its first call, messing up with the original string of first call. */
  host = strtok(host_names, " ");
  while(host && counter < Config->Application.max_hosts) {
    host_array[counter++] = host;    
    host = strtok(NULL, " ");
  }
  no_of_hosts = counter;
  counter = 0;
  
  while(counter < no_of_hosts) {
    host = host_array[counter++];
    if(host[0]=='~') {
      rv = wr_validate_app_host_name(host+1, err_msg);
    } else {
      rv = wr_validate_app_host_name(host, err_msg);
    }

    if(rv != 0)
      return -1;

    len = strlen(host);
    tmp_host = wr_malloc(config_host_list_t);
    if(tmp_host == NULL)
      return -1;

    tmp_host->next = NULL;
    tmp_host->type = HOST_TPE_INVALID;
    //storing plain name, removing any '*', and '~'
    if(host[1] == '*') {
      if(host[len-1] == '*') {
        tmp_host->type = HOST_TYPE_WILDCARD_IN_START_END;
        wr_string_new(tmp_host->name, host+2, len-3);
      } else {
        tmp_host->type = HOST_TYPE_WILDCARD_IN_START;
        wr_string_new(tmp_host->name, host+2, len-2);
      }
      LOG_DEBUG(DEBUG, "Host name = %s", tmp_host->name.str);
    } else if(host[len-1] == '*') {
      tmp_host->type = HOST_TYPE_WILDCARD_IN_END;
      wr_string_new(tmp_host->name, host+1, len-2);
      LOG_DEBUG(DEBUG, "Host name = %s", tmp_host->name.str);
    } else {
      tmp_host->type = HOST_TYPE_STATIC;
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
      hosts = hosts->next;
    }    
  }
  return 0;
}

/** Create and fill application configuration */
config_application_list_t* wr_config_application_set(node_t* app_node, char* err_msg) {
  LOG_FUNCTION
  config_application_list_t *app = NULL;
  struct stat buff;
  char *str, *app_name;
  short free_app_obj = 0;
  size_t len;

  // Create application configuration with default values
  app = wr_config_application_new();

  if(!app) {
    return NULL;
  }
  
  //Set application name
  str = wr_validate_string(get_node_value(app_node->child, "name"));
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
    wr_application_list_free(app);
    return NULL;
  } else {
    LOG_ERROR(SEVERE,"Application name is missing");
    printf("Application name is missing.\n");
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication name is missing.");
    wr_application_list_free(app);
    return NULL;
  }

  // Set application path
  str = wr_validate_string(get_node_value(app_node->child, "path"));
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
    LOG_DEBUG(DEBUG, "Application Path = %s", str);
  } else {
    LOG_ERROR(SEVERE,"Application path for %s is missing. Application not started.", app_name);
    printf("Application path for %s is missing. Application not started\n", app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication path for %s is missing. Application not started", app_name);
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application type
  str = wr_validate_string(get_node_value(app_node->child, "type"));
  if(str && strlen(str) > 0) {
    LOG_DEBUG(DEBUG, "Application Type = %s", str);
  } else {
    LOG_ERROR(SEVERE,"Application type for %s is missing", app_name);
    printf("Application type for %s is missing\n", app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"Application type is missing.");
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application analytics
  str = wr_validate_string(get_node_value(app_node->child, "analytics"));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    LOG_DEBUG(DEBUG,"App analytics = %s", str);
  } else {
    LOG_ERROR(SEVERE,"Application analytics for %s is missing. Application not started.",app_name);
    printf("Application analytics for %s is missing. Application not started.\n",app_name);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication analytics for %s is missing. Application not started.",app_name);
    //wr_conf_app_free(app); return NULL;
    free_app_obj = 1;
  }

  // Set application base uri
  str = wr_validate_string(get_node_value(app_node->child, "baseuri"));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    wr_string_new(app->baseuri, str, len);
    LOG_DEBUG(DEBUG, "Application Baseuri = %s", app->baseuri.str);
  }

  // Set Host names (used for multiple host deployment and application identifiaction)
  str = wr_validate_string(get_node_value(app_node->child, "host_names"));
  if(str && strlen(str) > 0) {
    wr_app_host_name_set(app, str, err_msg);
  }

  // Set application user & group id
  str = wr_validate_string(get_node_value(app_node->child, "run_as_user"));
  if(str && strlen(str) > 0) {
    len = strlen(str);
    struct passwd *user_info=NULL;
    user_info = getpwnam(str);
    // Check for user existence
    if(!user_info) {
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
  str = wr_validate_string(get_node_value(app_node->child, "environment"));
  if(str && strlen(str) > 0) {
    LOG_DEBUG(DEBUG, "Application environment = %s", str);
  }

  // Set min_worker
  str = wr_validate_string(get_node_value(app_node->child, "min_worker"));
  if(str && strlen(str) > 0) {
    app->min_worker = atoi(str);
    if(app->min_worker > Config->Server.Worker.max) {
      LOG_ERROR(SEVERE, "Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.", app_name, Config->Server.Worker.max);
      printf("Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.\n", app_name, Config->Server.Worker.max);
      if(err_msg)
        sprintf(err_msg + strlen(err_msg), "Application(%s)-Minimum workers should be a number between 1 and %d. Application not started.", app_name, Config->Server.Worker.max);
      free_app_obj = 1; 
    }
  }

  // Set max_worker
  str = wr_validate_string(get_node_value(app_node->child, "max_worker"));
  if(str && strlen(str) > 0) {
    app->max_worker = atoi(str);
    if(app->max_worker > Config->Server.Worker.max) {
      LOG_ERROR(SEVERE, "Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.", app_name, Config->Server.Worker.max);
      printf("Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.\n", app_name, Config->Server.Worker.max);
      if(err_msg)
        sprintf(err_msg + strlen(err_msg), "Application(%s)-Maximum workers should be a number between 1 and %d. Application not started.", app_name, Config->Server.Worker.max);
      free_app_obj = 1; 
    }
  }

  if(free_app_obj & 1) {
    wr_application_list_free(app);
    return NULL;
  }
  
  // Check min_worker should be less than or equal to max_worker
  if(app->min_worker > app->max_worker) {
    LOG_ERROR(SEVERE,"Application(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.",app_name, app->min_worker, app->max_worker);
    printf("Application(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.\n",app_name, app->min_worker, app->max_worker);
    if(err_msg)
      sprintf(err_msg+strlen(err_msg),"\nApplication(%s) no. of min workers(%d) should not be greater than no. of max workers(%d). Application not started.",app_name, app->min_worker, app->max_worker);
    wr_application_list_free(app);
    return NULL;
  }

  // Set logging level
  str = wr_validate_string(get_node_value(app_node->child, "log_level"));
  if(str && strlen(str) > 0){
    app->log_level = get_log_severity(str);
  }
  
  if(wr_app_conf_req_set(app, app_node) == FALSE){
    wr_application_list_free(app);
    return NULL;
  }

  return app;
}

/** Iterate application nodes and construct application configuration structure */
int wr_iterate_app_node(node_t *root) {
  LOG_FUNCTION
  config_application_list_t *app, *prev_app;
  node_t* app_nodes;

  LOG_DEBUG(DEBUG,"iterate_application_node()");
  //Fetch Application Specification nodes
  app_nodes = get_nodes(root, "Application Specification");

  // Iterate application nodes
  while(app_nodes) {
    if(app_nodes->child) {
      // Create & fill application configuration structure
      app = wr_config_application_set(app_nodes, NULL);

      if(app) {
        //return -1;
        // Set application configuration to configuration structure
        if(Config->Application.list) {
          prev_app->next = app;
        } else {
          Config->Application.list = app;
        }
        prev_app = app;
      }
    }
    app_nodes = NODE_NEXT(app_nodes);
  }
  return 0;
}

/** Validate application baseuri for duplication. Also removes every such application object. */
int wr_remove_app_with_dup_baseuri() {
  LOG_FUNCTION
  config_application_list_t *app = Config->Application.list, *next,*tmp_app;
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
      if(strcmp(app->baseuri.str, Config->Application.Admin_panel.base_uri.str)==0) {
        LOG_ERROR(SEVERE,"'%s' base-uri is reserved for 'Admin Panel'. Application %s not started", Config->Application.Admin_panel.base_uri.str,app->name.str);
        printf("'%s' base-uri is reserved for 'Admin Panel'. Application %s not started\n", Config->Application.Admin_panel.base_uri.str,app->name.str);
        rv = -1;
        wr_app_conf_remove(app->name.str);
      } else {
        tmp_app = next;
        while(tmp_app) {
          if(tmp_app->baseuri.str && strcmp(app->baseuri.str, tmp_app->baseuri.str)==0) {
            LOG_ERROR(SEVERE,"Base-uri '%s' is repeated for more than one application.", app->baseuri.str);
            printf("Base-uri '%s' is repeated for more than one application.\n",app->baseuri.str);
            rv = -1;
            wr_app_conf_remove(tmp_app->name.str);
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

int wr_chk_host_within_list(config_host_list_t *list) {
  LOG_FUNCTION

  config_host_list_t *tmp=NULL;

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

int wr_chk_host_lists(config_host_list_t *list1, config_host_list_t *list2) {
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
int wr_remove_app_with_dup_host() {
  LOG_FUNCTION
  config_application_list_t *app = Config->Application.list, *tmp_app = NULL;
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
        wr_app_conf_remove(app->name.str);
        app = tmp_app;
        rv = -1;
        continue;
      }

      while(tmp_app) {
        if(tmp_app->host_name_list) {
          if(wr_chk_host_lists(app->host_name_list, tmp_app->host_name_list) !=0) {
            LOG_ERROR(WARN,"Host names are repeated in '%s' and '%s'. Applications would not start.", app->name.str, tmp_app->name.str);
            printf("Host names are repeated in '%s' and '%s'. Applications would not start.\n", app->name.str, tmp_app->name.str);
            wr_app_conf_remove(app->name.str);
            wr_app_conf_remove(tmp_app->name.str);
            rv = -1;
            break;
          }
        }
        tmp_app = tmp_app->next;
      }
      if(tmp_app) {
        app = Config->Application.list;
        continue;
      }
    }
    app = app->next;
  }
  return rv;
}

/** Read Admin Panel */
config_application_list_t* wr_conf_admin_panel_read() {
  LOG_FUNCTION
  struct passwd *user_info = getpwnam("root");;
  
  // Check for user privilege
  if(user_info) {
    if(geteuid() == user_info->pw_uid && getegid() == user_info->pw_gid) {
      config_application_list_t* app = wr_config_application_new();

      if(app ==NULL) {
        return NULL;
      }
      
      app->scgi = scgi_new();
      scgi_header_add(app->scgi, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
      scgi_header_add(app->scgi, "METHOD", strlen("METHOD"), "CONF_REQ", strlen("CONF_REQ"));
      scgi_header_add(app->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));   
      

      // Set Admin base uri to 'admin-panel'
      wr_string_dump(app->baseuri, Config->Application.Admin_panel.base_uri);
      scgi_header_add(app->scgi, "BASE_URI", strlen("BASE_URI"), app->baseuri.str, app->baseuri.len);
      
      scgi_header_add(app->scgi, "USER", strlen("USER"), "root", strlen("root"));
      
      // Set application environment to production
      scgi_header_add(app->scgi, "ENV", strlen("ENV"), "production",strlen("production"));

      //Set max_worker & min_processsor to 1
      app->max_worker = 1;
      app->min_worker = 1;

      // Set application name
      wr_string_dump(app->name, Config->Application.Admin_panel.name);
      scgi_header_add(app->scgi, "NAME", strlen("NAME"), app->name.str, app->name.len);
      
      // Set Admin Panel path
      wr_string_dump(app->path, Config->Server.Dir.admin_panel);
      scgi_header_add(app->scgi, "PATH", strlen("PATH"), Config->Server.Dir.admin_panel.str, Config->Server.Dir.admin_panel.len);

      // Set application type to rails
      scgi_header_add(app->scgi, "TYPE", strlen("TYPE"), "rails", strlen("rails"));
      
      scgi_header_add(app->scgi, "ANALYTICS", strlen("ANALYTICS"), "disabled", strlen("disabled"));
      scgi_build(app->scgi);
      return app;
    }
  }
  return NULL;
}

/** Create application configuration for static content server */
config_application_list_t* wr_conf_static_server_read() {
  LOG_FUNCTION
  struct passwd *user_info=NULL;

  user_info = getpwnam("root");
  // Check for user privilege
  if(user_info) {
    if(geteuid() == user_info->pw_uid && getegid() == user_info->pw_gid) {
      config_application_list_t* app = wr_config_application_new();

      if(app == NULL) {
        return NULL;
      }

      // Set application name
      wr_string_dump(app->name, Config->Application.Static_server.name);
      
      //Set user & group id

      // Set all other parameter to app name
      wr_string_dump(app->baseuri,app->name);
      wr_string_dump(app->path,app->name);

      //Set max_worker & min_processsor
      app->max_worker = Config->Application.Static_server.max_workers;
      app->min_worker = Config->Application.Static_server.min_workers;
      
      return app;
    }
  }
  return NULL;
}

/** Search application configuration form application list */
config_application_list_t* wr_conf_app_exist(const char *app_name, config_application_list_t **prev_app){
  config_application_list_t* app = Config->Application.list;
  
  if(prev_app){
    *prev_app = NULL;
    while(app){
      if(strcmp(app_name, app->name.str) == 0) //Compare application name
        return app;
      *prev_app = app;
      app = app->next;
    }
  }else{
    while(app){
      if(strcmp(app_name, app->name.str) == 0) //Compare application name
        return app;
      app = app->next;
    }
  }  
  return NULL;
}


/***********************************************************
 *     Configurator API definitions
 ************************************************************/

/** Remove specified application from configuraion */
int wr_app_conf_remove(const char *app_name) {
  LOG_FUNCTION
  LOG_DEBUG(DEBUG, "Removing application %s", app_name);
  config_application_list_t *app, *prev_app;
  
  app = wr_conf_app_exist(app_name, &prev_app);

  if(app) {
    // Set application configuraion links
    if(prev_app) {
      prev_app->next = app->next;
    } else {
      Config->Application.list = app->next;
    }
    app->next = NULL;
    //Destroy application configuration
    LOG_DEBUG(DEBUG, "Removed application %s", app->name.str);
    wr_application_list_free(app);
    return 0;
  } else
    return -1;
}

/** Remove the existing application specification if exists.
 *  And add the new application configuration. */
int wr_conf_app_update(config_application_list_t *app) {
  LOG_FUNCTION
  
  if(app == NULL)   return FALSE;
  
  wr_string_free(app->baseuri);
  app->baseuri = app->new->baseuri;
  
  wr_string_free(app->path);
  app->path = app->new->path;
  
  scgi_free(app->scgi);
  app->scgi = app->new->scgi;
  
  wr_host_list_free(app->host_name_list);
  app->host_name_list = app->new->host_name_list;
   
  app->min_worker = app->new->min_worker;
  app->max_worker = app->new->max_worker;
  app->log_level = app->new->log_level;  
  
  free(app->new);
  app->new = NULL;
  
  return TRUE;
}

/** Read specified application and construct application configuration */
// Flag to allow duplicate application
config_application_list_t* wr_conf_app_read(const char *app_name, char* err_msg, int flag) {
  LOG_FUNCTION
  //Parse configuration file
  node_t *root , *app_nodes = NULL;
  config_application_list_t *app = NULL, *old_app = NULL, *tmp;
  char *str;
  
  old_app = wr_conf_app_exist(app_name, NULL);
  
  if(flag == TRUE && old_app == NULL)   return NULL;
  if(flag == FALSE && old_app){
    if(err_msg)
        sprintf(err_msg, "Application '%s' is already exists", app_name);
    return NULL;
  }
    
  if(strcmp(app_name, Config->Application.Admin_panel.name.str) == 0) {
    app = wr_conf_admin_panel_read();

    if(app) {
      //Set application configuration into configuration data structure
      if(flag == TRUE){
        old_app->new = app;
        return old_app;
      }else{
        app->next = Config->Application.list;
        Config->Application.list = app;
      }
    } else {
      if(err_msg)
        strcpy(err_msg, "Could not read Admin Panel");
    }
    return app;
  }else if(strcmp(app_name, Config->Application.Static_server.name.str) == 0){
  	// Read Static server
  	app = wr_conf_static_server_read();
  	if(app) {
      //Set application configuration into configuration data structure
      if(flag == TRUE){
        old_app->new = app;
        return old_app;
      }else{
        app->next = Config->Application.list;
        Config->Application.list = app;
      }
    } else {
      if(err_msg)
        strcpy(err_msg, "Could not read Static Server");
    }
    return app; 
  }

  root = yaml_parse(Config->Server.File.config.str);

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
  app_nodes = get_nodes(root, "Application Specification");

  // Iterate application nodes
  while(app_nodes) {
    if(app_nodes->child) {
      str = wr_validate_string(get_node_value(app_nodes->child, "name"));// Compare application name
      if(str && strcmp(str, app_name)==0) {
        app = wr_config_application_set(app_nodes, err_msg);
        break;
      }
    }
    app_nodes = NODE_NEXT(app_nodes);
  }

  node_free(root);
  if(app == NULL)   return NULL;
  

  // checking uniqueness for host name. While setting application object, we are parsing raw string of host_names
  // into host_name_list. We can easily check for uniqueness once host_name_list is ready.
  if(app->host_name_list){
    if(wr_chk_host_within_list(app->host_name_list)!=0) {
      LOG_ERROR(WARN,"Checking hosts within list is failed.");
      wr_application_list_free(app);
      return NULL;
    }

    tmp = Config->Application.list;
    while(tmp) {
      if(tmp->host_name_list && strcmp(tmp->name.str, app_name)!= 0 ) {
        if(wr_chk_host_lists(app->host_name_list, tmp->host_name_list)!=0) {
          LOG_ERROR(WARN,"Checking host lists is failed.");
          wr_application_list_free(app);
          return NULL;
        }
      }
      tmp = tmp->next;
    }
  }
  
  //Set application configuration into configuration data structure
  if(flag == TRUE){
    old_app->new = app;
    return old_app;
  }else{    
    app->next = Config->Application.list;
    Config->Application.list = app;
  }
  
  return app;
}

/** Read configuration file and fill configuration object */
int wr_conf_read() {
  LOG_FUNCTION
  node_t *root;

  // Get parsed nodes
  LOG_DEBUG(4,"YAML file path %s", Config->Server.File.config.str);
  root = yaml_parse(Config->Server.File.config.str);

  if(!root) {
    LOG_ERROR(SEVERE, "Config file found with erroneous entries. Please correct it.");
    printf("Config file found with erroneous entries. Please correct it.\n");
    return FALSE;
  }

  // Set server_configuration parameters
  if(wr_config_server_set(root)!=0)
    return FALSE;

  // Set application_configuration list
  wr_iterate_app_node(root);

  wr_remove_app_with_dup_baseuri();

  wr_remove_app_with_dup_host();

  //configuration_print(configuration);
  node_free(root);

  return TRUE;
}

/** Display configuration object */
void wr_conf_display() {
  LOG_FUNCTION
  config_application_list_t *app = Config->Application.list;

  //printf("No of Applications : %d\n", conf->no_of_application);

  // Display Server specification
  printf("Server log level : %d\n", Config->Server.log_level);
  printf("Server port : %d\n", Config->Server.port);
  printf("Server min worker : %d\n", Config->Application.Default.min_workers);
  printf("Server max worker : %d\n", Config->Application.Default.max_workers);
  printf("Access log flag : %d\n", Config->Server.flag & SERVER_ACCESS_LOG);
#ifdef HAVE_GNUTLS
  printf("Server SSL certificate : %s\n", Config->Server.SSL.certificate.str);
  printf("Server SSL key : %s\n", Config->Server.SSL.key.str);
  printf("Server SSL port : %d\n", Config->Server.SSL.port);
#endif

  // Display application specification
  while(app) {
    printf("Application log level : %d\n", app->log_level);
    printf("Application min worker : %d\n", app->max_worker);
    printf("Application max worker : %d\n", app->min_worker);
    printf("Application name : %s\n", app->name.str);
    printf("Application path : %s\n", app->path.str);
    printf("Application baseuri : %s\n", app->baseuri.str);
    if(app->host_name_list) {
      config_host_list_t* host=app->host_name_list;
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
int wr_conf_admin_panel_add() {
  LOG_FUNCTION
  config_application_list_t* app = wr_conf_admin_panel_read();

  if(app != NULL) {
    app->next = Config->Application.list;
    Config->Application.list = app;
    return 0;
  } else {
    printf("'Admin Panel' could not be started. To start 'Admin Panel' run server with root privileges.\n");
  }

  return -1;
}

/** Add the configuration for static content server */
int wr_conf_static_server_add() {
  LOG_FUNCTION
  config_application_list_t* app = wr_conf_static_server_read();

  if(app != NULL) {
    app->next = Config->Application.list;
    Config->Application.list = app;
    return 0;
  }

  return -1;
}
