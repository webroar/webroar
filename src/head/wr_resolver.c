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
#include <string.h>

extern config_t *Config;

/*********** Private Function ***********/
void wr_req_resolver_print(wr_req_resolver_t* resolver) {
  LOG_FUNCTION
  if(resolver) {
    if(resolver->baseuris) {
      wr_baseuri_t* baseuri = resolver->baseuris;
      while(baseuri) {
        LOG_DEBUG(DEBUG,"Baseuri = %s", baseuri->app->conf->baseuri.str);
        baseuri = baseuri->next;
      }
    }
    if(resolver->hosts) {
      wr_host_list_t *hosts = resolver->hosts;
      while(hosts) {
        LOG_DEBUG(DEBUG,"Host type = %d, Host = %s", hosts->host->type, hosts->host->name.str);
        hosts = hosts->next;
      }
    }
  }
}

/** Resolve static content */
int wr_req_resolve_static_content(wr_req_t *req){
  LOG_FUNCTION
  char path[STR_SIZE1KB + Config->Request.max_path_size];
  char *req_path;
  struct stat buf;
  int len;
  wr_str_t decoded_req_path;

  if(WR_QUEUE_SIZE(req->app->svr->static_app->q_workers) <= 0){
    LOG_ERROR(SEVERE,"Static content server is down.")
    return -1;
  }
  if(req->req_path.len == req->app->conf->baseuri.len){
    return -1;
  }
  
  if (req->app->conf->baseuri.len > 1) {
    req_path = req->req_path.str + req->app->conf->baseuri.len;
    len = req->req_path.len - req->app->conf->baseuri.len;
  }else {
    req_path = req->req_path.str;
    len = req->req_path.len;
  }
  decoded_req_path = uri_decode(req_path, len);
  sprintf(path, "%s/public%s", req->app->conf->path.str, decoded_req_path.str);
  wr_string_free(decoded_req_path);
  if (stat(path, &buf)) {
    return -1;
  }
  if (S_ISDIR(buf.st_mode) != 0) {
    LOG_DEBUG(DEBUG, "%s is a directory.", path);
    return -1;
  }

  /* Add WR_FILE_PATH header into SCGI header list */
  LOG_DEBUG(DEBUG, "File path = %s, lenght = %d", path, strlen(path));
  scgi_header_add(req->scgi, Config->Request.Header.file_path.str, Config->Request.Header.file_path.len, path, strlen(path));
  req->app = req->app->svr->static_app;

  return 0;
}

/**************************************/
/** Create new resolver */
wr_req_resolver_t* wr_req_resolver_new() {
  LOG_FUNCTION

  wr_req_resolver_t *resolver = wr_malloc(wr_req_resolver_t);
  if(!resolver) {
    return NULL;
  }
  resolver->baseuris = NULL;
  resolver->hosts = NULL;

  return resolver;
}

/** Add Application resolver */
int wr_req_resolver_add(wr_svr_t *server, wr_app_t *app, config_application_list_t *conf) {
  LOG_FUNCTION
  short  rv = 0;

  if(conf->baseuri.str) {
    LOG_DEBUG(DEBUG, "Adding resolver baseuri = %s",conf->baseuri.str);
    wr_baseuri_t *baseuri = wr_malloc(wr_baseuri_t);
    if(baseuri == NULL) {
      rv = -1;
    }

    baseuri->baseuri_hash = uri_hash(conf->baseuri.str + 1);

    if(baseuri->baseuri_hash == Config->Request.prefix_hash) {
      free(baseuri);
      server->default_app = app;
    } else {
      baseuri->app = app;
      LOG_DEBUG(DEBUG, "resolver baseri = %u", server->resolver->baseuris);
      baseuri->next = server->resolver->baseuris;
      server->resolver->baseuris = baseuri;
    }
  }
  /** Host name list would be filled in following order.
  * Static host names
  * Host name start with '*'
  * Host name end with '*'
  * Host name start and end with '*'
  */

  if(conf->host_name_list) {
    config_host_list_t *host = conf->host_name_list;
    while(host) {
      LOG_DEBUG(DEBUG, "Adding resolver Host = %s, type=%d",host->name.str, host->type);
      wr_host_list_t *list = wr_malloc(wr_host_list_t);
      wr_host_list_t *tmp , *prev = NULL;

      if(list == NULL) {
        return -1;
      }
      list->host = host;
      list->app = app;

      tmp = server->resolver->hosts;
      while(tmp && host->type > tmp->host->type) {
        prev = tmp;
        tmp = tmp->next;
      }

      LOG_DEBUG(DEBUG, "resolver Host = %u", server->resolver->hosts);

      if(prev) {
        list->next = tmp;
        prev->next = list;
      } else {
        list->next = server->resolver->hosts;
        server->resolver->hosts = list;
      }

      host = host->next;
    }
  }

  return rv;
}

/** Remove resolver */
int wr_req_resolver_remove(wr_svr_t *server, wr_app_t *app) {
  LOG_FUNCTION
  /* remove baseuri */
  wr_baseuri_t *baseuri, *prev_baseuri = NULL;

  baseuri = server->resolver->baseuris;

  if(server->default_app == app) {
    server->default_app = NULL;
  }

  while(baseuri) {
    if(baseuri->app == app) {
      LOG_DEBUG(DEBUG,"Removed application %s",baseuri->app->conf->baseuri.str);
      //      if(baseuri->baseuri_hash == Config->Request.prefix_hash){
      //        server->default_app = NULL;
      //      }
      if(prev_baseuri == NULL) {
        server->resolver->baseuris = baseuri->next;
        free(baseuri);
        baseuri = server->resolver->baseuris;
      } else {
        prev_baseuri->next = baseuri->next;
        free(baseuri);
        baseuri = prev_baseuri->next;
      }
    } else {
      prev_baseuri = baseuri;
      baseuri = baseuri->next;
    }
  }

  /* remove host name */

  wr_host_list_t *list, *prev_list = NULL;

  list = server->resolver->hosts;

  while(list) {
    if(list->app == app) {
      LOG_DEBUG(DEBUG,"Removed application %s",app->conf->baseuri.str);
      if(prev_list == NULL) {
        server->resolver->hosts = list->next;
        free(list);
        list = server->resolver->hosts;
      } else {
        prev_list->next = list->next;
        free(list);
        list = prev_list->next;
      }
    } else {
      prev_list = list;
      list = list->next;
    }
  }

  return 0;
}

/** Resolve the application */
int wr_req_resolve_http_req(wr_svr_t *server, wr_req_t *req) {
  LOG_FUNCTION
  wr_app_t *app = NULL;

  /* resolve base uri */
  if(req->req_path.str) {
    wr_baseuri_t *baseuri = server->resolver->baseuris;
    wr_u_long hash = uri_hash_len(req->req_path.str+1, req->req_path.len-1);
    while(baseuri) {
      if(baseuri->baseuri_hash == hash) {
        LOG_DEBUG(DEBUG,"Application resolved with baseuri %s",baseuri->app->conf->baseuri.str);
        app = baseuri->app;
        break;
      }
      baseuri = baseuri->next;
    }
  }
  /* resolve host name */
  if(app == NULL && server->resolver->hosts) {
    scgi_header_t *http_host = scgi_header_get(req->scgi, "HTTP_HOST");
    if(http_host) {
      wr_str_t host_str;
      wr_host_list_t *list = server->resolver->hosts;
      char *value = req->scgi->header + http_host->value_offset;

      //removing port
      char *ptr = memchr(value, ':', http_host->value_length);
      if(ptr) {
        wr_string_new(host_str, value, ptr - value);
      } else {
        wr_string_new(host_str, value, http_host->value_length);
      }

      while(list) {
        if(list->host->type == HOST_TYPE_STATIC &&
            list->host->name.len == host_str.len &&
            strncmp(list->host->name.str, host_str.str, host_str.len)==0) {
          LOG_DEBUG(DEBUG,"Application resolved with WR_HOST_TYPE_STATIC host %s", list->host->name.str);
          app = list->app;
          break;
        } else if(list->host->type == HOST_TYPE_WILDCARD_IN_START &&
                  list->host->name.len < host_str.len &&
                  strncmp(list->host->name.str, host_str.str + host_str.len -  list->host->name.len, list->host->name.len)==0) {
          LOG_DEBUG(DEBUG,"Application resolved with WR_HOST_TYPE_WILDCARD_IN_START host %s", list->host->name.str);
          app = list->app;
          break;
        } else if(list->host->type == HOST_TYPE_WILDCARD_IN_END &&
                  list->host->name.len < host_str.len &&
                  strncmp(list->host->name.str, host_str.str, list->host->name.len)==0) {
          LOG_DEBUG(DEBUG,"Application resolved with WR_HOST_TYPE_WILDCARD_IN_END host %s", list->host->name.str);
          app = list->app;
          break;
        } else if(list->host->type == HOST_TYPE_WILDCARD_IN_START_END &&
                  list->host->name.len < host_str.len &&
                  strstr(host_str.str, list->host->name.str)!=NULL) {
          LOG_DEBUG(DEBUG,"Application resolved with WR_HOST_TYPE_WILDCARD_IN_START_END host %s", list->host->name.str);
          app = list->app;
          break;
        }
        list = list->next;
      }
      wr_string_free(host_str);
    }
  }

  if(app == NULL) {
    LOG_DEBUG(DEBUG,"Application resolved with default application.");
    app = server->default_app;
  }

  if(app && WR_QUEUE_SIZE(app->q_workers) > 0) {
//    int rv = 0;
    req->app = app;
    wr_req_resolve_static_content(req);
    LOG_DEBUG(DEBUG,"Application resolved with %s.", req->app->conf->name.str);
    return 0;
//    if(wr_req_resolve_static_content(req) == 1){
//      return 1;
//    }
//    WR_QUEUE_INSERT(req->app->msg_que, req, rv)
//    return rv;
  }

  return -1;
}

/** Destroy the resolver */
void wr_req_resolver_free(wr_req_resolver_t *resolver) {
  LOG_FUNCTION
  if(resolver) {
    wr_host_list_t *list = resolver->hosts, *next_list;
    wr_baseuri_t *baseuri = resolver->baseuris, *next_baseuri;
    while(list) {
      next_list = list->next;
      free(list);
      list = next_list;
    }

    while(baseuri) {
      next_baseuri = baseuri->next;
      free(baseuri);
      baseuri = next_baseuri;
    }

    free(resolver);
  }
  resolver = NULL;
}
