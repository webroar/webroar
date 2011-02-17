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
 
 /*****************************************************************
 *     Set Configuration parameters
 *****************************************************************/
 
#include <wr_config.h>
#include <sys/socket.h>

#define SERVER_NAME       "WebROaR"
#define SERVER_VERSION    "0.5.1"
 
#define FILE_PATH         "FILE_PATH"
#define CONN_ID           "CONNECTION_ID"
#define REQ_ID            "REQ_ID"
#define RESP_CODE         "RESP_CODE"
#define RESP_CONTENT_LEN  "RESP_CONTENT_LEN"

int wr_config_server_init(config_t *Config, const char* root_path){
  wr_string_new(Config->Server.Dir.root, root_path, strlen(root_path));

  Config->Server.Control.conn_pool = 5;
  wr_string_new(Config->Server.Control.sock_path, "/tmp/webroar_controller_sock", strlen("/tmp/webroar_controller_sock"));
  
  wr_string_new(Config->Server.File.sock, "/tmp/webroar.sock", strlen("/tmp/webroar.sock"));
  wr_string_new(Config->Server.File.pid, "/var/run/webroar.pid", strlen("/var/run/webroar.pid"));
  wr_string_new(Config->Server.File.high_rss, "/var/run/high_rss.pid", strlen("/var/run/high_rss.pid"));
  wr_string_new(Config->Server.File.log, "webroar.log", strlen("webroar.log"));  
  wr_string_dump(Config->Server.File.config, Config->Server.Dir.root);
  wr_string_append(Config->Server.File.config, "/conf/config.yml", strlen("/conf/config.yml"));
  wr_string_dump(Config->Server.File.internal_config, Config->Server.Dir.root);
  wr_string_append(Config->Server.File.internal_config, "/conf/server_internal_config.yml", strlen("/conf/server_internal_config.yml"));
  wr_string_dump(Config->Server.File.worker_bin, Config->Server.Dir.root);
  wr_string_append(Config->Server.File.worker_bin, "/bin/webroar-worker", strlen("/bin/webroar-worker"));

  wr_string_dump(Config->Server.Dir.admin_panel, Config->Server.Dir.root);
  wr_string_append(Config->Server.Dir.admin_panel, "/admin_panel", strlen("/admin_panel"));
  
  Config->Server.Worker.max         = 20;
  Config->Server.Worker.pending     = 10;
  Config->Server.Worker.add_trials  = 3;
  Config->Server.Worker.add_wait    = 1800;
  Config->Server.Worker.add_timeout = 25;
  Config->Server.Worker.kill_timeout= 10;
  Config->Server.Worker.idle_time   = 60;
  Config->Server.Worker.ping_timeout= 15;
  Config->Server.Worker.ping_trials = 2;

#ifdef HAVE_GNUTLS
  Config->Server.SSL.port  = 443;
  wr_string_null(Config->Server.SSL.certificate);
  wr_string_null(Config->Server.SSL.key);
#endif
  
  wr_string_new(Config->Server.name, SERVER_NAME, strlen(SERVER_NAME));
  wr_string_new(Config->Server.version, SERVER_VERSION, strlen(SERVER_VERSION));
  
  Config->Server.port            = 3000;
  Config->Server.log_level       = SEVERE;  
  // using 'AF_UNIX' macro to identify UDS support.  
#ifdef AF_UNIX
  Config->Server.flag            = SERVER_UDS_SUPPORT;
#else
  Config->Server.flag            = 0;
#endif
  Config->Server.flag            |= SERVER_KEEP_ALIVE;
  Config->Server.stack_trace     = 50;

  return TRUE;
}

int wr_config_application_init(config_t *Config){
  Config->Application.Default.min_workers = 4;
  Config->Application.Default.max_workers = 8;
  wr_string_new(Config->Application.Default.env, "production", strlen("production"));
    
  wr_string_new(Config->Application.Admin_panel.name, "Admin Panel", strlen("Admin Panel"));
  wr_string_new(Config->Application.Admin_panel.base_uri, "/admin-panel", strlen("/admin-panel"));
  
  wr_string_new(Config->Application.Static_server.name, "static-worker", strlen("static-worker"));
  Config->Application.Static_server.min_workers = 4;
  Config->Application.Static_server.max_workers = 8;
  
  wr_string_new(Config->Application.analytics_on, "enabled", strlen("enabled"));
  Config->Application.msg_queue_size  = 2048;
  Config->Application.max_req_ratio   = 1;
  Config->Application.min_req_ratio   = 3;
  Config->Application.high_load       = 2;
  Config->Application.low_load        = 600;
  Config->Application.max_hosts       = 16;
  
  Config->Application.list = NULL;
  
  return TRUE;
}

int wr_config_worker_init(config_t *Config, const char *root_path){
  
  wr_u_short root_path_len = strlen(root_path);
  
  wr_string_new(Config->Worker.File.config, root_path, root_path_len);
  wr_string_append(Config->Worker.File.config, "/conf/config.yml", strlen("/conf/config.yml"));
  wr_string_new(Config->Worker.File.mime_type, root_path, root_path_len);
  wr_string_append(Config->Worker.File.mime_type, "/conf/mime_type.yml", strlen("/conf/mime_type.yml"));
  wr_string_new(Config->Worker.File.internal_config, root_path, root_path_len);
  wr_string_append(Config->Worker.File.internal_config, "/conf/server_internal_config.yml", strlen("/conf/server_internal_config.yml"));
  wr_string_new(Config->Worker.File.app_loader, root_path, root_path_len);
  wr_string_append(Config->Worker.File.app_loader, "/src/ruby_lib/webroar_app_loader.rb", strlen("/src/ruby_lib/webroar_app_loader.rb"));
  
  wr_string_new(Config->Worker.Header.file_path, FILE_PATH, strlen(FILE_PATH));
  wr_string_new(Config->Worker.Header.conn_id, CONN_ID, strlen(CONN_ID));
  wr_string_new(Config->Worker.Header.req_id, REQ_ID, strlen(REQ_ID));
  wr_string_new(Config->Worker.Header.resp_code, RESP_CODE, strlen(RESP_CODE));
  wr_string_new(Config->Worker.Header.resp_content_len, RESP_CONTENT_LEN, strlen(RESP_CONTENT_LEN));
  
  wr_string_new(Config->Worker.Server.name, SERVER_NAME, strlen(SERVER_NAME));
  wr_string_new(Config->Worker.Server.version, SERVER_VERSION, strlen(SERVER_VERSION));
  
  wr_string_new(Config->Worker.static_server, "static-worker", strlen("static-worker"));
  wr_string_new(Config->Worker.sock_path, "/tmp/webroar_worker_sock", strlen("/tmp/webroar_worker_sock"));
  Config->Worker.stack_tace    = 50;
  Config->Worker.max_body_size = 65536;
  
  Config->Worker.Compress.lower_limit = 10240;   //10KB
  Config->Worker.Compress.upper_limit = 1024*1024; //1MB
  
  return TRUE;
}

int wr_config_request_init(config_t *Config){
  Config->Request.prefix_hash     = 5381;
  Config->Request.conn_pool       = 10;
  Config->Request.max_body_size   = 65536;
  Config->Request.max_uri_size    = 12288;
  Config->Request.max_path_size   = 1024;
  Config->Request.max_frag_size   = 1024;
  Config->Request.max_query_size  = 1024;
  Config->Request.max_field_size  = 256;
  Config->Request.max_value_size  = 81920;
  Config->Request.max_header_size = 112640;
  Config->Request.max_header_count= 40;
  
#ifdef L_DEBUG
  wr_string_new(Config->Request.Header.conn_id, CONN_ID, strlen(CONN_ID));
  wr_string_new(Config->Request.Header.req_id, REQ_ID, strlen(REQ_ID));
#endif
  wr_string_new(Config->Request.Header.file_path, FILE_PATH, strlen(FILE_PATH));
  wr_string_new(Config->Request.Header.resp_code, RESP_CODE, strlen(RESP_CODE));
  wr_string_new(Config->Request.Header.resp_content_len, RESP_CONTENT_LEN, strlen(RESP_CONTENT_LEN));
  
  return TRUE;
}
 
config_t* wr_worker_config_init(const char* root_path){  
  config_t *Config;
  if(root_path == NULL) return NULL;
  Config = wr_malloc(config_t);
  
  if(Config){
    if(!wr_config_worker_init(Config, root_path)){
      free(Config);
      return NULL;      
    }    
  }
  
  return Config;
}

config_t* wr_server_config_init(const char *root_path){  
  config_t *Config;
  wr_u_short retval = TRUE;
  
  if(root_path == NULL) return NULL;
  Config = wr_malloc(config_t);
  

  if(Config){
    if(!wr_config_server_init(Config, root_path)) retval = FALSE;
    if(!wr_config_request_init(Config))           retval = FALSE;
    if(! wr_config_application_init(Config))      retval = FALSE;
  }
  
  if(retval == FALSE){
    free(Config);
    return NULL;
  }
  
  return Config;
}

void wr_config_server_free(config_t *Config){
  wr_string_free(Config->Server.Control.sock_path);
  wr_string_free(Config->Server.File.sock);
  wr_string_free(Config->Server.File.pid);
  wr_string_free(Config->Server.File.high_rss);
  wr_string_free(Config->Server.File.log);
  wr_string_free(Config->Server.File.config);
  wr_string_free(Config->Server.File.internal_config);
  wr_string_free(Config->Server.File.worker_bin);
  wr_string_free(Config->Server.Dir.admin_panel);
  wr_string_free(Config->Server.Dir.root);
#ifdef HAVE_GNUTLS
  wr_string_free(Config->Server.SSL.certificate);
  wr_string_free(Config->Server.SSL.key);
#endif
  wr_string_free(Config->Server.name);
  wr_string_free(Config->Server.version);
}

void wr_config_request_free(config_t *Config){
#ifdef L_DEBUG
  wr_string_free(Config->Request.Header.conn_id);
  wr_string_free(Config->Request.Header.req_id);
#endif
  wr_string_free(Config->Request.Header.file_path);
  wr_string_free(Config->Request.Header.resp_code);
  wr_string_free(Config->Request.Header.resp_content_len);
}

void wr_config_application_free(config_t *Config){
  wr_string_free(Config->Application.Default.env);
  wr_string_free(Config->Application.Admin_panel.name);
  wr_string_free(Config->Application.Admin_panel.base_uri);
  wr_string_free(Config->Application.Static_server.name);
  wr_string_free(Config->Application.analytics_on);
  wr_application_list_free(Config->Application.list);
}

void wr_config_worker_free(config_t *Config){
  wr_string_free(Config->Worker.File.config);
  wr_string_free(Config->Worker.File.mime_type);
  wr_string_free(Config->Worker.File.internal_config);
  wr_string_free(Config->Worker.File.app_loader);
  wr_string_free(Config->Worker.Header.file_path);
  wr_string_free(Config->Worker.Header.conn_id);
  wr_string_free(Config->Worker.Header.req_id);
  wr_string_free(Config->Worker.Header.resp_code);
  wr_string_free(Config->Worker.Header.resp_content_len);
  wr_string_free(Config->Worker.Server.name);
  wr_string_free(Config->Worker.Server.version);
  wr_string_free(Config->Worker.static_server);
  wr_string_free(Config->Worker.sock_path);
}

void wr_host_list_free(config_host_list_t *list) {
  config_host_list_t *next;
  while(list) {
    next = list->next;
    wr_string_free(list->name);
    free(list);
    list = next;
  }
}

/** Destroy application configuration */
void wr_application_list_free(config_application_list_t* list){
  LOG_FUNCTION
  config_application_list_t* next;
  
  // Iterate applications and destroy each application
  while(list) {
    next = list->next;
    wr_string_free(list->name);
    wr_string_free(list->baseuri);
    wr_string_free(list->path);
    scgi_free(list->scgi);
    wr_host_list_free(list->host_name_list);
    wr_application_list_free(list->new);
    free(list);
    list = next;
  }
}

void wr_server_config_free(config_t *Config){
  if(Config == NULL) return;
  wr_config_server_free(Config);
  wr_config_request_free(Config);
  wr_config_application_free(Config);
  free(Config);
}

void wr_worker_config_free(config_t *Config){
  if(Config == NULL) return;
  wr_config_worker_free(Config);
  free(Config);
}

void wr_set_numeric_value(node_t *root, const char *path, void *value, wr_u_short flag){
  char *str = yaml_validate_string(yaml_get_value(root, path));
  long *lvalue = (long*) value;
  if(str) {
    wr_u_long val = atoi(str);
    if(val > 0){
      *lvalue = val;
    }else if(flag && strcmp(str,"0") == 0){
      *lvalue = 0;
    }
  }  
}
