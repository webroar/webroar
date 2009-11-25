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
 
#include <wr_helper.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define WR_MSG_QUEUE_VALUE_SIZE 512

wr_msg_queue_server_t* wr_msg_queue_server_new(char *host, int port) {
  LOG_FUNCTION
  wr_msg_queue_server_t *server = NULL;
  server = wr_malloc(wr_msg_queue_server_t);
  if (server == NULL) {
    LOG_ERROR(SEVERE, "Memory allocation to wr_msg_queue_server_t failed");
    return NULL; 
  }
  wr_string_new(server->host, host, strlen(host));
  server->port = port;
  return server;  
}

int wr_msg_queue_server_free(wr_msg_queue_server_t *server) {
  LOG_FUNCTION
  if (server) {    
    free(server);
  }
  return 0;
}

wr_msg_queue_conn_t* wr_msg_queue_conn_new(wr_msg_queue_server_t *server){
  LOG_FUNCTION
  wr_msg_queue_conn_t *conn = NULL;
  if (!server) { 
    return NULL;
  }
  conn = wr_malloc(wr_msg_queue_conn_t);
  if (!conn) {
    LOG_ERROR(SEVERE, "Memory allocation to wr_msg_queue_conn_t failed");
    return NULL; 
  }
  conn->queue_server = server;
  conn->conn_fd = 0;  
  return conn;
}

int wr_msg_queue_conn_open(wr_msg_queue_conn_t *conn) {
  LOG_FUNCTION;
  if (!conn) return -1;
  
  struct sockaddr_in addr;
  if ( (conn->conn_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1 ) {
    LOG_ERROR(SEVERE, "Socket opening for wr_msg_queue_conn failed");
    wr_msg_queue_conn_free(conn);
    return -1; 
  }
  LOG_DEBUG(DEBUG, "Socket for wr_msg_queue_conn successfully opened. File descriptor is %d", conn->conn_fd);
  setsocketoption(conn->conn_fd);
  memset(&addr, 0, sizeof(addr)); 
  addr.sin_family = AF_INET;
  addr.sin_port = htons(conn->queue_server->port);
  addr.sin_addr.s_addr = inet_addr(conn->queue_server->host.str);
  
  if ( (connect(conn->conn_fd, (struct sockaddr *)&addr, sizeof addr)) == -1) {
    LOG_ERROR(SEVERE, "wr_msg_queue_conn - Socket connect error, errno = %d, desc = %s", errno, strerror(errno));
    //close(conn->conn_fd);
    //conn->conn_fd = 0;
    //wr_msg_queue_conn_free(conn);
    return -1; 
  }
  
  return 0;   
}

int wr_msg_queue_conn_free(wr_msg_queue_conn_t *conn) {
  LOG_FUNCTION
  if (!conn) return -1;
  if (conn->conn_fd) close(conn->conn_fd);
  free(conn);
  return 0; 
}

int wr_msg_queue_set(wr_msg_queue_conn_t *conn, char *queue_name, char *value, int value_len) {
  LOG_FUNCTION
  char message[WR_MSG_QUEUE_VALUE_SIZE];
  int msg_len = 0, sent = 0, read = 0, temp = 0;
  if (!conn || !queue_name || !value) {
    return -1;
  }
  msg_len = sprintf(message, "set %s 0 0 %d\r\n%s\r\n", queue_name, value_len, value);
  while (sent < msg_len) {
    temp = send(conn->conn_fd, message + sent, msg_len - sent, 0);
    if (temp < 0) {
      LOG_ERROR(WARN, "Failed to set the message in queue, errno = %d, errmsg = %s", errno, strerror(errno));
      return -1; 
    }
    sent += temp;
  }
  
  read = recv(conn->conn_fd, message, WR_MSG_QUEUE_VALUE_SIZE, 0);
  if (read < 0) {
    LOG_ERROR(WARN, "Failed to read response from message queue, errno = %d, errmsg = %s", errno, strerror(errno));
    //Message may be set successfully
    return -2;   
  }
  message[read] = 0;
  if (strcmp(message, "STORED\r\n") == 0) {
    return 0;
  } else {
    return -3;
  }
}