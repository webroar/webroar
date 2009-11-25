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
/******************************************************************************
 *          Implementation of Logger module
 *****************************************************************************/

#include<wr_logger.h>
#include<stdarg.h>
#include<stdlib.h>
#include<string.h>
#include<stdio.h>
#include<time.h>
#include<errno.h>

static inline char* get_date_time();
static inline char* get_executable_path();
static inline char* get_log_file_path();

//this macro should included in common utility
#define null_check(ptr) if (ptr == NULL) \
{ \
  printf("Fatal memory error. Execution Terminated.\n%s:%d\n",__FILE__,__LINE__); \
  exit(-1); \
}

FILE               *log_fp = NULL;
LOG_SEVERITY       logging_level = DEBUG;
char             *log_file_path = NULL;

void close_logger() {
  //if(log_fp != NULL)     fclose(log_fp);
  log_fp = NULL;
  if (log_file_path != NULL)
    free(log_file_path);
  fclose(stdout);
  fclose(stderr);
}

static inline char* get_log_file_path() {
  return log_file_path;
}

static inline  char* get_date_time() {
  struct tm     *now=NULL;
  time_t         time_value=0;
  char         *str;

  time_value    = time(NULL);
  now          = localtime(&time_value);
  str           = asctime(now);
  // Removes new line character
  str[strlen(str)-1] = '\0';
  return str;
}

/* Redirect stdout and stderr to logfile */
void redirect_standard_io() {
  freopen(log_file_path, "a+", stdout);
  freopen(log_file_path, "a+", stderr);  
}

/** Initialize logger */
int initialize_logger(const char*file_name) {
  char *path=NULL;

  int retval;
  const char *PATH_SEPARATOR = "/";//in windows we'll need forward slash
  log_file_path=(char*)malloc(sizeof(char)*512);
  null_check(log_file_path);

  if(file_name!=NULL) {
    strcpy(log_file_path, WR_LOG_DIR);
    strcat(log_file_path, PATH_SEPARATOR);
    strcat(log_file_path, file_name);
  } else {
    return -1;
  }

  log_fp=fopen(log_file_path,"a+");  //do we require a lock on file?
  if(log_fp==NULL) {
    printf("Error in opening log file %s:%s. Are you root? Trying to open in PWD.\n",log_file_path,strerror(errno));
    getcwd(log_file_path, 512);
    strcat(log_file_path, PATH_SEPARATOR);
    strcat(log_file_path, file_name);
    log_fp=fopen(log_file_path,"a+");
    if(log_fp == NULL) {
      printf("Log file opening in PWD also failed.\n");
      return -1;
    }
  }

  fprintf(log_fp,"\nLog file opened at %s",get_date_time());
  fclose(log_fp);
  return 0;
}


void a_log(const char* type,LOG_SEVERITY level,const char* format,...) {
  va_list arg_ptr;
  va_start(arg_ptr,format);
  if(level >= logging_level && log_file_path) {
    log_fp=fopen(log_file_path,"a+");
    if(log_fp) {
      fprintf(log_fp,"\n%s-%d-%s:", get_date_time(), getpid(), type);
      vfprintf(log_fp,format,arg_ptr);
      fclose(log_fp);
    }
  }
}

void a_error(LOG_SEVERITY level, const char *file_name, int line_no, const char *function_name, const char *format, ...) {
  va_list arg_ptr;
  va_start(arg_ptr,format);
  if(level >= logging_level) {
    log_fp=fopen(log_file_path,"a+");
    if(log_fp) {
      fprintf(log_fp,"\n%s-%d-Error:", get_date_time(), getpid());
      vfprintf(log_fp,format,arg_ptr);
      fclose(log_fp);
    }
  }
}

/** Get logging severity */
LOG_SEVERITY get_log_severity(const char*str) {
  if(strcmp(str,"DEBUG") == 0) {
    return DEBUG;
  }
  if(strcmp(str,"INFO") == 0) {
    return INFO;
  }
  if(strcmp(str,"WARN") == 0) {
    return WARN;
  }
  if(strcmp(str,"SEVERE") == 0) {
    return SEVERE;
  }
  if(strcmp(str,"FATAL") == 0) {
    return FATAL;
  }
}

/** Change log file group-owner to given group and user id */
int change_log_file_owner(int user_id, int group_id) {
  return chown(log_file_path, user_id, group_id);
}

/** Set logging level */
int set_log_severity(int severity) {
  LOG_INFO("setting log level to %d",severity);
  logging_level = severity;
}
