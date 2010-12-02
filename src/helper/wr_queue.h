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
#ifndef WR_QUEUE_H_
#define WR_QUEUE_H_

/************ Queue structure **************/
typedef struct {
  short q_front;
  short q_max_size;
  short q_rear;
  short q_count;
  void  **q_elements;
}wr_queue_t;

wr_queue_t* wr_queue_new(short);
int wr_queue_insert(wr_queue_t*, void*);
void* wr_queue_fetch(wr_queue_t*);
int wr_queue_remove(wr_queue_t*, void*);
void wr_queue_free(wr_queue_t* queue);

#define WR_QUEUE_SIZE(queue) queue->q_count
#define WR_QUEUE_MAX_SIZE(queue) queue->q_max_size

/** Insert element in Queue */
#define WR_QUEUE_INSERT(queue, element, retval) do {\
  retval = -1;\
  if(queue->q_count < queue->q_max_size){\
    queue->q_count++;\
    queue->q_rear = (queue->q_rear + 1) % queue->q_max_size;\
    if(queue->q_front == -1) queue->q_front = 0;\
    queue->q_elements[queue->q_rear] = element;\
    retval = 0;\
  } } while(0);

/** Fetch message from Message Queue */
#define WR_QUEUE_FETCH(queue, element) do {\
  element = NULL;\
  if(queue->q_count > 0){\
    element = queue->q_elements[queue->q_front];\
    if(queue->q_rear == queue->q_front){\
      queue->q_rear = queue->q_front = -1;\
    }else{\
      queue->q_front = (queue->q_front + 1) % queue->q_max_size;\
    }\
    queue->q_count --;\
  } } while(0);

#endif /*WR_QUEUE_H_*/
