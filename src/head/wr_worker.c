
#include "wr_worker.h"

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
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/un.h>

extern config_t *Config;

/** Private functions */
static void wr_req_hearer_write_cb(struct ev_loop*, struct ev_io*, int);
static void wr_wrk_allocate(wr_wkr_t* worker);
static void wr_wkr_ping_send(wr_wkr_t *worker);

static void wr_wkr_state_machine(wr_wkr_t *worker, wr_wkr_action_t action){

 switch(action){
    case WKR_ACTION_ERROR:
    case WKR_ACTION_REMOVE:
      worker->state = WKR_STATE_ERROR;
      wr_wkr_free(worker);
      return;
  }

  switch(worker->state){
    // Connecting
    case WKR_STATE_CONNECTING:
      switch(action){
        case WKR_ACTION_ADD:
          worker->state = WKR_STATE_INACTIVE;
          return;
      }
      break;

    // Active
    case WKR_STATE_ACTIVE:
      switch(action){
        case WKR_ACTION_REQ_PROCESSED:
          worker->state = WKR_STATE_INACTIVE;
          wr_wrk_allocate(worker);
          return;
        case WKR_ACTION_PING_TIMEOUT:
          if(worker->trials_done < Config->Server.Worker.ping_trials) {
            worker->state = WKR_STATE_PINGING;
            wr_wkr_ping_send(worker);
          } else {
            worker->state = WKR_STATE_HANGUP;
            wr_app_t *app = worker->app;
            wr_wkr_free(worker);
            wr_app_wkr_balance(app);
          }
          return;
      }
      break;

    // Inactive
    case WKR_STATE_INACTIVE:
      switch(action){
        case WKR_ACTION_REQ_PROCESSING:
          worker->state = WKR_STATE_ACTIVE;
          return;
      }
      break;

    // Pinging
    case WKR_STATE_PINGING:
      switch(action){
        case WKR_ACTION_REQ_PROCESSED:
          worker->state = WKR_STATE_INACTIVE;
          wr_wrk_allocate(worker);
          return;
        case WKR_ACTION_REQ_PROCESSING:
          worker->state = WKR_STATE_ACTIVE;
          return;
        case WKR_ACTION_PING_REPLAY:
          worker->state = WKR_STATE_ACTIVE;
          ev_timer_stop(worker->loop, &worker->t_wait);
          worker->t_wait.repeat = Config->Server.Worker.idle_time;
          ev_timer_again(worker->loop, &worker->t_wait);
          return;
        case WKR_ACTION_PING_TIMEOUT:
          if(worker->trials_done < Config->Server.Worker.ping_trials) {
            worker->state = WKR_STATE_PINGING;
            wr_wkr_ping_send(worker);
          } else {
            worker->state = WKR_STATE_HANGUP;
            wr_app_t *app = worker->app;
            wr_wkr_free(worker);
            wr_app_wkr_balance(app);
          }
          return;
      }
      break;

    // Expired
    case WKR_STATE_EXPIRED:
      switch(action){
        case WKR_ACTION_REQ_PROCESSED:
        case WKR_ACTION_PING_TIMEOUT:
          worker->state = WKR_STATE_DISCONNECTING;
          wr_wkr_free(worker);
          return;
      }
      break;

    // Acknowledge Error message
    case WKR_STATE_ERROR_ACK:
      break;
    
    case WKR_STATE_ERROR:           // Error
    case WKR_STATE_TIMEDOUT:        // Timedout
    case WKR_STATE_HANGUP:          // Hangup
    case WKR_STATE_DISCONNECTING:   // Disconnecting
      wr_wkr_free(worker);
      break;
  }
}

static void wr_wkr_ping_send(wr_wkr_t *worker){
  worker->trials_done++;
  LOG_INFO("Worker %d with pid %u ping for trial no %d",
            worker->id, worker->pid, worker->trials_done);
  worker->t_wait.repeat = Config->Server.Worker.ping_timeout;

  scgi_t *scgi = scgi_new();
  scgi_header_add(scgi, "COMPONENT", strlen("COMPONENT"), "WORKER", strlen("WORKER"));
  scgi_header_add(scgi, "METHOD", strlen("METHOD"), "PING", strlen("PING"));
  if(scgi_build(scgi)!=0) {
    LOG_ERROR(WARN,"SCGI request build failed.");
  }
  worker->ctl->scgi = scgi;
  ev_io_start(worker->loop, &worker->ctl->w_write);
  //ev_timer_again(loop, &worker->t_ping_wait);
  ev_timer_again(worker->loop, &worker->t_wait);
}

static inline void wr_wait_watcher_start(wr_wkr_t *worker) {
  wr_wkr_state_machine(worker, WKR_ACTION_REQ_PROCESSING);
  worker->trials_done = 0;
  // Clear WR_WKR_PING_SENT, WR_WKR_PING_REPLIED and WR_WKR_HANG state.
  worker->t_wait.repeat = Config->Server.Worker.idle_time;
  ev_timer_again(worker->loop, &worker->t_wait);
}

static void wr_wkr_req_processing(wr_wkr_t* worker, wr_req_t* req){
  LOG_DEBUG(4,"Allocate worker %d to req id %d", worker->id , req->id);
  req->wkr = worker;
  req->using_wkr = TRUE;

  worker->req = req;
  worker->watcher.data = req;

  wr_wkr_state_machine(worker, WKR_ACTION_REQ_PROCESSING);

  ev_io_init(&worker->watcher, wr_req_hearer_write_cb, worker->fd, EV_WRITE);
  ev_io_start(worker->loop,&worker->watcher);
}

/** Check for pending request to process */
static void wr_wrk_allocate(wr_wkr_t* worker) {
  LOG_FUNCTION
  wr_req_t* req;
  wr_app_t* app = worker->app;
  wr_svr_t* server = app->svr;
  int retval;

  //do we need high load ratio check here?
  if(worker->app){
    wr_app_chk_load_to_remove_wkr(worker->app);
  }

  if(app && app->q_messages->q_count > 0) {
    //There is pending request
    WR_QUEUE_FETCH(app->q_messages, req)  ;

    if(req == NULL) {
      WR_QUEUE_INSERT(app->q_free_workers, worker, retval)  ;
    } else {
      wr_wkr_req_processing(worker, req);
    }
  } else if(app) {
    //No any pending request. Add Worker to free worker list
    LOG_DEBUG(4,"Message queue is empty");
    WR_QUEUE_INSERT(app->q_free_workers, worker, retval)  ;
  } else {
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
  }
}

static void wr_wkr_req_processed(wr_wkr_t *worker){
  wr_req_free(worker->req);
  worker->req = NULL;
  LOG_DEBUG(DEBUG,"Idle watcher stopped for worker %d", worker->id);
  // worker is done with current Request
  ev_timer_stop(worker->loop,&worker->t_wait);
  wr_wkr_state_machine(worker, WKR_ACTION_REQ_PROCESSED);
}

/** Reads streamed response from Worker */
static void wr_resp_read_cb(struct ev_loop *loop,struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_req_t *req = (wr_req_t*) w->data;
  wr_wkr_t *worker = req->wkr;
  ssize_t read;

  LOG_DEBUG(DEBUG,"req %d",req->id);
  //TODO: what to do if there is some unread data for req, and it's get closed?
  if(!(revents & EV_READ))
    return;

  //TODO: can this thing can be improved by directly reading into response_buffer?
  // if we do so we have overhead of allocating and freeing response_buffer.

  read = recv(w->fd,
              req->resp_buf,
              wr_min(WR_RESP_BUF_SIZE,req->resp_buf_len - req->bytes_received),
              0);
  if(read <= 0) {
    LOG_ERROR(WARN,"Error reading response:%s",strerror(errno));
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
    return;
  }

  req->bytes_received += read;
  LOG_DEBUG(DEBUG,"Request %d, read %d/%d", req->id, req->bytes_received, req->resp_buf_len);

  //worker responding
  LOG_DEBUG(DEBUG,"Idle watcher reset for worker %d", worker->id);

  if(!req->conn_err) {
    wr_conn_resp_body_add(req->conn, req->resp_buf, read);
  }
  // Check response lenth
  //if(req->bytes_received == req->resp_buf_len) {
  if(req->bytes_received >= req->resp_buf_len) {
    ev_io_stop(loop, w);
    wr_wkr_req_processed(worker);
  } else {
    wr_wait_watcher_start(worker);
  }
}

static int wr_wkr_set_req(wr_wkr_t *worker, wr_req_t* req, scgi_t* scgi){
  const char *value = scgi_header_value_get(scgi, SCGI_CONTENT_LENGTH);
  
  // Set response length
  req->resp_buf_len = (value ? atoi(value) : 0);
  
  // Set rsponse code
  value = scgi_header_value_get(scgi, Config->Request.Header.resp_code.str);
  req->resp_code = (value ? atoi(value) : 0);
  
  // Set content length
  value = scgi_header_value_get(scgi, Config->Request.Header.resp_content_len.str);
  req->resp_body_len = (value ? atoi(value) : 0);

  LOG_DEBUG(DEBUG,"resp_code = %d, content len = %d, resp len = %d",
            req->resp_code,
            req->resp_body_len,
            req->resp_buf_len);
  // Response length should be greater than 0
  if(req->resp_buf_len == 0) {
    //TODO: Render 500 Internal Error, close Request, allocate worker to next Request
    LOG_ERROR(WARN,"Got response len 0");
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
    return FALSE;
  }

  if(!req->conn_err && req->app && Config->Server.flag & SERVER_ACCESS_LOG) {
    wr_access_log(req);
  }

  scgi_free(req->scgi);
  req->scgi = NULL;

  req->bytes_received = scgi->body_length;
  LOG_DEBUG(DEBUG,"wr_resp_len_read_cb() bytes read = %d", req->bytes_received);
  if(req->bytes_received > 0 && !req->conn_err) {
    wr_conn_resp_body_add(req->conn, scgi->body, scgi->body_length);
  }

  scgi_free(scgi);
  return TRUE;
}

/** Reads the response from worker, deserialize it, render it to the Request. */
static void wr_resp_len_read_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_req_t* req = (wr_req_t*) w->data;
  wr_wkr_t *worker = req->wkr;
  ssize_t read;

  LOG_DEBUG(DEBUG,"Request %d",req->id);

  if(!(revents & EV_READ))
    return;

  read = recv(w->fd,
              req->resp_buf + req->bytes_received,
              WR_RESP_BUF_SIZE - req->bytes_received,
              0);

  if(read <= 0) {
    ev_io_stop(loop,w);
    LOG_ERROR(WARN,"Error reading response:%s",strerror(errno));
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
    return;
  }

  req->bytes_received =+ read;
  //worker responding
  LOG_DEBUG(DEBUG,"Idle watcher reset for worker %d", worker->id);
  LOG_DEBUG(DEBUG,"bytes read = %d", req->bytes_received);

  scgi_t* scgi = scgi_parse(req->resp_buf, req->bytes_received);

  if(scgi == NULL) return;
  ev_io_stop(loop,w);

  if(wr_wkr_set_req(worker, req, scgi) == FALSE) return;
  
  // Check for response length
  if(req->resp_buf_len == req->bytes_received) {
    wr_wkr_req_processed(worker);
  } else {
    LOG_DEBUG(DEBUG,"wr_resp_len_read_cb() Request %d, read %d/%d",
              req->id,
              req->bytes_received,
              req->resp_buf_len);
    ev_io_init(w,wr_resp_read_cb, w->fd,EV_READ);
    ev_io_start(loop,w);
    wr_wait_watcher_start(worker);
  }
}

static void wr_wkr_req_sent(wr_wkr_t *worker){
  ev_io_stop(worker->loop, &worker->watcher);
  wr_req_t * req = worker->req;

  if(req->upload_file) {
    fclose(req->upload_file);
    remove(req->upload_file_name->str);
    wr_buffer_free(req->upload_file_name);
    req->upload_file = NULL;
  }

  scgi_free(req->scgi);
  req->scgi = NULL;

  ev_io_init(&worker->watcher, wr_resp_len_read_cb, worker->fd, EV_READ);
  ev_io_start(worker->loop,&worker->watcher);
  //We are waiting for response from worker, start idle watcher for it
  LOG_DEBUG(DEBUG,"Idle watcher started for worker %d", worker->id);
  wr_wait_watcher_start(worker);
}

/** Send SCGI formatted request stream to Worker*/
/* Send request body to worker */
static void wr_req_body_write_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_req_t *req = (wr_req_t*) w->data;
  wr_wkr_t *worker = req->wkr;
  ssize_t sent = 0;
  LOG_DEBUG(DEBUG, "Request %d",req->id);
  if(!(revents & EV_WRITE))
    return;

  if(req->upload_file) {
    char buffer[Config->Request.max_body_size];
    ssize_t read;
    int rv=fseek(req->upload_file,req->bytes_sent,SEEK_SET);
    if(rv<0) {
      LOG_ERROR(WARN,"Error reading file:%s",strerror(errno));
      return;
    }
    read = fread(buffer,1,Config->Request.max_body_size,req->upload_file);
    sent = send(w->fd, buffer, read, 0);
  }

  if(sent <= 0) {
    LOG_ERROR(WARN,"Error sending request:%s",strerror(errno));
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
    return;
  }

  req->bytes_sent += sent;
  LOG_DEBUG(DEBUG,"Request %d sent %d/%d",  req->id, req->bytes_sent, req->ebb_req->content_length);

  if(req->ebb_req->content_length == req->bytes_sent) {
    wr_wkr_req_sent(worker);
  }
}

/** Start writing SCGI formatted request to Worker */
/* Send request headers to worker */
//whenever there is a pending request for processing and worker's fd is ready for write, it will dump serialized data to worker by this function
static void wr_req_hearer_write_cb(struct ev_loop *loop, struct ev_io *w, int revents) {
  LOG_FUNCTION
  wr_req_t* req = (wr_req_t*) w->data;
  wr_wkr_t *worker = req->wkr;
  LOG_DEBUG(DEBUG,"Request %d",req->id);
  if (!(revents & EV_WRITE))
    return;

  //TODO: we can improve here by sending request body part also
  if(scgi_send(req->scgi, w->fd) <= 0){
    ev_io_stop(loop,w);
    LOG_ERROR(WARN,"Error sending request:%s",strerror(errno));
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
  }
  LOG_DEBUG(DEBUG,"Request %d write %d/%d", req->id,  req->scgi->bytes_sent, 
          req->scgi->length);
  if(req->scgi->bytes_sent == req->scgi->length) {
    
    LOG_DEBUG(DEBUG,"Sent request header for Request %d to worker %d", req->id, worker->id);
    req->bytes_sent = 0;

    if(req->upload_file) {
      ev_io_stop(loop,w);
      ev_io_init(w,wr_req_body_write_cb,w->fd,EV_WRITE);
      ev_io_start(loop,w);
    } else {
      wr_wkr_req_sent(worker);
    }
  }
}

/*******************************************
 *       Worker Function Definition          *
 *******************************************/

typedef struct {
  char uid[STR_SIZE32], gid[STR_SIZE32],
          log_level[STR_SIZE32], controller_path[STR_SIZE32];
  wr_str_t baseuri;
}wr_wkr_create_t;

static wr_wkr_create_t* wr_wkr_create_init(wr_svr_t *server, config_application_list_t *app_conf){
  wr_wkr_create_t *worker = wr_malloc(wr_wkr_create_t);

  wr_string_null(worker->baseuri);
  if(app_conf->baseuri.str) {
    wr_string_dump(worker->baseuri, app_conf->baseuri);
  } else {
    wr_string_new(worker->baseuri, "/", 1);
  }

  sprintf(worker->uid, "%d", app_conf->cuid);
  sprintf(worker->gid, "%d", app_conf->cgid);
  sprintf(worker->log_level, "%d", app_conf->log_level);

  if(Config->Server.flag & SERVER_UDS_SUPPORT) {
    strcpy(worker->controller_path, server->ctl->sock_path.str);
  } else {
    sprintf(worker->controller_path, "%d", server->ctl->port);
  }

  return worker;
}

/** Create the Worker */
/* Fork a new process and start worker in it. */
int wr_wkr_create(wr_svr_t *server, config_application_list_t *app_conf) {
  LOG_FUNCTION
  pid_t   pid;
  wr_wkr_create_t *worker = wr_wkr_create_init(server, app_conf);
  
  pid = fork();
  LOG_DEBUG(DEBUG,"Forked PID is  %i, uid = %s, gid =%s, app = %s",pid, worker->uid, worker->gid, app_conf->name.str) ;
  if (pid == 0) {
      LOG_DEBUG(3,"Child is continuing %i",pid);
      setsid();
      int i = 0;
      for (i = getdtablesize();i>=0;--i) {
        //LOG_DEBUG(DEBUG,"closing fd=%d",i);
        close(i); //why??
      }

      /* Close out the standard file descriptors*/

      close(STDIN_FILENO);
      close(STDOUT_FILENO);
      close(STDERR_FILENO);
      i=open("/dev/null",O_RDWR); // open stdin and connect to /dev/null
      int j = dup(i); // stdout
      j = dup(i); // stderr

      LOG_DEBUG(DEBUG,"Before execl():Rails application=%s, uid=%s, gid = %s",
              app_conf->path.str, worker->uid, worker->gid);
      LOG_DEBUG(DEBUG,"exe file = %s",Config->Server.File.worker_bin.str);
      int rv;
      rv=execl(Config->Server.File.worker_bin.str, Config->Server.File.worker_bin.str,
               "-a", app_conf->path.str,
               "-e", app_conf->env.str,
               "-u", worker->uid,
               "-g", worker->gid,
               "-c", worker->controller_path,
               "-i", (Config->Server.flag & SERVER_UDS_SUPPORT ? "y" : "n"),
               "-t", app_conf->type.str,
               "-n", app_conf->name.str,
               "-p", (app_conf->analytics? "y" : "n"),
               "-r", worker->baseuri.str,
               "-o", Config->Server.Dir.root.str,
               "-k", (Config->Server.flag & SERVER_KEEP_ALIVE ? "y" : "n"),
               "-l", worker->log_level,
               NULL);
      wr_string_free(worker->baseuri);
      free(worker);
      if(rv<0) {
        LOG_ERROR(5,"Unable to run %s: %s\n", Config->Server.File.worker_bin.str, strerror(errno));
        fprintf(stderr, "Unable to run %s: %s\n", Config->Server.File.worker_bin.str, strerror(errno));
        fflush(stderr);
        _exit(1);
      }
  } else if (pid == -1) {
    wr_string_free(worker->baseuri);
    free(worker);
    LOG_ERROR(5,"Cannot fork a new process %i", errno);
  } else {
    wr_string_free(worker->baseuri);
    free(worker);
    //Temporary Hack
    return pid;
  }
  return -1;
}


/** This would get called when idel time watcher goes timeout */
static void wr_wkr_wait_cb(struct ev_loop *loop, ev_timer *w, int revents) {
  LOG_FUNCTION
  wr_wkr_t *worker = (wr_wkr_t*)w->data;

  //ev_timer_stop(loop, &worker->t_idle);
  ev_timer_stop(loop, &worker->t_wait);

  if(worker->app == NULL) {
    LOG_INFO("wr_wkr_wait_cb: Worker removed with pid %d", worker->pid);
    wr_wkr_state_machine(worker, WKR_ACTION_ERROR);
  }else{
    wr_wkr_state_machine(worker, WKR_ACTION_PING_TIMEOUT);
  }
}

/** Create new worker */
wr_wkr_t* wr_wkr_new(wr_ctl_t *ctl) {
  LOG_FUNCTION
  wr_wkr_t* worker = wr_malloc(wr_wkr_t);
  if(worker == NULL)
    return NULL;

  // Set default value
  worker->ctl = ctl;
  worker->req = NULL;
  worker->fd = 0;
  worker->id = 0;
  worker->pid = 0;
  worker->app = NULL;
  worker->watcher.active = 0;
  worker->state = WKR_STATE_CONNECTING;
  worker->trials_done = 0;
  worker->t_wait.data = worker;
  worker->loop = ctl->svr->ebb_svr.loop;
  ev_timer_init(&worker->t_wait, wr_wkr_wait_cb, 0., Config->Server.Worker.idle_time);
  return worker;
}

/** Destroy worker */
void wr_wkr_free(wr_wkr_t *worker) {
  LOG_FUNCTION
  
  if(ev_is_active(&worker->t_wait))
    ev_timer_stop(worker->loop,&worker->t_wait);

  if(ev_is_active(&worker->watcher))
      ev_io_stop(worker->loop,&worker->watcher);

  if(worker->req) {
    LOG_DEBUG(DEBUG,"Worker %d with pid %d. Worker cannot served the request.",worker->id, worker->pid);
    LOG_INFO("Worker %d with pid %d. Worker cannot served the request.",worker->id, worker->pid);
    worker->req->using_wkr = FALSE;
    wr_conn_err_resp(worker->req->conn, WR_HTTP_STATUS_500);
  }

  if(worker->app){
    LOG_INFO("Removing worker %d with pid %d...app->q_workers->q_count=%d, q_front=%d, q_rear=%d app=%s",
             worker->id, worker->pid,worker->app->q_workers->q_count,
             worker->app->q_workers->q_front,worker->app->q_workers->q_rear,
             worker->app->conf->name.str);
    if(wr_queue_remove(worker->app->q_workers, worker) == 0) {
      worker->app->high_ratio = TOTAL_WORKER_COUNT(worker->app) * Config->Application.max_req_ratio;
      worker->app->low_ratio = WR_QUEUE_SIZE(worker->app->q_workers) * Config->Application.min_req_ratio;
    }
    wr_queue_remove(worker->app->q_free_workers, worker);
  }else{
    LOG_INFO("Removing worker %d with pid %d", worker->id, worker->pid);
  }

  if(worker->state == WKR_STATE_DISCONNECTING){
    LOG_DEBUG(DEBUG,"Stopping worker %d with pid %d...",worker->id, worker->pid);
    LOG_INFO("Stopping worker %d with pid %d...",worker->id, worker->pid);
    scgi_t* scgi = scgi_new();
    if(scgi) {
      scgi_header_add(scgi, "METHOD", strlen("METHOD"), "REMOVE", strlen("REMOVE"));
      scgi_build(scgi);
      //TODO: made it asynchronous
      scgi_send(scgi, worker->ctl->fd);
      scgi_free(scgi);
    } else {
      kill(worker->pid, SIGHUP);
    }
    worker->pid = 0;
  }else if(worker->state == WKR_STATE_HANGUP){
    kill(worker->pid, SIGKILL);
  }else{
    kill(worker->pid, SIGHUP);
  }

  if(worker->ctl) {
    worker->ctl->wkr = NULL;
    wr_ctl_free(worker->ctl);
  }
  //Close socket
  if(worker->fd > 0)
    close(worker->fd);

  free(worker);
}

/** Request callback called by ebb Request*/
/* It will be called after request is parsed and environment hash is ready.
 * Request is inserted into application queue, and one of free worker allocated to a Request. */
/** Dispatch the request to Worker process */
void wr_wkr_dispatch_req(wr_req_t* req) {
  LOG_FUNCTION
  wr_req_t* new_req = NULL;
  wr_wkr_t* worker = NULL;

  // Check load balance
  wr_app_chk_load_to_add_wkr(req->app);

  //Dispatch message
  WR_APP_MSG_DISPATCH(req->app, new_req, worker)    ;

  if(new_req && worker) {
    wr_wkr_req_processing(worker, new_req);
  }else{
    LOG_DEBUG(DEBUG, "Could not dispatch the request");
  }
}

int wr_wkr_check_uds(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg){
  if(Config->Server.flag & SERVER_UDS_SUPPORT) {
    if(strcmp(ctl_msg->msg.wkr.uds.str,"YES")!=0 ||
        ctl_msg->msg.wkr.sock_path.str == NULL) {
      scgi_body_add(ctl->scgi, "Invalid UDS, sock path and configuration.", strlen("Invalid UDS, sock path and configuration."));
      LOG_ERROR(SEVERE,"connect_with_worker()Invalid UDS, sock path and configuration.");
      return FALSE;
    }
  } else {
    if(strcmp(ctl_msg->msg.wkr.uds.str,"NO")!=0 ||
        ctl_msg->msg.wkr.port.str == NULL) {
      scgi_body_add(ctl->scgi, "Invalid UDS, sock path and configuration.", strlen("Invalid UDS, sock path and configuration."));
      LOG_ERROR(SEVERE,"connect_with_worker()Invalid UDS, sock path and configuration.");
      return FALSE;
    }
  }
  return TRUE;
}

/** Connect to worker using UDS */
int wr_wkr_connect_uds(wr_wkr_t* worker, const wr_ctl_msg_t *ctl_msg){
  struct sockaddr_un addr;
  int len;

  if((worker->fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    perror("socket()");
    LOG_ERROR(4,"socket() failed");
    // Worker is not added, Reset the high load ratio
    return FALSE;
  }

  LOG_DEBUG(3,"Socket successfully open for worker. File Descriptor is %d",worker->fd);

  setsocketoption(worker->fd);
  memset(&addr, 0, sizeof(addr));

  addr.sun_family = AF_UNIX;
  strcpy(addr.sun_path,ctl_msg->msg.wkr.sock_path.str);
  len = sizeof(addr.sun_family) + strlen(addr.sun_path);

#ifdef __APPLE__
  len++;
#endif

  if(connect(worker->fd, (struct sockaddr *)&addr,len) == -1) {
    perror("connect");
    LOG_ERROR(4,"Unable to connect with worker at socket path %s. %s Closing it.",addr.sun_path, strerror(errno));
    close_fd(worker->fd);
    worker->fd=0;
    // Worker is not added, Reset the high load ratio
    return FALSE;
  }

  return TRUE;
}

/** Connect to worker using internet socket */
int wr_wkr_connect_inet(wr_wkr_t* worker, const wr_ctl_msg_t *ctl_msg){
  struct sockaddr_in addr;
  if ((worker->fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
    perror("socket()");
    LOG_ERROR(4,"socket() failed for worker");
    // Worker is not added, Reset the high load ratio
    // return if not able to connect to the first worker
    return FALSE;
  }
  LOG_DEBUG(3,"Socket successfully open for worker. File Descriptor is %d",worker->fd);

  setsocketoption(worker->fd);
  memset(&addr, 0, sizeof(addr));

  addr.sin_family = AF_INET;
  addr.sin_port = htons(atoi(ctl_msg->msg.wkr.port.str));
  addr.sin_addr.s_addr =inet_addr("127.0.0.1");

  if(connect(worker->fd, (struct sockaddr *)&addr,sizeof addr) == -1) {
    perror("connect");
    LOG_ERROR(4,"Unable to connect with worker at port %s. %s Closing it.",ctl_msg->msg.wkr.port.str, strerror(errno));
    close_fd(worker->fd);
    worker->fd=0;
    return FALSE;
  }

  return TRUE;
}

int wr_wkr_set_ratio(wr_ctl_t *ctl, wr_wkr_t* worker){
  if(setnonblock(worker->fd) < 0) {
    LOG_ERROR(SEVERE,"Setting worker_fd non-block failed:%s",strerror(errno));
    close_fd(worker->fd);
    return FALSE;
  }

  if(wr_queue_insert(worker->app->q_workers, worker) < 0){
    LOG_ERROR(WARN,"Worker queue is full.");
    return FALSE;
  }

  //Setting low load ratio for application, refer "wr_worker_remove_cb" in wr_server.c for details.
  worker->app->low_ratio = worker->app->q_workers->q_count * Config->Application.min_req_ratio;
  ctl->wkr = worker;
  LOG_DEBUG(DEBUG,"Added Worker %d",worker->id);

  wr_wkr_state_machine(worker, WKR_ACTION_ADD);
  
  ev_io_set(&worker->watcher,worker->fd,EV_READ);
  return TRUE;
}

/** Handle connect request from Worker */
int wr_wkr_connect(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  wr_svr_t* server = ctl->svr;
  wr_wkr_t* worker = NULL;
  wr_u_short retval = TRUE;

  if(wr_wkr_check_uds(ctl, ctl_msg) == FALSE) return -1;

  LOG_DEBUG(4,"Sock_path = %s, port=%s, app_name=%s, pid=%s", ctl_msg->msg.wkr.sock_path.str,
            ctl_msg->msg.wkr.port.str,
            ctl_msg->msg.wkr.app_name.str,
            ctl_msg->msg.wkr.pid.str);

  worker = wr_wkr_new(ctl);
  if(worker == NULL) {
    LOG_ERROR(WARN,"worker object alloaction failde. Returning ...");
    return -1;
  }

  worker->pid = atoi(ctl_msg->msg.wkr.pid.str);
  
  // Insert newly added Worker to application list*/
  if(wr_app_wkr_insert(server, worker, ctl_msg)!=0) {
    LOG_INFO("No more workers required.");
    free(worker);
    return -1;
  }

  LOG_INFO("Worker %d with PID %d for Application %s inserted successfully. control fd = %d",
           worker->id, worker->pid, worker->app->conf->name.str,worker->ctl->fd);
  if(Config->Server.flag & SERVER_UDS_SUPPORT) {
    retval = wr_wkr_connect_uds(worker, ctl_msg);
  } else {
    retval = wr_wkr_connect_inet(worker, ctl_msg);
  }
  
  if(retval == TRUE) retval = wr_wkr_set_ratio(ctl, worker);
  
  if(retval == FALSE){
    worker->app->high_ratio = TOTAL_WORKER_COUNT(worker->app) * Config->Application.max_req_ratio;
    free(worker);
    return -1;
  }

  LOG_DEBUG(DEBUG,"Allocating task to newly added worker %d",worker->id);
  //Check for pending requests
  wr_wrk_allocate(worker);
  LOG_DEBUG(5,"Successfully connected to worker");
  LOG_DEBUG(DEBUG,"Allocated task to newly added worker %d",worker->id);
  wr_app_wkr_balance(worker->app);
  //wr_app_wkr_added_cb(worker->app);

  return 0;
}

///** This would get called when worker reply to PING */
//void wr_wkr_ping_reply(wr_wkr_t *worker)
//{
//  LOG_FUNCTION
//  LOG_INFO("Worker %d with pid %d replied for trial no %d", worker->id, worker->pid, worker->trials_done);
//  //worker has replied so setting WR_WORKER_REPLIED flag, and clearing WR_WORKER_PING_SENT
//  if(worker->state & WR_WKR_PING_SENT)
//  {
//    ev_timer_stop(worker->ctl->svr->ebb_svr.loop, &worker->t_wait);
//    worker->t_wait.repeat = Config->Server.Worker.idle_time;
//    worker->state &= (~224);
//    ev_timer_again(worker->ctl->svr->ebb_svr.loop, &worker->t_wait);
//  }
//}

/** Worker add callback */
/* This callback function called from controller on receiving WORKER ADD control
 * signal */
void wr_wkr_add_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  int retval;
  retval = wr_wkr_connect(ctl, ctl_msg);

  if(retval == 0) {
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
  } else {
    LOG_ERROR(SEVERE,"failed to connect with worker");
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  }
  wr_ctl_resp_write(ctl);
}

/** Worker Add error callback */
void wr_wkr_add_error_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg){
  LOG_FUNCTION
  wr_app_wkr_error(ctl->svr, ctl_msg);
  scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
  wr_ctl_resp_write(ctl);
}

/** Worker remove callback */
void wr_wkr_remove_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msg) {
  LOG_FUNCTION
  wr_app_t *app = NULL;
  
  if(ctl->wkr ) {
    app = ctl->wkr->app;
    wr_wkr_state_machine(ctl->wkr, WKR_ACTION_REMOVE);
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "OK", strlen("OK"));
  }else{
    LOG_ERROR(SEVERE,"failed to connect with worker");
    scgi_header_add(ctl->scgi, "STATUS", strlen("STATUS"), "ERROR", strlen("ERROR"));
  }
  
  wr_ctl_resp_write(ctl);

  // Create new worker if required
  if(app && app->state == WR_APP_ACTIVE)   wr_app_wkr_balance(app);
}

/** Worker ping callback */
/* Get reply for the ping control request */
void wr_wkr_ping_cb(wr_ctl_t *ctl, const wr_ctl_msg_t *ctl_msgs) {
  LOG_FUNCTION
  wr_wkr_t *worker = ctl->wkr;
  LOG_INFO("Worker %d with pid %d replied for trial no %d", worker->id, worker->pid, worker->trials_done);
  wr_wkr_state_machine(worker, WKR_ACTION_PING_REPLAY);
  scgi_build(ctl->scgi);
  scgi_free(ctl->scgi);
  ctl->scgi = NULL;
  wr_ctl_resp_write(ctl);
}
