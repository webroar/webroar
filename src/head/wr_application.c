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

/************** Private Functions ******************/

static inline int wr_app_fetch_wkr_pid(wr_app_t *app) {
  int pid = app->last_wkr_pid[0], i;

  for(i = 0 ; i < (app->pending_wkr-1) ; i ++) {
    app->last_wkr_pid[i] = app->last_wkr_pid[i+1];
  }
  app->last_wkr_pid[i] = 0;

  return pid;
}

/** Callback function to add worker to application */
void wr_app_wrk_add_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;
  ev_timer_stop(loop, &app->t_add);

  //do we need high load ratio check?
  if(TOTAL_WORKER_COUNT(app) < app->conf->max_worker) {
    wr_app_wkr_add(app);
  }
}

/** Callback function to add worker timeout */
void wr_app_wrk_add_timeout_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;
  char err_msg[512];
  int err_msg_len = 0;
  
  // Stop add timeout timer
  ev_timer_stop(loop, &app->t_add_timeout);

  // Decreament active worker count
  if(app->pending_wkr > 0) {
    // Kill worker
    int pid = wr_app_fetch_wkr_pid(app);
    LOG_INFO("wr_app_wrk_add_timeout_cb: killing worker, pid = %d", pid);
    if(pid > 0)
      kill(pid ,SIGKILL);
    LOG_DEBUG(DEBUG,"app->pending_wkr = %d", app->pending_wkr);
    app->pending_wkr --;
    if(app->pending_wkr > 0) {
      ev_timer_again(loop, &app->t_add_timeout);
    }

    // Update high load ratio
    app->high_ratio = TOTAL_WORKER_COUNT(app) * WR_MAX_REQ_RATIO;
  }

  //TODO: Check minimum no. of workers and, create worker if needed.
  // Also, do not OK if some worker were failed to connect.
  // For timebeing sending OK even if some worker failed to connect.
  if(app->in_use == FALSE && app->ctl && app->pending_wkr == 0) {
    LOG_DEBUG(DEBUG,"Some problem occurred while starting Application %s.", app->conf->name.str);
    scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    err_msg_len = sprintf(err_msg,"The application could not be started due to an error. Please refer '/var/log/webroar/%s.log' and the application log file for details.", app->conf->name.str); 
    scgi_body_add(app->ctl->scgi, err_msg, err_msg_len);
    wr_ctl_resp_write(app->ctl);
    app->ctl = NULL;
    if(app->restarted == TRUE){
      app->old_workers = 0;
      app->add_workers = 0;
      app->restarted = FALSE;
    }
  } else if(app->in_use == TRUE && (TOTAL_WORKER_COUNT(app) < app->conf->min_worker || app->add_workers)) {
    wr_app_wkr_add(app);
  }
}

/** Callback function to remove worker from application */
void wr_app_wrk_remove_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_app_t* app = (wr_app_t*) w->data;

  ev_timer_stop(loop, &app->t_remove);

  // Following variable helps in removing unncecessary call to wr_app_wrk_remove_cb
  int forecasted_count=app->wkr_que->q_count;
  // Its a known bug - At any time app->active_worker should equals to app->wkr_que->q_count
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
  LOG_DEBUG(DEBUG,"Pending_wkr = %d, app->wkr_que->q_count = %d",
            app->pending_wkr, app->wkr_que->q_count);
  if(app->wkr_que->q_count > app->conf->min_worker) {
    char cmd[WR_LONG_LONG_STR_LEN];
    char pid_list[WR_LONG_LONG_STR_LEN], pid_c[WR_SHORT_STR_LEN];
    int i,index;
    i = 0;
    index = (app->wkr_que->q_front + i) % app->wkr_que->q_max_size;
    wr_wkr_t *tmp_worker = (wr_wkr_t*)app->wkr_que->q_elements[index];
    
    
    // Get pid of the worker consuming more resident memory
#ifdef __APPLE__
    //sprintf(cmd,"ps -o pid -m -p %s | head -n2 | tail -n1 | cut -c-6 > %s",pid_list, WR_HIGH_RSS_PID_FILE);
	/* TODO: when any shell command is executed using system(), process goes into wait state. It is 
	 observed on only Mac. When tried calling syste() at various interval like after port binding,
	 controller initialization, forking required worker, daemonizing, activating event loop etc, in all 
	 cases it was working fine. But after dynamically created worker added into service, call to system()
	 goes into infinite wait.	   
	 In this case we would simply pick the first worker from queue and remove it.
	 */
    FILE *wfp = fopen(WR_HIGH_RSS_PID_FILE, "w");
    if(wfp) {
      fprintf(wfp,"%d", tmp_worker->pid); 
      fclose(wfp);
	}
#else
    sprintf(pid_c,"%d",tmp_worker->pid);
    strcpy(pid_list, pid_c);
    i++;
    for(;i < app->wkr_que->q_count ; i++) {
      index = (app->wkr_que->q_front + i) % app->wkr_que->q_max_size;
      tmp_worker = (wr_wkr_t*)app->wkr_que->q_elements[index];
      sprintf(pid_c,",%d", tmp_worker->pid);
      strcat(pid_list, pid_c);
    }
    sprintf(cmd,"ps -o pid --sort=rss -p %s | tail -n1 | cut -c-6 > %s",pid_list, WR_HIGH_RSS_PID_FILE);
    LOG_DEBUG(DEBUG,"Formed command to remove worker is %s",cmd);
    system(cmd);
#endif
	
    // Read pid from file
    FILE *fp = fopen(WR_HIGH_RSS_PID_FILE, "r");
    if(fp) {
      unsigned pid = 0;
      fscanf(fp, "%u", &pid);
      fclose(fp);
      remove(WR_HIGH_RSS_PID_FILE);
      int flag = 1;

      // Check for worker in list of free workers. If found remove it.
      if(app->free_wkr_que->q_count > 0) {
        LOG_DEBUG(DEBUG,", pid = %d find in free worker", pid);
        //int i, index;
        for( i = 0; i < app->free_wkr_que->q_count ; i++) {
          index = (app->free_wkr_que->q_front + i) % app->free_wkr_que->q_max_size;
          tmp_worker = (wr_wkr_t*)app->free_wkr_que->q_elements[index];
          if(tmp_worker->pid == pid) {
            LOG_DEBUG(DEBUG,"Removing from free worker id=%d", tmp_worker->id);
            forecasted_count--;
            wr_wkr_remove(tmp_worker, 1);
            LOG_DEBUG(DEBUG,"Worker removed from free worker.");
            flag = 0;
            break;
          }
        }
      }

      // Check for worker in the list of all the worker. If found mark it as in-active.
      // In-active worker will be removed once current request is processed.
      if(flag && app->wkr_que->q_count > 0) {
        LOG_DEBUG(DEBUG,"pid = %d find in active worker", pid);
        //int i, index;
        for( i = 0; i < app->wkr_que->q_count ; i++) {
          index = (app->wkr_que->q_front + i) % app->wkr_que->q_max_size;
          tmp_worker = (wr_wkr_t*)app->wkr_que->q_elements[index];
          if(tmp_worker->pid == pid) {
            forecasted_count--;
            LOG_DEBUG(DEBUG,"Remove active status id = %d", tmp_worker->id);
            if(tmp_worker->state & WR_WKR_ACTIVE)
              tmp_worker->state -= WR_WKR_ACTIVE;
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
static inline int wr_app_reload(wr_app_t *app){
  LOG_FUNCTION
  wr_wkr_t *worker;
  wr_app_conf_t *app_conf;
  short count;

  app->restarted = FALSE;
  // Remove an old application from the resolver list.
  wr_req_resolver_remove(app->svr, app);

  // Update the application configuration.
  app_conf = wr_conf_app_update(app->svr->conf,
                   app->conf->name.str,
                   app->svr->err_msg);
  if(app_conf == NULL){
    LOG_DEBUG(WARN, "Error: %s",app->svr->err_msg);
    scgi_body_add(app->ctl->scgi, app->svr->err_msg, strlen(app->svr->err_msg));
    scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    wr_ctl_resp_write(app->ctl);
    return -1;
  }

  // Remove old application specification.
  app->conf->next = NULL;
  wr_conf_app_free(app->conf);
  app->conf = app_conf;

  // Add the updated application to resolver list.
  wr_req_resolver_add(app->svr, app, app_conf);

  // Remove workers based on following logic:
  // If all the workers are free keep a single worker to process the requests and remove all others.
  // Else remove all the free workers.
  count = (app->free_wkr_que->q_count == app->wkr_que->q_count ? 1 :0 );

  LOG_DEBUG(DEBUG,"Free workers queue count is %d. Active worker count is %d.", WR_QUEUE_SIZE(app->free_wkr_que), WR_QUEUE_SIZE(app->wkr_que));
  LOG_DEBUG(DEBUG,"The %d worker(s) to be removed from free workers list.", WR_QUEUE_SIZE(app->free_wkr_que) - count);
  while(WR_QUEUE_SIZE(app->free_wkr_que) > count){
    worker = (wr_wkr_t*)wr_queue_fetch(app->free_wkr_que);
    // The worker is already removed from free workers list so do not pass the flag.
    wr_wkr_remove(worker, 0);
  }

  // Set the number of workers to be removed.
  app->old_workers = WR_QUEUE_SIZE(app->wkr_que);
  // Set the number of workers to be added.
  app->add_workers = app->conf->min_worker;
  // Mark all existing workers to OLD worker.
  for(count = 0; count < app->old_workers ; count++){
    worker = (wr_wkr_t*)wr_queue_fetch(app->wkr_que);
    wr_queue_insert(app->wkr_que, worker);
    worker->state |= WR_WKR_OLD;
  } 

  LOG_DEBUG(DEBUG,"Number of old and add workers are %d and %d respectively", app->old_workers, app->add_workers);

  // Create queue with higher capacity to accomodate extra worker(which would remain during transient period of application reload) if required.
  //TODO: If max_worker < WR_QUEUE_MAX_SIZE(app->wkr_que) and queue is full, need to create new queue 
  if(app->conf->max_worker >= WR_QUEUE_MAX_SIZE(app->wkr_que)){
    void *element;
    LOG_DEBUG(DEBUG,"Create a worker queue with size %d", app->conf->max_worker + 1);
    wr_queue_t *queue = wr_queue_new(app->conf->max_worker + 1);

    // Create new worker queue.
    while(element = wr_queue_fetch(app->wkr_que)){
      wr_queue_insert(queue, element);
    }
    wr_queue_free(app->wkr_que);
    app->wkr_que = queue;

    // Create new free worker queue.
    queue = wr_queue_new(app->conf->max_worker + 1);
    while(element = wr_queue_fetch(app->free_wkr_que)){
      wr_queue_insert(queue, element);
    }
    wr_queue_free(app->free_wkr_que);
    app->free_wkr_que = queue;
  }
  return 0;
}

/*************** Application function definition *********/

/** Destroy application */
void wr_app_free(wr_app_t* app) {
  LOG_FUNCTION
  wr_app_t* tmp_app;
  wr_wkr_t* worker;

  //wr_application_print(app);

  while(app) {
    tmp_app = app->next;
    app->in_use = FALSE;
    LOG_DEBUG(4,"Destroying application %s...", app->conf->name.str);
    LOG_DEBUG(DEBUG,"Worker count = %d", WR_QUEUE_SIZE(app->wkr_que));
    //Destroy workers
    while(worker = (wr_wkr_t*)wr_queue_fetch(app->wkr_que)) {
      if(app->svr->is_running==0)
        worker->state |= WR_WKR_HANG;
      wr_wkr_free(worker);
    }

    wr_queue_free(app->free_wkr_que);
    wr_queue_free(app->wkr_que);

    wr_req_t *req;
    WR_QUEUE_FETCH(app->msg_que, req)  ;
    while(req) {
      wr_conn_err_resp(req->conn, WR_HTTP_STATUS_500);
      WR_QUEUE_FETCH(app->msg_que, req)  ;
    }

    wr_queue_free(app->msg_que);

    wr_req_resolver_remove(app->svr, app);

    ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add);
    ev_timer_stop(app->svr->ebb_svr.loop, &app->t_remove);
    ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add_timeout);

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

/** Create worker for application */
int wr_app_wkr_add(wr_app_t *app) {
  if(app->pending_wkr < WR_MAX_PENDING_WKR) {
    int retval = wr_wkr_create(app->svr, app->conf);
    if(retval > 0){
      app->pending_wkr++;
      app->high_ratio = TOTAL_WORKER_COUNT(app) * WR_MAX_REQ_RATIO;
      app->last_wkr_pid[app->pending_wkr-1] = retval;
      ev_timer_again(app->svr->ebb_svr.loop, &app->t_add_timeout);
      LOG_INFO("PID of created worker = %d, Rails application=%s",
             app->last_wkr_pid[app->pending_wkr-1],app->conf->path.str);
      return 0;
    }else{
      LOG_ERROR(SEVERE,"Could not fork process to start new worker.");
    }
  }
  return -1;
}

/** Insert application based on application configuration */
static int wr_app_insert(wr_svr_t* server, wr_app_conf_t* config, wr_ctl_t *ctl) {
  LOG_FUNCTION
  wr_app_t* app = wr_malloc(wr_app_t);
  short is_static_server = 0;

  if(!app) {
    LOG_ERROR(WARN, "%s() application object allocation failed. Returning ...", __FUNCTION__);
    return -1;
  }

  if(strcmp(config->name.str, WR_STATIC_FILE_SERVER_NAME) == 0){
    is_static_server = 1;
  }
  
  app->free_wkr_que = wr_queue_new(config->max_worker);
  app->wkr_que = wr_queue_new(config->max_worker);
  app->msg_que = wr_queue_new(WR_MSG_QUE_SIZE);

  if(  app->wkr_que == NULL ||
       app->free_wkr_que == NULL ||
       app->msg_que == NULL) {
    free(app);
    app = NULL;
    LOG_ERROR(WARN, "application object initialization failed. Returning ...");
    return -1;
  }
  app->svr = server;
  app->conf = config;
  app->ctl = ctl;
  if(!is_static_server){
    wr_req_resolver_add(server, app, config);
    app->next = server->apps;
    server->apps = app;
  }else{
    app->next = NULL;
    server->static_app = app;
  }

  app->t_add.data = app->t_remove.data = app->t_add_timeout.data = app;

  ev_timer_init (&app->t_add, wr_app_wrk_add_cb, 0., WR_HIGH_LOAD_LIMIT);
  ev_timer_init (&app->t_remove, wr_app_wrk_remove_cb, 0., WR_LOW_LOAD_LIMIT);
  ev_timer_init (&app->t_add_timeout, wr_app_wrk_add_timeout_cb, 0., WR_WKR_ADD_TIMEOUT);

  //app->next = server->apps;
  //server->apps = app;
  LOG_DEBUG(4,"%s() Application Added:%s", __FUNCTION__, config->name.str);

  app->pending_wkr = 0;
  app->in_use = FALSE;
  app->restarted = FALSE;
  app->old_workers = 0;
  app->add_workers = 0;

  int i;
  for(i = 0; i < WR_MAX_PENDING_WKR ; i ++) {
    app->last_wkr_pid[i] = 0;
  }

  /** Creating workers */
  for(i=0; i < config->min_worker;  i++) {
    //Create a new Worker
    wr_app_wkr_add(app);
    //      int pid = wr_wkr_create(server, config);
    //      LOG_DEBUG(DEBUG,"Rails application=%s", config->path.str);
    //      LOG_DEBUG(4,"PID of created process is %i",pid);
  }

  //app->high_ratio = TOTAL_WORKER_COUNT(app) * WR_MAX_REQ_RATIO;
  app->low_ratio = TOTAL_WORKER_COUNT(app) * WR_MIN_REQ_RATIO;
  return 0;
}

/** Worker added to application callback */
void wr_app_wkr_added_cb(wr_app_t *app){
  LOG_FUNCTION
  wr_wkr_t *worker;

  // Decrease the add workers count.
  if(app->add_workers){
    LOG_DEBUG(DEBUG, "Number of add workers is %d.", app->add_workers);
    app->add_workers --;
  }

  // Add a worker if required.
  if(app->add_workers){
    LOG_DEBUG(DEBUG,"Add a worker to a reloaded application.");
    wr_app_wkr_add(app);
  }else{
    if(app->old_workers){
      short count, i;
      // Remove all the old workers, if there is no more workers to add.
      LOG_DEBUG(DEBUG, "Number of old workers is %d.", app->old_workers);
      count = WR_QUEUE_SIZE(app->wkr_que);
      for( i = 0 ; i < count ; i ++){
        worker = (wr_wkr_t*) wr_queue_fetch(app->wkr_que);
        wr_queue_insert(app->wkr_que, worker);
        if(worker->state & WR_WKR_OLD){
          // Pass flag to remove worker from the worker free list.
          wr_wkr_remove(worker, 1);
          app->old_workers --;
        }
      }
      app->old_workers = 0;
    }

    // Add worker if total number of worker is less than minimum number of workes.
    if(TOTAL_WORKER_COUNT(app) < app->conf->min_worker){
      LOG_DEBUG(DEBUG, "Application does not have minimum number of workes.");
      wr_app_wkr_add(app);
    }
    return;
  }

  // Remove old worker.
  if(app->old_workers){
    short count, i;
    LOG_DEBUG(DEBUG, "Number of old workers is %d.", app->old_workers);
    count = WR_QUEUE_SIZE(app->wkr_que);
    for( i = 0 ; i < count ; i ++){
      worker = (wr_wkr_t*) wr_queue_fetch(app->wkr_que);
      wr_queue_insert(app->wkr_que, worker);
      LOG_DEBUG(DEBUG,"Worker PID is %d and state is %d.", worker->pid, worker->state);
      if(worker->state & WR_WKR_OLD){
        // Pass flag to remove worker from the worker free list.
        wr_wkr_remove(worker, 1);
        app->old_workers --;
        break;
      }
    }
  }
}

/** Add newly created worker to application */
int wr_app_wrk_insert(wr_svr_t *server, wr_wkr_t *worker,const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  wr_app_t* app = server->apps;
  const char* app_name = ctl_msg->msg.wkr.app_name.str;
  
  if(strcmp(app_name, WR_STATIC_FILE_SERVER_NAME) == 0){
    app = server->static_app;
  }

  while(app) {
    LOG_DEBUG(DEBUG,"app->a_config->max_worker = %d, app->wkr_que->q_count =%d", app->conf->max_worker, WR_QUEUE_SIZE(app->wkr_que));
    LOG_DEBUG(DEBUG, "Application name = %s, Application->config->name =%s", app_name, app->conf->name.str );
    if((app->conf->max_worker > WR_QUEUE_SIZE(app->wkr_que) || app->restarted == TRUE || app->add_workers > 0)
        && strcmp(app_name, app->conf->name.str) == 0) {
      int i;
      for(i = 0; i < app->pending_wkr ; i++) {
        if(app->last_wkr_pid[i] == worker->pid)
          break;
      }

      if(i == app->pending_wkr) {
        scgi_body_add(worker->ctl->scgi, "Either worker add timeout or worker PID does not match.",
                              strlen("Either worker add timeout or worker PID does not match."));
        return -1;
      }

      for(; i < app->pending_wkr ; i++) {
        app->last_wkr_pid[i] = app->last_wkr_pid[i+1];
      }
      app->last_wkr_pid[i] = 0;
      app->pending_wkr --;


      worker->id = ++worker_count;
      worker->app = app;
      
      if(app->pending_wkr <= 0)
        ev_timer_stop(app->svr->ebb_svr.loop, &app->t_add_timeout);
      if(!(worker->state& WR_WKR_ACTIVE))
        worker->state += WR_WKR_ACTIVE;

      if(app->in_use == FALSE) {
        app->in_use = TRUE;
        if(app->ctl) {
          LOG_DEBUG(DEBUG,"Send OK status");
          scgi_header_add(app->ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
          wr_ctl_resp_write(app->ctl);
          app->ctl = NULL;
        }
      }

      if(app->restarted == TRUE){
        return wr_app_reload(app);
      }

      return 0;
    }
    app = app->next;
  }
  LOG_ERROR(SEVERE, "Either queue is full or Baseuri is not matched");
  scgi_body_add(worker->ctl->scgi, "Either queue is full or Baseuri is not matched.",
                        strlen("Either queue is full or Baseuri is not matched."));
  return -1;
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
    wr_app_conf_remove(server->conf, app_name);
    return 0;
  } else {
    LOG_ERROR(WARN,"Aapplication %s didn't found in list", app_name);
    sprintf(server->err_msg, "Application '%s' is not found.", app_name);
    return -1;
  }
}

/** Check load balance to add the worker */
void wr_app_chk_load_to_add_wkr(wr_app_t *app) {
  if(TOTAL_WORKER_COUNT(app) < app->conf->max_worker) {
    if(app->msg_que->q_count > app->high_ratio) {
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
  if(WR_QUEUE_SIZE(app->wkr_que) > app->conf->min_worker) {
    if(app->msg_que->q_count < app->low_ratio) {
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
  wr_app_conf_t *app = server->conf->apps;

  while(app) {
    wr_app_insert(server, app, NULL);
    app = app->next;
  }
}

/** Allication add callback */
void wr_app_add_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION

  wr_svr_t* server = ctl->svr;
  wr_app_conf_t* app_conf = NULL;
  wr_app_t* app = server->apps, *tmp_app = NULL;
    
  while(app) {
    if(strcmp(ctl_msg->msg.app.app_name.str, app->conf->name.str)==0)
      break;
    tmp_app = app;
    app = app->next;
  }
  ctl->svr->err_msg[0] = 0;
  if(app) {
    sprintf(ctl->svr->err_msg, "Appliation '%s' is already running.", ctl_msg->msg.app.app_name.str);
  }
  
  if(!app && ctl && ctl->svr && ctl->svr->conf) {
    app_conf = wr_conf_app_read(ctl->svr->conf,
                           ctl_msg->msg.app.app_name.str,
                           ctl->svr->err_msg);
    if(app_conf!=NULL) {
      if(wr_app_insert(ctl->svr, app_conf, ctl) >= 0)
        return;
    } else if(ctl->svr->err_msg[0] == 0) {
      sprintf(ctl->svr->err_msg, "Appliation '%s' is not found.", ctl_msg->msg.app.app_name.str);
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
void wr_app_reload_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  wr_app_t *app = ctl->svr->apps;
  wr_app_conf_t* app_config = NULL;

  // Find the application.
  while(app) {
    if(strcmp(ctl_msg->msg.app.app_name.str, app->conf->name.str)==0)
      break;
    app = app->next;
  }

  // Read new application configuration.
  app_config = wr_conf_app_update(ctl->svr->conf,
                         ctl_msg->msg.app.app_name.str,
                         ctl->svr->err_msg);
  // Report error on not getting the application configuration.
  if(app_config == NULL){
    LOG_ERROR(WARN, "Error: %s",ctl->svr->err_msg);
    scgi_body_add(ctl->scgi, ctl->svr->err_msg, strlen(ctl->svr->err_msg));
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
    wr_ctl_resp_write(ctl);
    // Add old application configuration to server configuration.
    if(app){
      LOG_DEBUG(WARN,"Replace the application configuration with old one.");
      wr_conf_app_replace(app->svr->conf, app->conf);
    }
    return;
  }

  if(app) {
    int i;
    wr_app_conf_t *tmp_app_conf = app->conf;
    // Set variables to restart the application.
    LOG_DEBUG(DEBUG,"Set variables to restart an existing application.");
    app->conf = app_config;
    app->in_use = FALSE;
    app->restarted = TRUE;
    app->pending_wkr = 0;
    for(i = 0; i < WR_MAX_PENDING_WKR ; i ++) {
      app->last_wkr_pid[i] = 0;
    }
    app->ctl = ctl;
    LOG_DEBUG(4,"%s() Application Added:%s", __FUNCTION__, app->conf->name.str);

    // Add single worker with updated application.
    LOG_DEBUG(DEBUG, "Add first worker on application restart.");
    wr_app_wkr_add(app);

    // Replace the application configuration with older configuration object.
    wr_conf_app_replace(app->svr->conf, tmp_app_conf);
    app->conf = tmp_app_conf;
    return;
  }else{
    // If application didn't found, report an error and create new application.
    LOG_ERROR(WARN,"Aapplication %s didn't found in list", ctl_msg->msg.app.app_name.str);
    sprintf(ctl->svr->err_msg, "Application '%s' is not found.", ctl_msg->msg.app.app_name.str);
    scgi_body_add(ctl->scgi,
                          "Couldn't remove application. But trying to start appliaction.",
                          strlen("Couldn't remove application. But trying to start appliaction."));
    if(wr_app_insert(ctl->svr, app_config, ctl) == 0)
      return;
  }

  // Return ERROR status.
  scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  wr_ctl_resp_write(ctl);
}
