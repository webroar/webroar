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
/**********************************************************
 *             Worker
 *********************************************************/

/**
 * Parse argument list
 * Initialize Worker to accept SCGI request from Head
 * Load web application
 * Start Atals Worker
 */

#include <worker.h>
#include <stdlib.h>
#include <assert.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <ev.c>
#include <pwd.h>

#ifdef __linux__
#include <sys/prctl.h>
#endif

extern config_t *Config;

void load_application(wkr_t* w);

wkr_tmp_t* wkr_tmp_new() {
  LOG_FUNCTION
  wkr_tmp_t *tmp = wr_malloc(wkr_tmp_t);

  if(tmp == NULL) {
    return NULL;
  }
  wr_string_null(tmp->path);
  wr_string_null(tmp->env);
  wr_string_null(tmp->type);
  wr_string_null(tmp->name);
  wr_string_null(tmp->resolver);
  wr_string_null(tmp->root_path);
  wr_string_null(tmp->ctl_path);
  wr_string_null(tmp->log_file);

  tmp->profiler = 'n';
  tmp->gid = tmp->uid = 0;
  // HTTP1.1 assumes persistent connection by default
  tmp->keep_alive = TRUE;
  tmp->is_uds = FALSE;
  tmp->is_static = 0;
#ifdef W_ZLIB
  tmp->lower_limit = tmp->upper_limit = 0;
#ifdef W_REGEX
  wr_string_null(tmp->r_user_agent);
  wr_string_null(tmp->r_content_type);
#endif
#endif
  return tmp;
}

void wkr_tmp_free(wkr_tmp_t** t) {
  LOG_FUNCTION
  wkr_tmp_t *tmp = *t;
  if(tmp) {
    wr_string_free(tmp->path);
    wr_string_free(tmp->env);
    wr_string_free(tmp->type);
    wr_string_free(tmp->name);
    wr_string_free(tmp->resolver);
    wr_string_free(tmp->root_path);
    wr_string_free(tmp->ctl_path);
    wr_string_free(tmp->log_file);
#if defined(W_ZLIB) && defined(W_REGEX)
    wr_string_free(tmp->r_content_type);
    wr_string_free(tmp->r_user_agent);
#endif
    free(tmp);
  }
  *t = NULL;
}

/** Create new Worker */
wkr_t* worker_new(struct ev_loop *loop, wkr_tmp_t *tmp) {
  LOG_FUNCTION
  wkr_t* w = wr_malloc(wkr_t);

  assert(w!=NULL);

  w->req_fd = -1;
  w->listen_fd = -1;
  w->is_uds = tmp->is_uds;
  w->loop = loop;
  wr_string_null(w->sock_path);
  w->listen_port = 0;

  w->tmp = tmp;
  assert(w->tmp!=NULL);

  w->env_var = NULL;
  
  w->ctl = wkr_ctl_new(w);
  assert(w->ctl!=NULL);
  if(connect_to_head(w) == FALSE){
    worker_free(&w);
    return NULL;
  }
  start_ctl_watcher(w);
/*  if(w->tmp->is_static){
    w->ctl->scgi = scgi_new();
    load_application(w);
  } else */ if(send_config_req_msg(w) < 0){
    worker_free(&w);
    return NULL;
  }

  // Connect to head controller UDS socket before user previliges get lowered.
  
  return w;
}

void worker_free(wkr_t **wrk) {
  LOG_FUNCTION
  wkr_t *w = *wrk;
  if(w) {
    if(w->req_fd > 0)
      close(w->req_fd);
    if(w->listen_fd > 0)
      close(w->listen_fd);
    if(w->sock_path.str) {
      // Set root privilege to remove socket file.
      //      if(setegid(0)!=0){
      //        LOG_ERROR(SEVERE,"setegid() to root failed");
      //      }
      //      if(seteuid(0)!=0){
      //        LOG_ERROR(SEVERE,"seteuid() to root failed");
      //      }
      unlink(w->sock_path.str);
      wr_string_free(w->sock_path);
    }
    ev_io_stop(w->loop, &(w->w_accept));
    ev_io_stop(w->loop, &(w->ctl->w_read));
    if(w->http)
      http_free(&w->http);    
    if(w->tmp)
      wkr_tmp_free(&w->tmp);
    if(w->ctl)
      wkr_ctl_free(&w->ctl);

    wr_string_list_free(w->env_var);
    free(w);
  }
  *wrk=NULL;
}

/** Conenct worker on internet socket */
int listen_internet_socket(wkr_t* w) {
  LOG_FUNCTION
  struct sockaddr_in addr;
  if ((w->listen_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    perror("socket()");
    return -1;
  }

  if(setnonblock(w->listen_fd)<0) {
    LOG_ERROR(SEVERE,"Setting fd non block failed");
    return -1;
  }
  setsocketoption(w->listen_fd);
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = 0; // to bind to an ephemeral port
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(w->listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("bind()");
    return -1;
  }
  //determine port to which listen_fd bound
  int len = sizeof(addr);
  if(getsockname(w->listen_fd,(struct sockaddr *)&addr, &len) < 0) {
    LOG_ERROR(4,"getsockname():%s",strerror(errno));
    return -1;
  }
  w->listen_port = ntohs(addr.sin_port);
  LOG_DEBUG(4,"connect_internet_socket() Initializing worker at port %d. FD is=%d",w->listen_port, w->listen_fd);
  // TODO: Accept connections only from WebROaR
  if (listen(w->listen_fd,2) < 0) {
    perror("listen()");
    return -1;
  }
  return 0;
}

int listen_unix_socket(wkr_t* w) {
  LOG_FUNCTION
  struct sockaddr_un addr;

  if ((w->listen_fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    LOG_ERROR(SEVERE,"Socket opening error:%s",strerror(errno));
    return -1;
  }

  if(setnonblock(w->listen_fd)<0) {
    LOG_ERROR(SEVERE,"Setting fd non block failed");
    return -1;
  }
  setsocketoption(w->listen_fd);
  memset(&addr, 0, sizeof(addr));
  /* Preparing socket path unique to this worker*/
  w->sock_path.str = (char*) malloc(sizeof(char)*50);
  w->sock_path.len = sprintf(w->sock_path.str, "%s_%d", Config->Worker.sock_path.str, getpid());

  LOG_DEBUG(DEBUG,"connect_unix_socket() socket name is %s",w->sock_path.str);

  addr.sun_family = AF_UNIX;
  //strcpy(addr.sun_path,w->sock_path);
  strcpy(addr.sun_path,w->sock_path.str);
  unlink(addr.sun_path);
  LOG_DEBUG(DEBUG,"connect_unix_socket() Binding worker at socket path %s",w->sock_path.str);

  int len = sizeof(addr.sun_family) + strlen(addr.sun_path);
#ifdef __APPLE__
  len ++;
#endif

  if (bind(w->listen_fd, (struct sockaddr *)&addr, len) < 0) {
    perror("bind()");
    return -1;
  }
  //LOG_DEBUG(DEBUG,"connect_unix_socket() Listening worker at socket path %s",w->sock_path);
  LOG_DEBUG(DEBUG,"connect_unix_socket() Listening worker at socket path %s",w->sock_path.str);
  /* TODO: Accept connections only from WebROaR*/
  if (listen(w->listen_fd,2) < 0) {
    perror("listen()");
    return -1;
  }
  return 0;
}


/** Connect worket to Head */
int worker_listen(wkr_t* w) {
  LOG_FUNCTION
  int retval;
  if(w->is_uds == 1) {
    return listen_unix_socket(w);
  }else{
    return listen_internet_socket(w);
  }

//  if(retval >= 0 ) return send_ack_ctl_msg(w);
}

/** This function accept connection from Head. */
void request_accept_cb(struct ev_loop *loop, struct ev_io *watcher, int revents) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) watcher->data;

  if(EV_ERROR & revents) {
    LOG_ERROR(SEVERE,"request_accept_cb() got error event, returning.\n");
    return;
  }

  if(w->is_uds) {
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);
    w->req_fd = accept(watcher->fd, (struct sockaddr *)&client_addr, &client_len); 
    //TODO: accept from WebROaR Head only
  } else {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    w->req_fd = accept(watcher->fd, (struct sockaddr *)&client_addr, &client_len); 
    //TODO: accept from WebROaR Head only
  }

  if (w->req_fd < 0) {
    LOG_ERROR(SEVERE,"accept() error:%s",strerror(errno));
    return;
  }

  if (setnonblock(w->req_fd) < 0) {
    LOG_ERROR(FATAL, "failed to set client socket to non-blocking");
    return;
  }
  LOG_INFO("Successfully connected with client. Read watcher starting");
  w->w_req.data = w;
  //worker_conversation_set(w->w_conversation);
  ev_io_init(&(w->w_req), http_req_header_cb, w->req_fd, EV_READ);
  ev_io_start(loop, &(w->w_req));
}

void worker_accept_requests(wkr_t* w) {
  LOG_FUNCTION
  w->w_accept.data = w;
  ev_io_init(&(w->w_accept), request_accept_cb, w->listen_fd, EV_READ);
  ev_io_start(w->loop,&(w->w_accept));
  //wkr_tmp_free(&w->tmp);
}

int drop_privileges(wkr_t *w, scgi_t *scgi) {
  char *str;
  
  str = (char*) scgi_header_value_get(scgi, "USER");
  
  if(str && strlen(str) > 0) {
    struct passwd *user_info=NULL;
    user_info = getpwnam(str);
    // Check for user existence
    if(user_info) {
      w->tmp->uid = user_info->pw_uid; 
      w->tmp->gid = user_info->pw_gid;
    } else {
      scgi_body_add(w->ctl->scgi, "Application run_as_user is invalid. Application not started.", strlen("Application run_as_user is invalid. Application not started."));
      LOG_ERROR(SEVERE,"Application run_as_user is invalid. Application not started.");
      return FALSE;
    }
  } else {
    scgi_body_add(w->ctl->scgi, "Application run_as_user is missing. Application not started.", strlen("Application run_as_user is missing. Application not started."));
    LOG_ERROR(SEVERE,"Application run_as_user is missing. Application not started.");
    return FALSE;
  }
  
  change_log_file_owner(w->tmp->uid, w->tmp->gid);
  //setting read, effective, saved group and user id
  if(setgid(w->tmp->gid)!=0) {
    scgi_body_add(w->ctl->scgi, "setegid() failed", strlen("setegid() failed"));
    LOG_ERROR(SEVERE,"setegid() failed");
    return FALSE;
  }
  if(setuid(w->tmp->uid)!=0) {
    scgi_body_add(w->ctl->scgi, "seteuid() failed", strlen("seteuid() failed"));
    LOG_ERROR(SEVERE,"seteuid() failed");
    return FALSE;
  }
  
  LOG_DEBUG(DEBUG,"Passed userid=%d and groupid=%d",
            w->tmp->uid, w->tmp->gid);
  LOG_DEBUG(DEBUG,"effective userid=%d and groupid=%d",geteuid(),getegid());
#ifdef __linux__
  int rv = prctl(PR_SET_DUMPABLE, 1, 0, 0, 0);
  LOG_DEBUG(DEBUG,"prctl(PR_SET_DUMPABLE, 1, 0, 0, 0) = %d", rv);
  if (rv < 0) {
    LOG_ERROR(SEVERE,"error setting prctl(PR_SET_DUMPABLE, 1, 0, 0, 0), errno = %d, desc = %s", errno, strerror(errno));
  }
#endif  
  return TRUE;
}

void manipulate_environment_variable(wkr_t* w, scgi_t *scgi) {
  LOG_FUNCTION
  char *var, *str;
  int rv = 0;  
    
  str = (char*) scgi_header_value_get(scgi, "ENV_VAR");
  w->env_var = wr_string_list_new();  
  if(str){    
    var = strtok(str,"#");
    while(var){
      LOG_DEBUG(DEBUG,"Environment variable string = %s", var);
      wr_string_list_add(w->env_var, var, strlen(var));
       // TODO: see the security concerns     
      rv = putenv(w->env_var->rear->str.str);
      if (rv != 0) {
        LOG_ERROR(WARN, "putenv() failed, errno = %d, description = %s", errno, strerror(errno)); 
      } 
      var = strtok(NULL,"#");
    }
  }
}

void load_application(wkr_t* w){
  LOG_FUNCTION
  
  w->ctl->scgi = scgi_new();
  if(w->ctl->scgi == NULL) {
    LOG_ERROR(SEVERE,"Cannot create SCGI Request");
    sigproc();
    return;
  }
  
  w->http = http_new(w);
  if(w->http == NULL) {
    scgi_body_add(w->ctl->scgi, "unable to load application.", strlen("unable to load application."));
    LOG_ERROR(SEVERE,"unable to load application.");
  }else if(worker_listen(w) < 0) {
    scgi_body_add(w->ctl->scgi, "Error Initializing Workers.", strlen("Error Initializing Workers."));
    LOG_ERROR(WARN,"Error Initializing Workers.");
  }else{
    worker_accept_requests(w);
    LOG_INFO("Worker ready for serving requests.");
    init_idle_watcher(w);
    
    LOG_INFO("Successfully loaded rack application=%s with environment=%s",
             w->tmp->path.str,   w->tmp->env.str);
  }  
  
  //loading adapter according to application type
  LOG_DEBUG(DEBUG,"webroar_root = %s", w->tmp->root_path.str);
  LOG_DEBUG(DEBUG,"path = %s, name = %s, type = %s, environment = %s, baseuri = %s, analytics = %c",
            w->tmp->path.str,  w->tmp->name.str, w->tmp->type.str,
            w->tmp->env.str, w->tmp->resolver.str, w->tmp->profiler);
  
  // Send error or ok acknowledgement message
  if(w->ctl->scgi->body_length > 0){
    // Send error response
    w->ctl->error = TRUE;
    get_worker_add_ctl_scgi(w, TRUE);
    ev_io_start(w->loop,&(w->ctl->w_write));
    ev_timer_again(w->loop, &w->ctl->t_ack);
  }else{
    // Send acknowledgement message
    get_worker_add_ctl_scgi(w, FALSE);
    ev_io_start(w->loop,&(w->ctl->w_write));        
  }
  wkr_tmp_free(&w->tmp);
}

void application_config_read_cb(wkr_t* w, scgi_t *scgi){
  LOG_FUNCTION
  char *str;
  /*w->ctl->scgi = scgi_new();
  
  if(w->ctl->scgi == NULL) {
    LOG_ERROR(SEVERE,"Cannot create SCGI Request");
    sigproc();
    return;
  } */ 
  
  if(w->tmp->is_static){

#ifdef W_ZLIB
    str = (char*) scgi_header_value_get(scgi, "LOWER_LIMIT");
    if(str){
      w->tmp->lower_limit = atol(str);
    }

    str = (char*) scgi_header_value_get(scgi, "UPPER_LIMIT");
    if(str){
      w->tmp->upper_limit = atol(str);
    }

#ifdef W_REGEX
    str = (char*) scgi_header_value_get(scgi, "CONTENT_TYPE");
    if(str){
      wr_string_new(w->tmp->r_content_type, str, strlen(str));
    }else {
      wr_string_new(w->tmp->r_content_type, DEFAULT_CONTENT_TYPE, strlen(DEFAULT_CONTENT_TYPE));
    }


    str = (char*) scgi_header_value_get(scgi, "USER_AGENT");
    if(str){
      wr_string_new(w->tmp->r_user_agent, str, strlen(str));
    }
#endif

#endif
  }else{
    if(drop_privileges(w, scgi) == FALSE) {
      wkr_tmp_free(&w->tmp);
      sigproc();
      return;
    }
    
    manipulate_environment_variable(w, scgi);
    str = (char*) scgi_header_value_get(scgi, "PATH");
    if(str){
      wr_string_new(w->tmp->path, str, strlen(str));
    }

    str = (char*) scgi_header_value_get(scgi, "ENV");
    if(str){
      wr_string_new(w->tmp->env, str, strlen(str));
    }

    str = (char*) scgi_header_value_get(scgi, "TYPE");
    if(str){
      wr_string_new(w->tmp->type, str, strlen(str));
    }

    str = (char*) scgi_header_value_get(scgi, "BASE_URI");
    if(str){
      wr_string_new(w->tmp->resolver, str, strlen(str));
    }

    str = (char*) scgi_header_value_get(scgi, "ANALYTICS");
    if(str && strcmp(str,"enabled")==0){
      w->tmp->profiler = 'y';
    }else{
      w->tmp->profiler = 'n'; 
    }
  }
  
  load_application(w);
}