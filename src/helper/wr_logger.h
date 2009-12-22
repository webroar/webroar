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
 *                 Logger module
 *****************************************************************************/

/**
 * Logged messages based on specified priority
 */

#ifndef wr_logger_h
#define wr_logger_h

/** Logging levels */
typedef enum
{
  DEBUG = 1,
  INFO,
  WARN,
  SEVERE,
  FATAL
}LOG_SEVERITY;

/** Log debug message */
#ifdef L_DEBUG
  #define LOG_DEBUG(severity,format,args...) a_log("Debug", severity, format, ##args)
#else
  #define LOG_DEBUG(severity,format,args...)
#endif

/** Log information message */
#ifdef L_INFO
  #define LOG_INFO(format,args...) a_log("Info", 5, format, ##args)//to ensure info should be logged every time passing 5 as level
#else
  #define LOG_INFO(format,args...)
#endif

/** Log error message */
#ifdef L_ERROR
  #define LOG_ERROR(severity,format,args...) a_error(severity,__FILE__,__LINE__,__FUNCTION__,format,##args);
#else
  #define LOG_ERROR(severity,format,args...)
#endif

/** Logging directory */
#define WR_LOG_DIR "/var/log/webroar"
//#define WR_LOG_DIR "."

#define LOG_FUNCTION LOG_DEBUG(DEBUG,"%s()", __FUNCTION__);

void   close_logger();
int     initialize_logger(const char*file_name, const char *server, const char *version); //prerequisite to use logger
void   a_log(const char* type,LOG_SEVERITY level,const char* format,...);
void   a_error(LOG_SEVERITY level, const char *file_name, int line_no, const char *function_name, const char *format, ...);
int change_log_file_owner(int user_id, int group_id);
LOG_SEVERITY get_log_severity(const char*str);
int   set_log_severity(int);
void redirect_standard_io();
#endif //end of wr_logger.h
