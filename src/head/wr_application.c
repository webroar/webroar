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
#include <wr_request.h>

// Worker count
static unsigned int worker_count = 0;
extern config_t *Config;

/************** Private Functions ******************/

// Check whether application already exist
wr_app_t* wr_app_exist(wr_svr_t *server, const char *app_name){
  wr_app_t* app = server->apps, *tmp_app = NULL;
  while(app) {
    if(strcmp(app_name, app->conf->name.str)==0)
      return app;
    tmp_app = app;
    app = app->next;
  }
  if(strcmp(app_name, Config->Application.Static_server.name.str) == 0){
    return server->static_app;
  }
  
  return NULL;
}

// Check whether pending worker exist
wr_pending_wkr_t* wr_pending_worker_exist(wr_app_t *app, const int pid){
  int i;
  for(i = 0 ; i < WR_QUEUE_SIZE(app->q_pending_workers); i++){
    wr_pending_wkr_t* pending = wr_queue_fetch(app->q_pending_workers);
    if(pending && *pending == pid) return pending;
    wr_queue_insert(app->q_pending_workers, pending);
  }
  return NULL;
}

/** Callback function to add worker to application */
void wr_app_wkr_add_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;
  ev_timer_stop(loop, &app->t_add);

  //do we need high load ratio check?
  if(TOTAL_WORKER_COUNT(app) < app->conf->max_worker) {
    wr_app_wkr_add(app);
  }
}

/** Set flag to TRUE to kill single pending worker */
void wr_app_kill_pending_wkr(wr_app_t* app, const int flag){
  int pid = 0;
  wr_pending_wkr_t *pending;

  while(WR_QUEUE_SIZE(app->q_pending_workers) > 0) {
    pending = wr_queue_fetch(app->q_pending_workers);
    if(pending){
      pid = *pending;
      free(pending);
    }
    LOG_INFO("wr_app_kill_pending_wkr: killing worker, pid = %d", pid);
    if(pid > 0)
      kill(pid ,SIGKILL);
    if(flag) break;
  }
  app->high_ratio = TOTAL_WORKER_COUNT(app) * Config->Application.max_req_ratio;
}

void wr_app_add_error_msg(wr_app_t* app){
  int err_msg_len = 0;
  char err_msg[512];

  LOG_DEBUG(DEBUG,"Some problem occurred while starting Application %s.", app->conf->name.str);
  if(app->ctl){
    scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    err_msg_len = sprintf(err_msg,"The application could not be started due to the following error. Please refer '/var/log/webroar/%s.log' and the application log file for more details.", app->conf->name.str);
    scgi_body_add(app->ctl->scgi, err_msg, err_msg_len);
    wr_ctl_resp_write(app->ctl);
    LOG_ERROR(SEVERE, "%s", err_msg);
  }else {
    LOG_ERROR(SEVERE, "Some problem occurred while starting Application %s.", app->conf->name.str);
  }
  
  app->timeout_counter = 0;
  app->ctl = NULL; 
}

/** Remove application from application list */
int wr_app_remove(wr_svr_t* server, const char* app_name) {
  LOG_FUNCTION
  wr_app_t* app = server->apps, *tmp_app = NULL;
  
  LOG_DEBUG(DEBUG, "Removing application %s", app_name);
  
  while(app) {
    if(strcmp(app_name, app->conf->name.str)==0)
      break;
    tmp_app = app;
    app = app->next;
  }
  if(app) {
    if(tmp_app) {      
      tmp_app->next = app->next;
    } else {
      server->apps = app->next;
    }
    
    app->next = NULL;
    wr_app_free(app);
    wr_app_conf_remove(app_name);
    return 0;
  } else if(strcmp(app_name, Config->Application.Static_server.name.str) == 0){
    wr_app_free(server->static_app);
    server->static_app = NULL;
    wr_app_conf_remove(app_name);
    return 0;
  } else {
    LOG_ERROR(WARN,"Aapplication %s didn't found in list", app_name);
    sprintf(server->err_msg, "Application '%s' is not found.", app_name);
    return -1;
  }
}

/** Callback function to add worker timeout */
void wr_app_wkr_add_timeout_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;
  
  LOG_ERROR(SEVERE,"wr_app_wkr_add_timeout_cb");

  // Stop add timeout timer and increament timeout counter
  ev_timer_stop(loop, &app->t_add_timeout);
  app->timeout_counter ++;

  if(app->timeout_counter > Config->Server.Worker.add_trials){
    LOG_ERROR(SEVERE,"Reset worker timeout counter for %s.", app->conf->name.str);
    app->timeout_counter = 0;
    return;
  }else if(app->timeout_counter == Config->Server.Worker.add_trials){
    LOG_ERROR(SEVERE,"worker timeout counter for %s exceeds limit.", app->conf->name.str);

    app->timeout_counter ++;

    wr_app_kill_pending_wkr(app, FALSE);

    app->t_add_timeout.repeat = Config->Server.Worker.add_wait;
    ev_timer_again(loop, &app->t_add_timeout);
  }

  // Kill oldest pending worker
  wr_app_kill_pending_wkr(app, TRUE);

  if(WR_QUEUE_SIZE(app->q_pending_workers) > 0) {
    ev_timer_again(loop, &app->t_add_timeout);
  }
  
  // If application restarted, rollback all the changes.
  if(app->state == WR_APP_RESTART){
    wr_application_list_free(app->conf->new);
    app->conf->new = NULL;
    app->state = WR_APP_ACTIVE;
    // Send error response
    wr_app_add_error_msg(app);
    return;
  }else if(app->state == WR_APP_NEW){
    if(WR_QUEUE_SIZE(app->q_pending_workers) == 0){
      // Send error response
      wr_app_add_error_msg(app);
      wr_app_remove(app->svr, app->conf->name.str);
    }
    return;
  }
  
  wr_app_wkr_balance(app);
}

/** Callback function to remove worker from application */
void wr_app_wkr_remove_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;

  ev_timer_stop(loop, &app->t_remove);

  // Following variable helps in removing unncecessary call to wr_app_wkr_remove_cb
  int forecasted_count=app->q_workers->q_count;
  // Its a known bug - At any time app->active_worker should equals to app->q_workers->q_count
  // Scenario: We are forking new worker due to high load and also increasing active worker count.
  // It took some time to get register with Head, and actual queue count incremented after Head
  // register the newly created worker. Now, mean while load goes down, and we are ready to remove the
  // worker.
  // Now there could be two things,
  // First, newly created worker failed to successful registration.
  // Second, newly created worker took little extra time for successful registration.
  // In both case active worker indicate wrong number and we try to remove the worker which does not exists for Head.
  // To overcome this, we would adjust high load ratio when new worker is added, adjust low load ratio
  // when new worker is actually get registered with Head also, we reset active worker with
  // application worker queue count, whenever worker is actually removed.
  // TODO: Handle above bug properly.
  LOG_DEBUG(DEBUG,"Pending_wkr = %d, app->q_workers->q_count = %d",
            WR_QUEUE_SIZE(app->q_pending_workers), WR_QUEUE_SIZE(app->q_workers));
  if(app->q_workers->q_count > app->conf->min_worker) {
    char cmd[STR_SIZE512];
    char pid_list[STR_SIZE512], pid_c[STR_SIZE32];
    int i,index;
    i = 0;
    index = (app->q_workers->q_front + i) % app->q_workers->q_max_size;
    wr_wkr_t *tmp_worker = (wr_wkr_t*)app->q_workers->q_elements[index];
    
    
    // Get pid of the worker consuming more resident memory
#ifdef __APPLE__
    //sprintf(cmd,"ps -o pid -m -p %s | head -n2 | tail -n1 | cut -c-6 > %s",pid_list, Config->Server.File.high_rss.str);
	/* TODO: when any shell command is executed using system(), process goes into wait state. It is 
	 observed on only Mac. When tried calling syste() at various interval like after port binding,
	 controller initialization, forking required worker, daemonizing, activating event loop etc, in all 
	 cases it was working fine. But after dynamically created worker added into service, call to system()
	 goes into infinite wait.	   
	 In this case we would simply pick the first worker from queue and remove it.
	 */
    FILE *wfp = fopen(Config->Server.File.high_rss.str, "w");
    if(wfp) {
      fprintf(wfp,"%d", tmp_worker->pid); 
      fclose(wfp);
	}
#else
    sprintf(pid_c,"%d",tmp_worker->pid);
    strcpy(pid_list, pid_c);
    i++;
    for(;i < app->q_workers->q_count ; i++) {
      index = (app->q_workers->q_front + i) % app->q_workers->q_max_size;
      tmp_worker = (wr_wkr_t*)app->q_workers->q_elements[index];
      sprintf(pid_c,",%d", tmp_worker->pid);
      strcat(pid_list, pid_c);
    }
    sprintf(cmd,"ps -o pid --sort=rss -p %s | tail -n1 | cut -c-6 > %s",pid_list, Config->Server.File.high_rss.str);
    LOG_DEBUG(DEBUG,"Formed command to remove worker is %s",cmd);
    system(cmd);
#endif
	
    // Read pid from file
    FILE *fp = fopen(Config->Server.File.high_rss.str, "r");
    if(fp) {
      unsigned pid = 0;
      fscanf(fp, "%u", &pid);
      fclose(fp);
      remove(Config->Server.File.high_rss.str);
      int flag = 1;

      // Check for worker in list of free workers. If found remove it.
      if(app->q_free_workers->q_count > 0) {
        LOG_DEBUG(DEBUG,", pid = %d find in free worker", pid);
        //int i, index;
        for( i = 0; i < app->q_free_workers->q_count ; i++) {
          index = (app->q_free_workers->q_front + i) % app->q_free_workers->q_max_size;
          tmp_worker = (wr_wkr_t*)app->q_free_workers->q_elements[index];
          if(tmp_worker->pid == pid) {
            LOG_DEBUG(DEBUG,"Removing from free worker id=%d", tmp_worker->id);
            forecasted_count--;
            tmp_worker->state = WKR_STATE_ERROR;
            wr_wkr_free(tmp_worker);
            LOG_DEBUG(DEBUG,"Worker removed from free worker.");
            flag = 0;
            break;
          }
        }
      }

      // Check for worker in the list of all the worker. If found mark it as in-active.
      // In-active worker will be removed once current request is processed.
      if(flag && app->q_workers->q_count > 0) {
        LOG_DEBUG(DEBUG,"pid = %d find in active worker", pid);
        //int i, index;
        for( i = 0; i < app->q_workers->q_count ; i++) {
          index = (app->q_workers->q_front + i) % app->q_workers->q_max_size;
          tmp_worker = (wr_wkr_t*)app->q_workers->q_elements[index];
          if(tmp_worker->pid == pid) {
            forecasted_count--;
            LOG_DEBUG(DEBUG,"Remove active status id = %d", tmp_worker->id);
            tmp_worker->state = WKR_STATE_EXPIRED;
            break;
          }
        }
      }
    }
  }

  if(forecasted_count > app->conf->min_worker) {
    ev_timer_again(loop, &app->t_remove);
  }
}

/** Reload the application */
int wr_app_reload(wr_app_t *app){
  LOG_FUNCTION
  wr_wkr_t *worker;
  short count;

  // Remove an old application from the resolver list.
  wr_req_resolver_remove(app->svr, app);

  // Update the application configuration.
  wr_conf_app_update(app->conf);
  
  // Add the updated application to resolver list.
  wr_req_resolver_add(app->svr, app);

  // Remove workers based on following logic:
  // If all the workers are free keep a single worker to process the requests and remove all others.
  // Else remove all the free workers.

  LOG_DEBUG(DEBUG,"Free workers queue count is %d. Active worker count is %d.", WR_QUEUE_SIZE(app->q_free_workers), WR_QUEUE_SIZE(app->q_workers));
  while(WR_QUEUE_SIZE(app->q_free_workers) > 0){
    worker = (wr_wkr_t*)wr_queue_fetch(app->q_free_workers);
    // The worker is already removed from free workers list so do not pass the flag.
    worker->state = WKR_STATE_ERROR;
    wr_wkr_free(worker);
  }

  // Mark all existing workers to OLD worker.
  for(count = 0; count < WR_QUEUE_SIZE(app->q_workers) ; count++) {
    worker = (wr_wkr_t*)wr_queue_fetch(app->q_workers);
    wr_queue_insert(app->q_workers, worker);
    worker->state = WKR_STATE_EXPIRED;
  } 

  app->state = WR_APP_RESTARTING;
  return TRUE;
}

/** Create worker for application */
int wr_app_wkr_add(wr_app_t *app) {
  if(WR_QUEUE_SIZE(app->q_pending_workers) < WR_QUEUE_MAX_SIZE(app->q_pending_workers)) {
    if(app->timeout_counter >= Config->Server.Worker.add_trials){
      LOG_ERROR(SEVERE, "Could not fork worker because previous %d workers got timed out.",
                Config->Server.Worker.add_trials);
      return FALSE;
    }
    config_application_list_t *conf = app->conf;
    
    if(app->state == WR_APP_RESTART) conf = app->conf->new; 
    
    int retval = wr_wkr_create(app->svr, conf);
    if(retval > 0){
      wr_pending_wkr_t *pending = wr_malloc(wr_pending_wkr_t);
      *pending = retval;
      wr_queue_insert(app->q_pending_workers, pending);
      app->high_ratio = TOTAL_WORKER_COUNT(app) * Config->Application.max_req_ratio;
      if (Config->Server.Worker.add_timeout > 0) {
        ev_timer_again(app->svr->ebb_svr.loop, &app->t_add_timeout);
      }
      
      LOG_INFO("PID of created worker = %d", retval);
      return TRUE;
    }else{
      LOG_ERROR(SEVERE,"Could not fork process to start new worker.");
    }
  }
  return FALSE;
}

/** Insert application based on application configuration */
int wr_app_insert(wr_svr_t* server, config_application_list_t* config, wr_ctl_t *ctl) {
  LOG_FUNCTION
  wr_app_t* app = wr_malloc(wr_app_t);
  
  if(!app) {
    LOG_ERROR(WARN, "%s() application object allocation failed. Returning ...", __FUNCTION__);
    return FALSE;
  }
  
  // Queue size is Config->Server.Worker.max + 1 to accommodate temporary extra 
  // worker, created during application restart 
  app->q_free_workers     = wr_queue_new(Config->Server.Worker.max + 1);
  app->q_workers         = wr_queue_new(Config->Server.Worker.max + 1);
  app->q_pending_workers = wr_queue_new(Config->Server.Worker.pending);
  
  app->q_messages        = wr_queue_new(Config->Application.msg_queue_size);
  
  if(app->q_workers == NULL || app->q_pending_workers == NULL ||
     app->q_free_workers == NULL || app->q_messages == NULL) {
    free(app);
    app = NULL;
    LOG_ERROR(WARN, "application object initialization failed. Returning ...");
    return FALSE;
  }
  
  app->svr = server;
  app->conf = config;
  app->ctl = ctl;
  app->state = WR_APP_NEW;
  app->timeout_counter = 0;
  app->high_ratio = 0;
  app->t_add.data = app->t_remove.data = app->t_add_timeout.data = app;
  
  /* set application object in control, it would be used at time of freeing control object */
  if(ctl)    ctl->app = app;
  
  if(strcmp(config->name.str, Config->Application.Static_server.name.str) == 0){
    app->next = NULL;
    server->static_app = app;
  }else{
    wr_req_resolver_add(server, app);
    app->next = server->apps;
    server->apps = app;
  }
  
  ev_timer_init (&app->t_add, wr_app_wkr_add_cb, 0., Config->Application.high_load);
  ev_timer_init (&app->t_remove, wr_app_wkr_remove_cb, 0., Config->Application.low_load);
  if (Config->Server.Worker.add_timeout > 0) {
    ev_timer_init (&app->t_add_timeout, wr_app_wkr_add_timeout_cb, 0., Config->Server.Worker.add_timeout);
  }
  
  LOG_DEBUG(4,"%s() Application Added:%s", __FUNCTION__, config->name.str);

  wr_app_wkr_balance(app);
  
  return TRUE;
}

/*************** Application function definition *********/

/** Destroy application */
void wr_app_free(wr_app_t* app) {
  LOG_FUNCTION
  wr_app_t* tmp_app;
  wr_wkr_t* worker;

  while(app) {
    tmp_app = app->next;
    app->state = WR_APP_DESTROY;
    LOG_DEBUG(4,"Destroying application %s...", app->conf->name.str);
    LOG_DEBUG(DEBUG,"Worker count = %d", WR_QUEUE_SIZE(app->q_workers));
    //Destroy workers
    while(worker = (wr_wkr_t*)wr_queue_fetch(app->q_workers)) {
      if(app->svr->is_running == 0)
        worker->state = WKR_STATE_ERROR;
      wr_wkr_free(worker);
    }

    wr_queue_free(app->q_free_workers);
    wr_queue_free(app->q_workers);
    wr_queue_free(app->q_pending_workers);

    wr_req_t *req;
    WR_QUEUE_FETCH(app->q_messages, req)  ;
    while(req) {
      wr_conn_err_resp(req->conn, WR_HTTP_STATUS_500);
      WR_QUEUE_FETCH(app->q_messages, req)  ;
    }

    wr_queue_free(app->q_messages);

    wr_req_resolver_remove(app->svr, app);

    ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add);
    ev_timer_stop(app->svr->ebb_svr.loop, &app->t_remove);
    if (Config->Server.Worker.add_timeout > 0) {
      ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add_timeout);
    }
    free(app);
    app = tmp_app;
  }
}

/** Display application structure */
void wr_app_print(wr_app_t*app) {
  while(app) {
    LOG_DEBUG(4,"Application %s", app->conf->name.str);
    app = app->next;
  }
}

/** Balance number of workers */
void wr_app_wkr_balance(wr_app_t *app){
  // Maintain minimum number of workers
  //while(TOTAL_WORKER_COUNT(app) < app->conf->min_worker && app->timeout_counter < Config->Server.Worker.add_trials){
  while(TOTAL_WORKER_COUNT(app) < app->conf->min_worker){
    if(wr_app_wkr_add(app) == FALSE)   break;
    app->low_ratio = TOTAL_WORKER_COUNT(app) * Config->Application.min_req_ratio;
  }

  if(WR_QUEUE_SIZE(app->q_workers) >= app->conf->min_worker && app->state == WR_APP_RESTART){
    app->state = WR_APP_ACTIVE;
    wr_application_list_free(app->conf->new);
    app->conf->new = NULL;
  }
  
  // Create worker if application is high loaded
/*
  if(TOTAL_WORKER_COUNT(app) < app->conf->max_worker && WR_QUEUE_SIZE(app->q_messages) > app->high_ratio){
    wr_app_wkr_add(app);
  }
*/
}

/** Got worker add error */
int wr_app_wkr_error(wr_svr_t *server, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  const char* app_name = ctl_msg->msg.wkr.app_name.str;
  wr_app_t* app = wr_app_exist(server, app_name);
  
  if(app == NULL){
    return -1;
  }
  
  if(app->state == WR_APP_RESTART){    
    app->state = WR_APP_ACTIVE;
    wr_application_list_free(app->conf->new);
    app->conf->new = NULL;
    // Send error response
    wr_app_add_error_msg(app);
  }else if(app->state == WR_APP_NEW){
    // Send error response
    wr_app_add_error_msg(app);
    wr_app_remove(app->svr, app->conf->name.str);
  }else{
    wr_pending_wkr_t *pending = wr_pending_worker_exist(app, atoi(ctl_msg->msg.wkr.pid.str));
    if(pending != NULL)     free(pending);
    app->timeout_counter = 0;
      
    if(WR_QUEUE_SIZE(app->q_pending_workers) <= 0 && Config->Server.Worker.add_timeout > 0)
      ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add_timeout);
  }
  return 0;
}

/** Add newly created worker to application */
int wr_app_wkr_insert(wr_svr_t *server, wr_wkr_t *worker,const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  const char* app_name = ctl_msg->msg.wkr.app_name.str;
  wr_app_t* app = wr_app_exist(server, app_name);
  
  if(app == NULL){
    LOG_ERROR(SEVERE, "Either queue is full or Baseuri is not matched");
    scgi_body_add(worker->ctl->scgi, "Either queue is full or Baseuri is not matched.",
                  strlen("Either queue is full or Baseuri is not matched."));
    return -1;
  }

  LOG_DEBUG(DEBUG,"app->a_config->max_worker = %d, app->q_workers->q_count =%d", app->conf->max_worker, WR_QUEUE_SIZE(app->q_workers));
  LOG_DEBUG(DEBUG, "Application name = %s, Application->config->name =%s", app_name, app->conf->name.str );
  
  if(app->conf->max_worker > WR_QUEUE_SIZE(app->q_workers) || app->state == WR_APP_RESTART) {
    wr_pending_wkr_t *pending = wr_pending_worker_exist(app, worker->pid);
    
    if(pending == NULL){
      scgi_body_add(worker->ctl->scgi, "Either worker add timeout or worker PID does not match.",
                    strlen("Either worker add timeout or worker PID does not match."));
      return -1;      
    }else{
      free(pending);
    }

    worker->id = ++worker_count;
    worker->app = app;
    
    app->timeout_counter = 0;
      
    if(WR_QUEUE_SIZE(app->q_pending_workers) <= 0 && Config->Server.Worker.add_timeout > 0)
      ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add_timeout);

    if(app->state == WR_APP_RESTART){
      if(wr_app_reload(app) == FALSE) return -1;
      if(app->ctl) {
        LOG_DEBUG(DEBUG,"Send OK status");
        scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
        wr_ctl_resp_write(app->ctl);
        app->ctl = NULL;
      }
      return 0;
    }
    
    if(app->state == WR_APP_NEW){
      if(app->ctl) {
        LOG_DEBUG(DEBUG,"Send OK status");
        scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
        wr_ctl_resp_write(app->ctl);
        app->ctl = NULL;
      }
      
      app->state = WR_APP_ACTIVE;
    }
    return 0;
  }
  
  return -1;
}

/** Check load balance to add the worker */
void wr_app_chk_load_to_add_wkr(wr_app_t *app) {
  if(TOTAL_WORKER_COUNT(app) < app->conf->max_worker) {
    if(app->q_messages->q_count > app->high_ratio) {
      if(!ev_is_active(&app->t_add)) {
        LOG_DEBUG(DEBUG,"%s() Timer set", __FUNCTION__);
        ev_timer_again(app->svr->ebb_svr.loop, &app->t_add);
      }
    } else if(ev_is_active(&app->t_add)) {
      LOG_DEBUG(DEBUG,"%s() Timer stop", __FUNCTION__);
      ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add);
    }
  }
}

/** Check load balance to remove the worker */
void wr_app_chk_load_to_remove_wkr(wr_app_t *app) {
  //Check load
  if(WR_QUEUE_SIZE(app->q_workers) > app->conf->min_worker) {
    if(app->q_messages->q_count < app->low_ratio) {
      if(!ev_is_active(&app->t_remove)) {
        LOG_DEBUG(DEBUG,"%s() Timer set", __FUNCTION__);
        ev_timer_again(app->svr->ebb_svr.loop, &app->t_remove);
      }
    } else if(ev_is_active(&app->t_remove)) {
      LOG_DEBUG(DEBUG,"%s() Timer stop", __FUNCTION__);
      ev_timer_stop(app->svr->ebb_svr.loop, &app->t_remove);
    }
  }
}

/** Initialize the applications */
void wr_app_init(wr_svr_t *server) {
  LOG_FUNCTION
  config_application_list_t *app = Config->Application.list;

  while(app) {
    wr_app_insert(server, app, NULL);
    app = app->next;
  }
}

/** Apllication add callback */
/* Deploy an application on the server */
void wr_app_add_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION

  wr_svr_t* server = ctl->svr;
  config_application_list_t* app_conf = NULL;
  wr_app_t* app = wr_app_exist(server, ctl_msg->msg.app.app_name.str);
  
  // Reset the error message
  ctl->svr->err_msg[0] = 0;
  if(app){
     /* set application object in control, it would be used at time of freeing control object */
     ctl->app = app;
     sprintf(ctl->svr->err_msg, "Application '%s' is already running.", ctl_msg->msg.app.app_name.str); 
  }else if(ctl && server) {
    app_conf = wr_conf_app_read(ctl_msg->msg.app.app_name.str,
                           ctl->svr->err_msg, FALSE);
    if(app_conf!=NULL) {
      if(wr_app_insert(ctl->svr, app_conf, ctl) == TRUE)        return;
    } else if(ctl->svr->err_msg[0] == 0) {
      sprintf(ctl->svr->err_msg, "Application '%s' is not found.", ctl_msg->msg.app.app_name.str);
    }
  }

  scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  scgi_body_add(ctl->scgi, ctl->svr->err_msg, strlen(ctl->svr->err_msg));
  wr_ctl_resp_write(ctl);
}

/** Allication remove callback */
void wr_app_remove_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  if(wr_app_remove(ctl->svr, ctl_msg->msg.app.app_name.str) >=0) {
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
  } else {
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    scgi_body_add(ctl->scgi, ctl->svr->err_msg, strlen(ctl->svr->err_msg));
  }
  wr_ctl_resp_write(ctl);
}

/** Allication reload callback */
void wr_app_reload_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg){
  LOG_FUNCTION
  wr_app_t *app = wr_app_exist(ctl->svr, ctl_msg->msg.app.app_name.str);

  if(app){
    
    LOG_INFO("Reload the application %s", ctl_msg->msg.app.app_name.str);
    // Read new application configuration.
    // Report error on not getting the application configuration.
    if(wr_conf_app_read(ctl_msg->msg.app.app_name.str, ctl->svr->err_msg, TRUE) == NULL){
      LOG_ERROR(WARN, "Error: %s",ctl->svr->err_msg);
      scgi_body_add(ctl->scgi, ctl->svr->err_msg, strlen(ctl->svr->err_msg));
      scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
      wr_ctl_resp_write(ctl);
      return;
    }
    
    app->state = WR_APP_RESTART;
    app->timeout_counter = 0;
    while(WR_QUEUE_SIZE(app->q_pending_workers) > 0){
      wr_pending_wkr_t* pending = wr_queue_fetch(app->q_pending_workers);
      free(pending);
    }

    app->ctl = ctl;
    LOG_DEBUG(4,"%s() Application Added:%s", __FUNCTION__, app->conf->new->name.str);
    
    // Add single worker with updated application.
    LOG_DEBUG(DEBUG, "Add first worker on application restart.");
    wr_app_wkr_add(app);   
    return;
  }else{
    // If application didn't found, report an error and create new application.
    LOG_ERROR(WARN,"Aapplication %s didn't found in list", ctl_msg->msg.app.app_name.str);
    sprintf(ctl->svr->err_msg, "Application '%s' is not found.", ctl_msg->msg.app.app_name.str);
    scgi_body_add(ctl->scgi, "Couldn't remove application. But trying to start application.",
                  strlen("Couldn't remove application. But trying to start application."));

    config_application_list_t *app_config = wr_conf_app_read(ctl_msg->msg.app.app_name.str, ctl->svr->err_msg, FALSE);
    if(app_config){
      if(wr_app_insert(ctl->svr, app_config, ctl) == TRUE)     return;
    }else{
      LOG_ERROR(WARN, "Error: %s",ctl->svr->err_msg);
      scgi_body_add(ctl->scgi, ctl->svr->err_msg, strlen(ctl->svr->err_msg));
    }
  }

  // Return ERROR status.
  scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  wr_ctl_resp_write(ctl);
}

/** Application configuration requset */
void wr_app_conf_req_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg){
  config_application_list_t* app_conf = NULL;
  wr_app_t* app = wr_app_exist(ctl->svr, ctl_msg->msg.app.app_name.str);

  if(app && app->conf->scgi){
    scgi_build(ctl->scgi);
    scgi_free(ctl->scgi);
    ctl->destroy_scgi = FALSE;
    if(app->state == WR_APP_RESTART){
      ctl->scgi = app->conf->new->scgi;
    }else{ 
      ctl->scgi = app->conf->scgi;
    }
  }else{
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  }
  wr_ctl_resp_write(ctl);
}
