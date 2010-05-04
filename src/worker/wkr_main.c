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

#include <assert.h>
#include <string.h>
#include <worker.h>
#include <ruby.h>
#include <rubysig.h>
#include <execinfo.h>
#ifdef __linux__
#include <sys/prctl.h>
#endif

static wkr_t        *worker = NULL;
config_t            *Config = NULL;

struct               ev_loop *loop;    // Event loop
struct               ev_idle idle_watcher;
int                 is_alive = 1;

static int drop_privileges(wkr_t *w) {
  change_log_file_owner(w->tmp->uid, w->tmp->gid);
  //setting read, effective, saved group and user id
  if(setgid(w->tmp->gid)!=0) {
    LOG_ERROR(SEVERE,"setegid() failed");
    return -1;
  }
  if(setuid(w->tmp->uid)!=0) {
    LOG_ERROR(SEVERE,"seteuid() failed");
    return -1;
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
  return 0;
}

/** Usage */
static inline void print_usage(char *appname) {
  printf("usage: \n%s -a <application_path> [-e <environment>] [-u <cuid >] [-g <cgid>] ",appname);
  printf("[-c <control port/sock path>] [-i <uds>] [-t <application_type>] [-n <application_name>] ");
  printf("[-p <analytics>] [-r <application baseuri>]\n");
  printf("<application_path> = path of rails application. e.g. /home/xyz/rails_projects/app1\n");
  printf("<environment> = rails environment. development/production. Default is production.\n");
  printf("<cuid> = User id.\n");
  printf("<cgid> = Group id.\n");
  printf("<control port/sock path> = Control port number (control sock path in case [-i 1])\n");
  printf("<uds> = Unix domain socket flag. Value should be 0 or 1.\n");
  printf("<application_type> = Type of application {rails, merb}.\n");
  printf("<application_name> = Name of application\n");
  printf("<analytics> = Analytics flag. Value should be yes or no.\n");
  printf("<baseuri> = Application URL baseuri.\n");
}

void sigproc() {
  //  file_log("/tmp/too_many_worker.log","Webroar-Worker of %s getting close\n", worker->tmp->name.str);
  LOG_DEBUG(4,"**************Caught Interrupt Signal************");
  is_alive = 0;
}

void cleanup() {
  LOG_FUNCTION
  stop_idle_watcher();
  LOG_DEBUG(DEBUG,"stoping event loop");
  ev_unloop(loop,EVUNLOOP_ALL);
  //TODO: send worker stopping signal
  worker_free(&worker);
  wr_worker_config_free(Config);
  LOG_INFO("Worker stopped and exiting gracefully.");
  close_logger();
  exit(0);
}
 
/** Handle segmentation fault */
void crash_handler(int sig) {
  void *array[Config->Worker.stack_tace];
  size_t size;
  char **bt_symbols;
  char bt_string[Config->Worker.stack_tace * STR_SIZE256];
  int i;
  
  LOG_ERROR(FATAL, "Got %d signal, trying to create core file.", sig);
  signal(sig, SIG_DFL);
  //kill(getpid(), sig);
  if(fork() == 0) { // child
    char cmd[64], core_file_name[48], timestamp[24];
    int rv;
    signal(SIGCHLD, SIG_DFL);
    //TODO: add application name
    sprintf(core_file_name, "/tmp/webroar-worker");
    if ( get_timestamp(timestamp) == 0 ) {
      strcat(core_file_name, "-");
      strcat(core_file_name, timestamp);
    }
#ifdef __APPLE__
    sprintf(cmd, "gcore -c %s %ld", core_file_name, (long) getppid() );
#else
    sprintf(cmd, "gcore -o %s %ld", core_file_name, (long) getppid() );
#endif
    rv = system(cmd);
    if ( rv < 0 ) {
      LOG_ERROR(FATAL, "Core file creation failed, gcore might be missing... rv = %d, errno = %d, error = %s", rv, errno, strerror(errno));
    } else {
      LOG_INFO("Core file - %s created", core_file_name);
    }
    exit(0);
  }
  sleep(5);
  // get void*'s for all entries on the stack
  size = backtrace(array, Config->Worker.stack_tace);
  bt_symbols = backtrace_symbols(array, size);
  strcpy(bt_string, "\n");
  for(i = 0; i < size; i++) {
    strcat(bt_string, bt_symbols[i]);
    strcat(bt_string, "\n");
  }
  LOG_ERROR(FATAL, "Obtained %zd stack frames.%s", size, bt_string);
  free(bt_symbols);
  //TODO: carefully dump worker state, current request
  cleanup();
}

/** Parse command line arguments */
static inline wkr_tmp_t* parse_args(int argc, char **argv) {
  int option;
  extern char *optarg;
  size_t len;
  char *str;
  int invalid_arg_flag = 0, app_path_flag = 0, log_level = INFO;
  wkr_tmp_t *tmp = wkr_tmp_new();

  if(tmp == NULL)
    return NULL;

  while ( (option=getopt(argc,argv,"a:e:l:f:g:u:c:i:t:n:o:p:r:k:")) != -1 ) {
    str = optarg;
    len = strlen(str);
    switch ( option ) {
    case 'a':  // Application Path
      wr_string_new(tmp->path, str, len);
      app_path_flag = 1;
      break;
    case 'e':  // Application environment
      wr_string_new(tmp->env, str, len);
      break;
    case 'l':  // Logging level
      log_level = atoi(optarg);
      break;
    case 'f':  // Log file name
      wr_string_free(tmp->log_file);
      wr_string_new(tmp->log_file, str, len);
      break;
    case 'g':  // Group id
      tmp->gid = atoi(optarg);
      break;
    case 'u':  // User id
      tmp->uid = atoi(optarg);
      break;
    case 'c':  // Control path
      wr_string_new(tmp->ctl_path, str, len);
      break;
    case 'i':  // Unix domain socket flag
      if(strcmp(optarg, "y")==0) {
        tmp->is_uds = TRUE;
      }
      break;
    case 't':  // Application type
      wr_string_new(tmp->type, str, len);
      break;
    case 'n':  // Application name
      wr_string_new(tmp->name, str, len);
      wr_string_free(tmp->log_file);
      tmp->log_file.str = (char*) malloc(sizeof(char)*(strlen(optarg)+8));
      tmp->log_file.len = sprintf(tmp->log_file.str,"%s.log", optarg);
      break;
    case 'o':  // Server root path
      wr_string_new(tmp->root_path, str, len);
      break;
    case 'r':  // Applicaiton base uri
      wr_string_new(tmp->resolver, str, len);
      break;
    case 'p':  // Analytics flag
      if(strcmp(optarg, "y")==0) {
        tmp->profiler = 'y';
      }
      break;
    case 'k':
      if(strcmp(optarg, "n")==0) {
        tmp->keep_alive = FALSE;
      }
      break;
    default:
      invalid_arg_flag++;
    }
  }

  Config = wr_worker_config_init(tmp->root_path.str);
  
  if(tmp->log_file.str){
    initialize_logger(tmp->log_file.str, Config->Worker.Server.name.str, Config->Worker.Server.version.str);
    redirect_standard_io();
#ifdef L_DEBUG
      set_log_severity(DEBUG);
#else
      set_log_severity(log_level);
#endif
  }else{
    perror("Log file is not specified.");
  }

  if (invalid_arg_flag > 0 || app_path_flag == 0 || tmp->root_path.str == NULL || Config == NULL) {
    print_usage(argv[0]);
    LOG_ERROR(SEVERE, "Either argument is invalid or application/root path is not passed.");
    wkr_tmp_free(&tmp);
    wr_worker_config_free(Config);
    return NULL;
  }
  
  if(strcmp(tmp->name.str, Config->Worker.static_server.str) == 0){
    tmp->is_static = 1;
  }
  return tmp;
}

void start_idle_watcher() {
  LOG_FUNCTION
  if(!ev_is_active(&idle_watcher)) {
    ev_idle_start (loop, &idle_watcher);
  }
}

void stop_idle_watcher() {
  LOG_FUNCTION
  ev_idle_stop(loop, &idle_watcher);
}

void idle_cb (struct ev_loop *loop, struct ev_idle *w, int revents) {
  LOG_FUNCTION
  /* Calling libev's blocking call ev_loop() between TRAP_* macros were working on Ruby 1.8, 
   * but didn't worked on Ruby 1.9, looks we need to schedule ruby threads on our own
   */
  if(rb_thread_alone()) {
    /* Stop scheduling ruby threads, there is only one! */
    stop_idle_watcher();    
  } else {
    /* TODO: Found following three api to schedule ruby threads  
     * rb_thread_schedule() was getting called infinitely and eating most of the CPU. 
     * rb_thread_polling() was getting called, for approximately 16 times in a second on 1.8
     * and 10 times on 1.9 
     * rb_thread_select() takes delay(in struct timeval) as last argument, useful to control 
     * number of call in a second, but need to checkout best value for that argument
     * Ruby 1.9 have rb_thread_blocking_region() to execute C blocking call, need to explore it
     * Checkout the best strategy to combine ruby thread scheduling with libev. 
     * Currently rb_thread_polling looks suitable to use  */
    rb_thread_polling();
    //rb_thread_schedule();
  } 
}

static void send_error(){
  if(worker){
    worker->ctl->error = TRUE;
    return send_err_ctl_msg(worker);
  }
  cleanup();
}

#define SET_ENVIRONMENT_VARIABLE "Environment Variable/set_env"
#define WR_CONF_APP_SPEC           "Application Specification"
#define WR_CONF_APP_NAME           "name"

int manipulate_environment_variable(wkr_tmp_t *tmp) {
  LOG_FUNCTION
  node_t *root = NULL, *env_var = NULL, *app_nodes = NULL;
  char *str, *app_name;
  int rv = 0;  

  app_name = tmp->name.str;
  
  root = yaml_parse(Config->Worker.File.config.str);
  if (root == NULL) {
    LOG_ERROR(SEVERE, "Could not read config.yml file");
    return -1;
  }
  
  app_nodes = get_nodes(root, WR_CONF_APP_SPEC);
  
  // Iterate application nodes
  while(app_nodes) {
    if(app_nodes->child) {
      str = wr_validate_string(get_node_value(app_nodes->child, WR_CONF_APP_NAME));
      // Compare application name
      if(str && strcmp(str, app_name)==0) {        
        break;
      }
    }
    app_nodes = NODE_NEXT(app_nodes);
  }
  
  if(!app_nodes || !app_nodes->child) 
    return -1;
  
  tmp->env_var = wr_string_list_new();  
  env_var = get_nodes(app_nodes->child , SET_ENVIRONMENT_VARIABLE);
  while(env_var) {
    str = wr_validate_string(NODE_VALUE(env_var));
    if (str) {
      // TODO: see the security concerns      
      wr_string_list_add(tmp->env_var, str, strlen(str));
      rv = putenv(tmp->env_var->rear->str.str);
      if (rv != 0) {
        LOG_ERROR(WARN, "putenv() failed, errno = %d, description = %s", errno, strerror(errno)); 
      } 
    }
    env_var = NODE_NEXT(env_var);   
  }
}

int main(int argc, char **argv) {
  wkr_t* w = NULL;

  if(argc == 1) {
    print_usage(argv[0]);
    return -1;
  }
  
  signal(SIGSEGV, crash_handler); /* set our handler for segfault */
//  signal(SIGQUIT, crash_handler);
//  signal(SIGILL, crash_handler);
//  signal(SIGABRT, crash_handler);
//  signal(SIGFPE, crash_handler);
  
  wkr_tmp_t *tmp = parse_args(argc, argv);
  if(tmp == NULL)
    return -1;
  
  loop = ev_default_loop (0);

  w = worker_new(loop, tmp);
  if(w==NULL){
    wr_worker_config_free(Config);
    send_error();
    return -1;
  }

  worker = w;  
  
  LOG_DEBUG(DEBUG,"control path = %s, Application baseuri = %s",
            w->tmp->ctl_path.str,  w->tmp->resolver.str);

  if(drop_privileges(w)!=0) {
    send_error();
  } else {
    manipulate_environment_variable(tmp);
    w->http = http_new(w);
    if(w->http == NULL) {
      LOG_ERROR(SEVERE,"unable to load application.");
      send_error();
    }else if(worker_connect(w) < 0) {
      LOG_ERROR(WARN,"Error Initializing Workers.");
      send_error();
    }else{
      worker_accept_requests(w);
      LOG_INFO("Worker ready for serving requests.");
        
      if(!w->http->is_static){
        ev_idle_init (&idle_watcher, idle_cb);
        start_idle_watcher();
      }
      LOG_INFO("Successfully loaded rack application=%s with environment=%s",
           w->tmp->path.str,   w->tmp->env.str);
    }
  }

  //loading adapter according to application type
  LOG_DEBUG(DEBUG,"webroar_root = %s", w->tmp->root_path.str);
  LOG_DEBUG(DEBUG,"path = %s, name = %s, type = %s, environment = %s, baseuri = %s, analytics = %c",
            w->tmp->path.str,  w->tmp->name.str, w->tmp->type.str,
            w->tmp->env.str, w->tmp->resolver.str, w->tmp->profiler);

  wkr_tmp_free(&w->tmp);

  //TODO: Windows Portability?
  signal(SIGHUP, sigproc); /* catch hangup signal */
  signal(SIGINT, sigproc);
  signal(SIGTERM, sigproc);
  //  signal(SIGCHLD, SIG_IGN);
  signal(SIGTSTP, SIG_IGN);
  signal(SIGTTOU, SIG_IGN);
  signal(SIGTTIN, SIG_IGN);
  signal(SIGPIPE, SIG_IGN);

/*
    worker_accept_requests(w);
    LOG_INFO("Worker ready for serving requests.");

    if(!w->http->is_static){
      ev_idle_init (&idle_watcher, idle_cb);
      start_idle_watcher();
    }
*/

  while(is_alive ==1) {
    /* TODO: wrapping ev_loop() between TARP_* macros didn't worked in Ruby 1.9 */
    //TRAP_BEG;
    ev_loop(loop,EVLOOP_ONESHOT);
    //TRAP_END;
  }

  cleanup();
  return 0;
}
