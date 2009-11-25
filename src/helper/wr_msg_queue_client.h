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
 
#ifndef WR_QUEUE_CLIENT_H_
#define WR_QUEUE_CLIENT_H_

typedef struct wr_msg_queue_server_s wr_msg_queue_server_t;
typedef struct wr_msg_queue_conn_s wr_msg_queue_conn_t;

struct wr_msg_queue_server_s {
  wr_str_t host;
  int port; 
};

struct wr_msg_queue_conn_s {
  wr_msg_queue_server_t *queue_server;
  int conn_fd; 
};

wr_msg_queue_server_t* wr_msg_queue_server_new(char *host, int port); 
int wr_msg_queue_server_free(wr_msg_queue_server_t *server);
wr_msg_queue_conn_t* wr_msg_queue_conn_new(wr_msg_queue_server_t *server);
int wr_msg_queue_conn_open(wr_msg_queue_conn_t *conn);
// If needed we can add conn_close() api
int wr_msg_queue_conn_free(wr_msg_queue_conn_t *conn);
int wr_msg_queue_set(wr_msg_queue_conn_t *conn, char *queue_name, char *value, int value_len);
 
#endif /*WR_QUEUE_CLIENT_H_*/
