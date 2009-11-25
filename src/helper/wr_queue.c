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
#include <stdio.h>
#include <stdlib.h>

wr_queue_t* wr_queue_new(short size) {
  wr_queue_t* queue = wr_malloc(wr_queue_t);
  if(!queue)
    return NULL;
  queue->q_elements = (void**) malloc (sizeof(void*)*size);
  if(!queue->q_elements)
    return NULL;
  queue->q_front = -1;
  queue->q_rear = -1;
  queue->q_count = 0;
  queue->q_max_size = size;
  return queue;
}

/** Insert element in Worker Queue */
int wr_queue_insert(wr_queue_t* queue, void* element) {
  if(!queue)
    return -1;

  if(queue->q_count < queue->q_max_size) {
    queue->q_count++;
    queue->q_rear = (queue->q_rear + 1) % queue->q_max_size;
    if(queue->q_front == -1)
      queue->q_front = 0;
    queue->q_elements[queue->q_rear] = element;
    return 0;
  }
  return -1;
}

/** Fetch element from Worker Queue */
void* wr_queue_fetch(wr_queue_t* queue) {
  if(!queue)
    return NULL;
  if(queue->q_count > 0) {
    void* element= queue->q_elements[queue->q_front];
    if(queue->q_rear == queue->q_front)
      queue->q_rear = queue->q_front = -1;
    else
      queue->q_front = (queue->q_front + 1) % queue->q_max_size;
    queue->q_count --;
    return element;
  }
  return NULL;
}

/** Remove element from Worker Queue */
int wr_queue_remove(wr_queue_t* queue, void* element) {
  if(!queue)
    return -1;

  int i;
  for(i = 0; i < queue->q_count ; i++) {
    if(queue->q_elements[(queue->q_front+i)% queue->q_max_size] == element)
      break;
  }
  if(i == queue->q_count)
    return -1;

  queue->q_count --;

  for(; i < queue->q_count ; i++) {
    queue->q_elements[(queue->q_front+i)% queue->q_max_size] = queue->q_elements[(queue->q_front+i+1)% queue->q_max_size];
  }

  if(queue->q_rear == queue->q_front)
    queue->q_rear = queue->q_front = -1;
  else if(queue->q_rear == 0)
    queue->q_rear = queue->q_max_size - 1;
  else
    queue->q_rear --;

  return 0;
}


/** Free Worker queue */
void wr_queue_free(wr_queue_t* queue) {
  if(queue) {
    if(queue->q_elements)
      free(queue->q_elements);
    free(queue);
  }
  queue = NULL;
}
