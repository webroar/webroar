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
#include <execinfo.h>

// wr_server object
static wr_svr_t *server = NULL;
config_t        *Config = NULL;

/** Cleanup and destroy the Server */
static inline void cleanup(wr_svr_t *server) {
  LOG_FUNCTION

  // Delete 'webroar.sock' file
  remove(Config->Server.File.sock.str);

  // Stop event loop
  ev_unloop(server->ebb_svr.loop, EVUNLOOP_ALL);

  // Destroy the Server structure
  wr_svr_free(server);

  // Delete 'webroar.pid' file
  remove(Config->Server.File.pid.str);
  wr_server_config_free(Config);
  LOG_INFO("Shutting down network server. No more request can be served");

  // Destroy logger object
  close_logger();
}

/** Daemonize the process */
static inline void daemonize() {
  LOG_FUNCTION
  /* Our process ID and Session ID */
  pid_t pid, sid;
  pid_t saved_pid = -1;

  if(saved_pid > 0) {
    printf("SERVER IS ALREADY RUNNING WITH PID %i",saved_pid);
    exit(-1);
  }

  LOG_DEBUG(4,"Calling fork");
  /* Fork off the parent process */
  pid = fork();

  if (pid < 0) {
    exit(EXIT_FAILURE);
  }
  /* If we got a good PID, then
     we can exit the parent process. */
  if (pid > 0) {
    exit(EXIT_SUCCESS);
  }
  /* Open any logs here */

  /* Create a new SID for the child process */
  sid = setsid();
  if (sid < 0) {
    /* Log the failure */
    exit(EXIT_FAILURE);
  }

  close(STDIN_FILENO);
  close(STDOUT_FILENO);
  close(STDERR_FILENO);
  int i=open("/dev/null",O_RDWR); /* open stdin and connect to /dev/null */
  LOG_DEBUG(DEBUG,"i=%d",i);
  int j = dup(i); /* stdout */
  LOG_DEBUG(DEBUG,"j=%d",j);
  j = dup(i); /* stderr */
  LOG_DEBUG(DEBUG,"j=%d",j);

  //Log current pid
  char str[STR_SIZE32];

  int pid_FD=open(Config->Server.File.pid.str,O_RDWR|O_CREAT,0640);
  LOG_DEBUG(4,"FD for PID is %i",pid_FD);

  if (pid_FD<0) {
    LOG_ERROR(5,"CANNOT OPEN PID FILE:%s",strerror(errno));
    exit(1); /* can not open */
  }
  int lpk = lockf(pid_FD,F_TLOCK,0);

  if (lpk<0) {
    printf("SERVER ALREADY RUNNING..\n");
    //can not lock
    exit(-1);

  }
  /* first instance continues */
  sprintf(str,"%d\n",getpid());

  write(pid_FD,str,strlen(str)); /* record pid to lockfile */
  close(pid_FD);

  signal(SIGCHLD, SIG_IGN);
  signal(SIGTSTP, SIG_IGN);
  signal(SIGTTOU, SIG_IGN);
  signal(SIGTTIN, SIG_IGN);
  /* Close out the standard file descriptors */
  LOG_DEBUG(4,"Daemonize Server Done");
}

/** Handle interrupt signal */
void sigproc() {
  LOG_DEBUG(4,"**************Caught Interrupt Signal************");
  // clear keep alive flag.
  server->is_running = 0;
}

/** Handle segmentation fault */
void crash_handler(int sig) {
  void *array[Config->Server.stack_trace];
  size_t size;
  char **bt_symbols;
  char bt_string[Config->Server.stack_trace * STR_SIZE256];
  int i;
  sigset_t unblock_sig;
  
  LOG_ERROR(FATAL, "Got %d signal, trying to create core file.", sig);
  sigemptyset (&unblock_sig);
  sigaddset (&unblock_sig, SIGSEGV);
  sigprocmask (SIG_UNBLOCK, &unblock_sig, NULL);
  if(fork() == 0) { // child
    char cmd[64], core_file_name[48], timestamp[24];
    int rv, sid;
    signal(SIGCHLD, SIG_DFL);    
    
    sprintf(core_file_name, "/tmp/webroar-head");
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
    /* Create a new SID for the child process */
    sid = setsid();
    if (sid < 0) {      
      LOG_ERROR(SEVERE, "setsid() failed, errno = %d, description = %s", errno, strerror(errno));
      exit(EXIT_FAILURE);
    }
    int i = 0;
    /* close all parent process fd except STDIN, STDOUT and STDERR */
    for (i=getdtablesize(); i>=3; --i) {      
      close(i); 
    }    
    sleep(5);    
    LOG_INFO("Executing webroar restart");
    rv = system("webroar restart");    
    if ( rv < 0 ) {
      LOG_ERROR(FATAL, "webroar restart failed, rv = %d, errno = %d, error = %s", rv, errno, strerror(errno));
    }
    LOG_INFO("Return value of webroar restart is %d", rv); 
    exit(0);
  }
  sleep(5);
    
  // get void*'s for all entries on the stack
  size = backtrace(array, Config->Server.stack_trace);
  bt_symbols = backtrace_symbols(array, size);
  strcpy(bt_string, "\n");
  for(i = 0; i < size; i++) {
    strcat(bt_string, bt_symbols[i]);
    strcat(bt_string, "\n");
  }
  LOG_ERROR(FATAL, "Obtained %zd stack frames.%s", size, bt_string);
  free(bt_symbols);
  //TODO: carefully dump server state(e.g. active & hang workers, number of connections, request, current request etc)
  server->is_running = 0;
  cleanup(server);
  exit(0);
}

int main(int argc, char *argv[]) {
  int retval = 0;
  
  Config = wr_server_config_init(argv[1]);
  
  if(Config == NULL) return -1;
  
    //Initialize logger
  if(initialize_logger(Config->Server.File.log.str, Config->Server.name.str, Config->Server.version.str) == 0) {
    LOG_DEBUG(DEBUG,"Logging started in %s file",Config->Server.File.log.str);
  } else {
    printf("Logger initialization failed. Please make sure you have write permission on '/var/log/webroar' directory.");
  }

  //Allocate and initialize configuration structure
  if(wr_conf_read() == FALSE ) {
    LOG_ERROR(FATAL,"Configuration reading failed.");
    printf("Server not started.\nProblem with reading the configuration file. Kindly refer the log files for details.\n");
    wr_server_config_free(Config);
    return -1;
  }

#ifdef L_DEBUG
  set_log_severity(DEBUG);
#else
  set_log_severity(Config->Server.log_level);
#endif
  // Add Admin Panel
  wr_conf_admin_panel_add();
  
  // Add staic file server
  wr_conf_static_server_add();

  //TODO: Windows Portability?
  signal(SIGINT, sigproc);
  signal(SIGPIPE, SIG_IGN);
  signal(SIGHUP, sigproc); /* catch hangup signal */
  signal(SIGTERM, sigproc); /* catch terminate signal */
  signal(SIGSEGV, crash_handler); /* set our handler for segfault */
//  signal(SIGQUIT, crash_handler);
//  signal(SIGILL, crash_handler);
//  signal(SIGABRT, crash_handler);
//  signal(SIGFPE, crash_handler);
  

  // Initialize and start the Server to accept requests
  retval = wr_svr_init(&server);
  if(retval<0) {
    LOG_ERROR(FATAL,"Initialization of network server failed.");
    printf("Server not started. Kindly refer the log files for details.\n");
    wr_server_config_free(Config);
    return retval;
  }
  LOG_INFO("Network server successfully initialized on port %d",Config->Server.port);

  // Set keep alive flag
  server->is_running = 1;

  // Initialize contol port/sock path to recive control messages
  retval = wr_ctl_init(server);
  if(retval < 0) {
    LOG_ERROR(FATAL,"Controller Initialization failed.");
    printf("Server not started. Kindly refer the log files for details.\n");
    wr_svr_free(server);
    wr_server_config_free(Config);
    return retval;
  }
  LOG_INFO("Controller initialized");

  // Fork processes and start 'webroar-workers's
  wr_app_init(server);

  //Daemonize the Server
  daemonize();
  LOG_DEBUG(4,"Done daemon");
  redirect_standard_io();
  // Start event loop
  while(server->is_running) {
    ev_loop(server->ebb_svr.loop,EVLOOP_ONESHOT);
  }

  // Cleanup
  LOG_DEBUG(DEBUG,"Call cleanup");
  cleanup(server);
  return 0;
}
