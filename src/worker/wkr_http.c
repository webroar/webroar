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
#include <worker.h>
#include <ruby.h>

#include "wkr_static.h"

/** for handling of $0, courtesy http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/16221 */
static VALUE gProgName = Qnil;
static VALUE cReq;
static VALUE cRequestHandler;
static VALUE rb_req;
static http_t *g_http;

#ifndef RSTRING_PTR
# define RSTRING_PTR(s) (RSTRING(s)->ptr)
# define RSTRING_LEN(s) (RSTRING(s)->len)
#endif

#ifndef RARRAY_PTR
# define RARRAY_PTR(s) (RARRAY(s)->ptr)
# define RARRAY_LEN(s) (RARRAY(s)->len)
#endif

/** Call 'Ruby' method 'RequestHandler.process' */
void http_req_process() {
  LOG_FUNCTION
  if(g_http->is_static){
    static_file_process(g_http);
  }else{
    rb_funcall(cRequestHandler, rb_intern("process"),1,rb_req);
    // New thread could be created during request processing, start idle watcher to keep scheduling it
    start_idle_watcher();
  }
}

/** Read request by 'Ruby' */
VALUE read_request(VALUE _, VALUE req, VALUE size) {
  LOG_FUNCTION
  VALUE string;
  int _size = FIX2INT(size);

  string = rb_str_buf_new( _size );
  int nread = http_req_body_read(g_http->req, RSTRING_PTR(string), _size);

#if RUBY_VERSION < 190

  RSTRING_LEN(string) = nread;
#else

  rb_str_set_len(string, nread);
#endif

  if(nread < 0)
    rb_raise(rb_eRuntimeError,"There was a problem reading from input (bad tmp file?)");
  if(nread == 0)
    return Qnil;
  return string;
}

/** HTTP response headers callback */
VALUE req_write_headers(VALUE _, VALUE req, VALUE status, VALUE headers, VALUE body_length) {
  LOG_FUNCTION
  size_t resp_body_len;

  http_resp_t *rsp  = g_http->resp;

  http_req_set(g_http->req);
  rsp->resp_code = FIX2INT(status);
  resp_body_len = FIX2INT(body_length);
  char *str = RSTRING_PTR(headers);
  size_t len = RSTRING_LEN(headers);
  wr_string_new(rsp->header,str, len);
  if(resp_body_len > 0) {
    wr_buffer_create(rsp->resp_body, resp_body_len);
  }

  LOG_DEBUG(DEBUG, "req_write_headers() status=%d header_len = %d, body_length = %d",
            rsp->resp_code, rsp->header.len, resp_body_len);

  return Qnil;
}

/** HTTP response body callback */
VALUE req_write_body(VALUE _, VALUE req, VALUE string) {
  LOG_FUNCTION
  http_resp_t *rsp  = g_http->resp;
  char *str = RSTRING_PTR(string);
  size_t len = RSTRING_LEN(string);

  wr_buffer_add(rsp->resp_body, str, len);

  return Qnil;
}

/** HTTP response completed callback */
VALUE req_resp_completed(VALUE _, VALUE req) {
  LOG_FUNCTION
  wkr_t *w  = (wkr_t*) g_http->wkr;

  http_resp_process(g_http->resp);

  ev_io_init(&(w->w_req), http_resp_scgi_write_cb, w->req_fd,EV_WRITE);
  ev_io_start(w->loop, &w->w_req);

  return Qnil;
}


/** Read SCGI headers by 'Ruby' and convert it into hash */
VALUE req_env(VALUE _, VALUE rb_req) {
  LOG_FUNCTION

  scgi_t           *scgi;
  scgi_header_t   *header;
  VALUE                   field, value, hash = rb_hash_new();

  scgi = g_http->req->scgi;

  if(scgi) {
    header = scgi->header_list;
    while(header) {
      LOG_DEBUG(DEBUG,"%s : %s", scgi->header + header->field_offset, scgi->header + header->value_offset);
      field   = rb_str_new2(scgi->header + header->field_offset);
      value   = rb_str_new2(scgi->header + header->value_offset);
      rb_hash_aset(hash, field, value);
      header = header->next;
    }
  }
  return hash;
}

/** Logging 'Ruby' messsage */
VALUE log(VALUE _, VALUE message_type, VALUE severity, VALUE log_message) {
  a_log(StringValuePtr(message_type), FIX2INT(severity), StringValuePtr(log_message));
  return Qnil;
}

/** for handling of $0 */
static void setProgName(VALUE name, ID id) {
  LOG_FUNCTION
  gProgName = rb_obj_as_string(name);
  rb_obj_taint(gProgName);
}

/** Initialize ruby interface */
void init_ruby_interface(http_t *h) {
  LOG_FUNCTION

  VALUE mObj;

  mObj = rb_define_module("Webroar");
  cReq = rb_define_class_under(mObj, "Client", rb_cObject);
  cRequestHandler = rb_define_class_under(mObj, "RequestHandler", rb_cObject);
  rb_define_singleton_method(mObj, "log", log, 3);
  rb_define_singleton_method(mObj, "read_request", read_request, 2);
  rb_define_singleton_method(mObj, "client_env", req_env, 1);
  rb_define_singleton_method(mObj, "client_write_headers", req_write_headers, 4);
  rb_define_singleton_method(mObj, "client_write_body", req_write_body, 2);
  rb_define_singleton_method(mObj, "client_resp_completed", req_resp_completed, 1);

  /** override Ruby's hooked handlers for $0 so that $0 can be
         *  treated as pure Ruby value and modified without restriction
         */
  rb_define_hooked_variable("$0", &gProgName, 0, setProgName);
}

static int init_ruby_interpreter(wkr_t *w) {
  LOG_FUNCTION
  //initializing ruby interpreter ... referred from main.c and ruby.c of ruby-dev
  //preparing pseudo argc and argv to set ruby_option
  int c = 2, retval = 0;
  char **v = NULL;
  v=(char**)malloc(sizeof(char*)*c);
  if(!v) {
    LOG_ERROR(WARN,"Memory allocation to pseudo argv failed.");
    retval = -1;
    goto err;
  }
  v[0] = v[1] = NULL;
  v[0] = (char*) malloc(sizeof(char)*20);
  if(!v[0]) {
    LOG_ERROR(WARN,"Memory allocation to pseudo argv failed.");
    retval = -1;
    goto err;
  }
  strcpy(v[0],"webroar-worker");

  v[1] =  (char*) malloc(sizeof(char)*(w->tmp->script_path.len+1));
  if(!v[1]) {
    LOG_ERROR(WARN,"Memory allocation to pseudo argv failed.");
    retval = -1;
    goto err;
  }
  strcpy(v[1], w->tmp->script_path.str);

  //RUBY_INIT_STACK;
  ruby_init();
  ruby_script("webroar-worker");
  ruby_init_loadpath();
  ruby_options(c, v);
  LOG_INFO("Ruby interpreter initialized successfully");

err:
  if(v && v[0]) {
    free(v[0]);
  }
  if(v && v[1]) {
    free(v[1]);
  }
  if(v) {
    free(v);
  }
  return retval;
}

#if RUBY_VERSION < 190
/* Exception handling code for Ruby script, loaded from embedded interpreter is
   based on code given at http://zzz.zggg.com/perl_ruby_multithreading_embedding.html
*/
static inline void show_error_pos() {
  LOG_FUNCTION
  ID this_func = rb_frame_last_func();
  if (ruby_sourcefile) {
    if (this_func) {
      LOG_INFO("show_error_pos() %s:%s:in %s", ruby_sourcefile,ruby_sourceline,rb_id2name(this_func));
    } else {
      LOG_INFO("show_error_pos() %s:%s", ruby_sourcefile,ruby_sourceline);
    }
  }
}

static inline void show_exception_info() {
  LOG_FUNCTION
  if (NIL_P(ruby_errinfo))
    return;

  VALUE errat = rb_funcall(ruby_errinfo, rb_intern("backtrace"), 0);
  if (!NIL_P(errat)) {
    VALUE mesg = RARRAY_PTR(errat)[0];

    if (NIL_P(mesg)) {
      show_error_pos();
    } else {
      LOG_INFO("%s",RSTRING_PTR(mesg));
    }
  }

  VALUE eclass = CLASS_OF(ruby_errinfo);

  char* einfo;
  int elen;
  int state;
  VALUE estr = rb_protect(rb_obj_as_string, ruby_errinfo, &state);
  if (state) {
    einfo = "";
    elen = 0;
  } else {
    einfo = RSTRING_PTR(estr);
    elen = RSTRING_LEN(estr);
  }

  if (eclass == rb_eRuntimeError && elen == 0) {
    LOG_INFO(": unhandled exception");
  } else {
    VALUE epath;
    epath = rb_class_path(eclass);
    if (elen == 0) {
      LOG_INFO("%s: ",RSTRING_PTR(epath));
    } else {
      char* tail  = 0;
      int len = elen;

      if ((RSTRING_PTR(epath))[0] == '#')
        epath = 0;

      if (tail = strchr(einfo, '\n')) {
        len = tail - einfo;
        tail++;
      }
      LOG_INFO("%s: ", einfo);
      if (epath) {
        LOG_INFO(" (%s",RSTRING_PTR(epath));
      }

      if (tail) {
        LOG_INFO("%s",tail);
      }
    }
  }

  if (!NIL_P(errat)) {
    const int TRACE_HEAD = 8;
    const int TRACE_TAIL = 5;
    const int TRACE_MAX = TRACE_HEAD + TRACE_TAIL + 5;

    long len =  RARRAY_LEN(errat);
    int i = 1;
    for (i = 1; i < len; ++i) {
      if (TYPE(RARRAY_PTR(errat)[i]) == T_STRING) {
        LOG_INFO("  from %s ",RSTRING_PTR(RARRAY_PTR(errat)[i]));
      }

      if (i == TRACE_HEAD && len > TRACE_MAX) {
        LOG_INFO("   ... %d ld levels... ",len - TRACE_HEAD - TRACE_TAIL);
        i = len - TRACE_TAIL;
      }
    }
  }
}
#endif

/** Load rack adapter */
int load_rack_adapter(wkr_tmp_t *tmp) {
  LOG_FUNCTION

  int state = 0, path_length=0;
  char *path;
  LOG_DEBUG(DEBUG,"load_rack_adapter() Application path is = %s",tmp->path.str);
  // TODO: Keys are being setup as strings. Doesn't allow standard symbol based access in ruby script.
  VALUE g_options=rb_hash_new();
  rb_hash_aset(g_options,rb_str_new("root",4),rb_str_new2(tmp->path.str));
  rb_hash_aset(g_options,rb_str_new("environment",11),rb_str_new2(tmp->env.str));
  rb_hash_aset(g_options,rb_str_new("app_type",8),rb_str_new2(tmp->type.str));
  rb_hash_aset(g_options,rb_str_new("app_name",8),rb_str_new2(tmp->name.str));
  rb_hash_aset(g_options, rb_str_new("webroar_root",12), rb_str_new2(tmp->root_path.str));

  if(tmp->resolver.len > 1) {
    rb_hash_aset(g_options,rb_str_new("prefix",6),rb_str_new2(tmp->resolver.str));
  } else {
    rb_hash_aset(g_options,rb_str_new("prefix",6),rb_str_new2(""));
  }
  if(tmp->profiler == 'y') {
    LOG_DEBUG(DEBUG,"Analytics ebabled");
    rb_hash_aset(g_options,rb_str_new("app_profiling",13),rb_str_new("yes",3));
  } else {
    LOG_DEBUG(DEBUG,"Analytics disabled");
    rb_hash_aset(g_options,rb_str_new("app_profiling",13),rb_str_new("no",2));
  }
  if(tmp->keep_alive) {
    LOG_DEBUG(DEBUG,"setting keep-alive true");
    rb_hash_aset(g_options,rb_str_new("keep_alive",10),Qtrue);
  } else {
    LOG_DEBUG(DEBUG,"setting keep-alive false");
    rb_hash_aset(g_options,rb_str_new("keep_alive",10),Qfalse);
  }
#ifdef L_DEBUG
  LOG_DEBUG(DEBUG,"setting debug true");
  rb_hash_aset(g_options,rb_str_new("debug",5),Qtrue);
#else

  LOG_DEBUG(DEBUG,"setting debug false");
  rb_hash_aset(g_options,rb_str_new("debug",5),Qfalse);
#endif

  rb_gv_set("g_options",g_options);

#if RUBY_VERSION < 190

  rb_load_protect(rb_str_new2(tmp->script_path.str), 0, &state);
  //free(path);
  LOG_DEBUG(DEBUG,"state=%d",state);
  if (state) {
    switch (state) {
    case 0x1: // TAG_RETURN
      LOG_INFO("unexpected return");
      show_error_pos();
      break;
    case 0x2: // TAG_BREAK
      LOG_INFO("unexpected break");
      show_error_pos();
      break;
    case 0x3: // TAG_NEXT
      LOG_INFO("unexpected next");
      show_error_pos();
      break;
    case 0x4: // TAG_RETRY
      LOG_INFO("retry outside of rescue clause");
      show_error_pos();
      break;
    case 0x5: // TAG_REDO
      LOG_INFO("unexpected redo");
      show_error_pos();
      break;
    case 0x6: // TAG_RAISE
    case 0x8: // TAG_FATAL
      show_exception_info();
      break;
    default:
      LOG_INFO("unknown long jump status ");
    }
    // TODO: No magic numbers please
    return -1;
  }
#else
  rb_require(tmp->script_path.str);
#endif

  return 0;
}

http_t* http_new(void *ptr) {
  LOG_FUNCTION
  wkr_t *w = (wkr_t*) ptr;
  http_t *h = wr_malloc(http_t);

  if(h==NULL) {
    return NULL;
  }

  w->http = h;
  h->wkr = ptr;
  
  h->req = http_req_new();
  h->resp = http_resp_new();

  if(h->req==NULL || h->resp == NULL) {
    http_free(&h);
    return NULL;
  }
  
  if(w->tmp->is_static){
    if(static_module_init(w->tmp->root_path.str)!=0){
      http_free(&h);
      return NULL;
    }
    h->is_static = 1;
  }else{
    if(init_ruby_interpreter(w)!=0) {
      http_free(&h);
      return NULL;
    }
    
    init_ruby_interface(h);
    if(load_rack_adapter(w->tmp) < 0) {
      http_free(&h);
      return NULL;
    }
    rb_req = Data_Wrap_Struct(cReq, 0, 0, h->req);
    h->is_static = 0;
  }
  g_http = h;
  return h;
}

void http_free(http_t** http) {
  LOG_FUNCTION
  http_t *h = *http;  
  if(h) {
    if(h->is_static){
      static_module_free();
    }else{
      ruby_finalize();
    }
    
    if(h->resp)
      http_resp_free(&h->resp);
    if(h->req)
      http_req_free(&h->req);
    free(h);
  }
  *http = NULL;
}

void http_set(http_t* h) {
  LOG_FUNCTION
  if(h->resp)
    http_resp_set(h->resp);
  if(h->req)
    http_req_set(h->req);
#ifdef L_DEBUG

  h->conn_id = h->req_id = 0;
#endif
}
