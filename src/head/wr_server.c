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

static struct ev_loop *loop;    //Event loop
struct ev_idle idle_watcher;  //Ideal watcher
/************ Private functions **************************/

/** Create Server */
wr_svr_t* wr_svr_new(struct ev_loop* loop, wr_conf_t* conf) {
  LOG_FUNCTION
  int i;
  wr_svr_t* server = wr_malloc(wr_svr_t);

  if(!server) {
    LOG_ERROR(WARN, "Server object allocation failed. Returning ...");
    return NULL;
  }

  //Get ebb server object
  ebb_server_init(&(server->ebb_svr),loop);

  if(conf->server->flag&WR_SVR_SSL_SUPPORT) {
#ifdef HAVE_GNUTLS

    //Initialize ebb server for SSL support
    ebb_server_init(&(server->secure_ebb_svr),loop);
    // Add GnuTLS support
    if(ebb_server_set_secure(&(server->secure_ebb_svr), conf->server->certificate.str, conf->server->key.str) < 0) {
      ebb_server_unlisten(&(server->secure_ebb_svr));
      //free(server);
      //return NULL;
      LOG_ERROR(SEVERE,"ebb_server_set_secure() failed. Server can not run on SSL.");
    } else {
      server->secure_ebb_svr.data = server;
      server->secure_ebb_svr.new_connection = wr_new_conn_cb;
    }

#endif

  }
  server->ebb_svr.data = server;
  server->ebb_svr.new_connection = wr_new_conn_cb;

  //Create Server Control object
  server->ctl =  wr_svr_ctl_new();
  if(!server->ctl) {
    ebb_server_unlisten(&(server->ebb_svr));
    free(server);
    LOG_ERROR(WARN, "%s() control object allocation failed. Returning ...",__FUNCTION__);
    return NULL;
  }

  server->conf = conf;
  server->apps = NULL;
  server->default_app = NULL;
  server->resolver = wr_req_resolver_new();
  if(server->resolver == NULL) {
    ebb_server_unlisten(&(server->ebb_svr));
    free(server);
    LOG_ERROR(WARN, "Resolver object allocation failed. Returning ...");
    return NULL;
  }

  return server;
}

/** Attach ideal watcher with event loop */
static inline  void attach_idle_watcher() {
  if(!ev_is_active(&idle_watcher)) {
    ev_idle_start (loop, &idle_watcher);
  }
}

/** Detach Ideal watcher from event loop*/
static inline void detach_idle_watcher() {
  ev_idle_stop(loop, &idle_watcher);
}

/** Callback function for Ideal watcher */
static inline void idle_cb (struct ev_loop *loop, struct ev_idle *w, int revents) {
  /*if(clients_in_use_p()) {
    rb_thread_schedule();
} else if(!rb_thread_alone()) {*/
  /* if you have another long running thread running besides the ones used
   * for the webapp's requests you will run into performance problems in
   * ruby 1.8.x because rb_thread_select is slow.
   * (Don't worry - you're probably not doing this.)
   */
  /*    struct timeval select_timeout = { tv_sec: 0, tv_usec: 50000 };
      fd_set server_fd_set;
      FD_ZERO(&server_fd_set);
      FD_SET(server->fd, &server_fd_set);
      rb_thread_select(server->fd+1, &server_fd_set, 0, 0, &select_timeout);
    } else {
      detach_idle_watcher();
    }*/
}
/*****************************************************
 *           Server API Definition                  *
 *****************************************************/

/** Starts listening for requests */
int wr_svr_init(wr_svr_t** server, wr_conf_t *conf) {
  //TODO: attach idle watcher
  //ev_idle_init (&idle_watcher, idle_cb);
  //attach_idle_watcher();

  //Create and initialize Server object
  loop = ev_default_loop (0);
  *server = wr_svr_new(loop, conf);

  if(*server == NULL) {
    LOG_ERROR(SEVERE,"Server is NULL");
    return -1;
  }

  (*server)->conf = conf;
  if(conf->server->flag&WR_SVR_SSL_SUPPORT) {
#ifdef HAVE_GNUTLS
    LOG_DEBUG(DEBUG,"SSL port = %d", conf->server->ssl_port);
    if(ebb_server_listen_on_port(&(*server)->secure_ebb_svr, conf->server->ssl_port) < 0) {
      LOG_ERROR(SEVERE,"ebb_server_listen_on_port(): failed. Port number = %d",conf->server->ssl_port);
      printf("Port %d is already in use.\n", conf->server->ssl_port);
    }
#endif

  }
  LOG_DEBUG(DEBUG,"port = %d", conf->server->port);
  //ebb server starts listening for request
  if(ebb_server_listen_on_port(&(*server)->ebb_svr, conf->server->port) < 1) {
    printf("Port %d is already in use.\n", conf->server->port);
    return -1;
  }

  (*server)->on_app_add = wr_app_add_cb;
  (*server)->on_app_remove = wr_app_remove_cb;
  (*server)->on_app_reload = wr_app_reload_cb;
  (*server)->on_wkr_add = wr_wkr_add_cb;
  (*server)->on_wkr_remove = wr_wkr_remove_cb;
  (*server)->on_wkr_ping = wr_wkr_ping_cb;
  (*server)->default_app = (*server)->static_app = NULL;

  return 0;
}

/** Destroy Server */
void wr_svr_free(wr_svr_t* server) {
  LOG_FUNCTION
  int i;
  //Destroy ebb server object
  ebb_server_unlisten(&(server->ebb_svr));

#ifdef HAVE_GNUTLS

  //Destroy ebb server object used for SSL
  ebb_server_unlisten(&(server->secure_ebb_svr));

#endif


  // Destroy application list
  if(server->apps) {
    wr_app_free(server->apps);
    server->apps = NULL;
  }
  
  if(server->static_app) {
    wr_app_free(server->static_app);
    server->apps = NULL;
  }

  //Destroy Server Control object
  wr_svr_ctl_free(server->ctl);
  wr_conf_free(server->conf);
  wr_req_resolver_free(server->resolver);
  free(server);
}

/*********************************************************/
