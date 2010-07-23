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

#define DEFAULT_LOWER_LIMIT 1024
#define DEFAULT_UPPER_LIMIT 10485760

static wkr_t        *worker = NULL;
config_t            *Config = NULL;

struct               ev_loop *loop;    // Event loop
struct               ev_idle idle_watcher;
int                  is_alive = 1;

/** Usage */
void print_usage(char *appname) {
  printf("usage: \n%s [-c <control_port/sock_path>] [-i <uds>] [-n <application_name>]",appname);
  printf("[-l <log_level>] [-f <log_file>] [-o <root_path>] [-k <keep_alive>]\n");
  printf("<control_port/sock_path> = Control port number (control sock path in case [-i 1])\n");
  printf("<uds> = Unix domain socket flag. Value should be 0 or 1.\n");
  printf("<application_name> = Name of application\n");
  printf("<log_level> = Logging Level\n");
  printf("<log_file> = Name of the log file\n");
  printf("<root_path> = Root directory path\n");
  printf("<keep_alive> = Keep Alive flag value must be 'y'/'n'\n");
}

void sigproc() {
  //  file_log("/tmp/too_many_worker.log","Webroar-Worker of %s getting close\n", worker->tmp->name.str);
  LOG_DEBUG(4,"**************Caught Interrupt Signal************");
  is_alive = 0;
}

void cleanup() {
  LOG_FUNCTION
  ev_idle_stop(loop, &idle_watcher);
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

/** Read and set Worker Configuration **/
void wr_worker_config_read(){
  LOG_FUNCTION
  node_t *root;
  
  LOG_DEBUG(4,"YAML file path %s", Config->Worker.File.internal_config);
  root = yaml_parse(Config->Worker.File.internal_config.str);

  if(!root) {
    LOG_ERROR(SEVERE, "Config file found with erroneous entries. Please correct it.");
    printf("Config file found with erroneous entries. Please correct it.\n");
    return;
  }
  
  wr_set_numeric_value(root, "Worker/maximum_request_body_size", &Config->Worker.max_body_size, FALSE);
  node_free(root);
  
  Config->Worker.Compress.lower_limit = DEFAULT_LOWER_LIMIT;
  Config->Worker.Compress.upper_limit = DEFAULT_UPPER_LIMIT;
}

/** Parse command line arguments */
wkr_tmp_t* parse_args(int argc, char **argv) {
  int option;
  extern char *optarg;
  size_t len;
  char *str;
  int invalid_arg_flag = 0, log_level = INFO;
  wkr_tmp_t *tmp = wkr_tmp_new();
  
  if(tmp == NULL)
    return NULL;
    
  while ( (option=getopt(argc,argv,"l:f:c:i:n:o:k:")) != -1 ) {
    str = optarg;
    len = strlen(str);
    switch ( option ) {    
    case 'l':  // Logging level
      log_level = atoi(optarg);
      break;
    case 'f':  // Log file name
      wr_string_free(tmp->log_file);
      wr_string_new(tmp->log_file, str, len);
      break;
    case 'c':  // Control path
      wr_string_new(tmp->ctl_path, str, len);
      break;
    case 'i':  // Unix domain socket flag
      if(strcmp(optarg, "y")==0) {
        tmp->is_uds = TRUE;
      }
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
  wr_worker_config_read();
  
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
  
  if (invalid_arg_flag > 0 || tmp->root_path.str == NULL || Config == NULL) {
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

void idle_cb (struct ev_loop *loop, struct ev_idle *w, int revents) {
  LOG_FUNCTION
  /* Calling libev's blocking call ev_loop() between TRAP_* macros were working on Ruby 1.8, 
   * but didn't worked on Ruby 1.9, looks we need to schedule ruby threads on our own
   */
  if(rb_thread_alone()) {
    /* Stop scheduling ruby threads, there is only one! */
    ev_idle_stop(loop, &idle_watcher);
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

void init_idle_watcher(wkr_t *w){
  if(!w->http->stat){
    ev_idle_init (&idle_watcher, idle_cb);
    start_idle_watcher();
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
    return -1;
  }

  worker = w;  
  
  //TODO: Windows Portability?
  signal(SIGHUP, sigproc); /* catch hangup signal */
  signal(SIGINT, sigproc);
  signal(SIGTERM, sigproc);
  //  signal(SIGCHLD, SIG_IGN);
  signal(SIGTSTP, SIG_IGN);
  signal(SIGTTOU, SIG_IGN);
  signal(SIGTTIN, SIG_IGN);
  signal(SIGPIPE, SIG_IGN);

  while(is_alive ==1) {
    /* TODO: wrapping ev_loop() between TARP_* macros didn't worked in Ruby 1.9 */
    //TRAP_BEG;
    ev_loop(loop,EVLOOP_ONESHOT);
    //TRAP_END;
  }
  cleanup();
  return 0;
}
