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
 *             Implementation of Stack
 *****************************************************************************/

#include <wr_stack.h>
#include <stdlib.h>
#include <wr_macro.h>

struct wr_stack_node_s{
  void *data;
  wr_stack_node_t *next;
};

int wr_stack_push(wr_stack_t *stack, void *data){
  wr_stack_node_t *new;
  new = wr_malloc(wr_stack_node_t);

  if(!new){
    return -1;
  }

  new->data = data;
  new->next = stack->list;
  stack->list = new;

  return 0;
}

void* wr_stack_pop(wr_stack_t *stack){

  if(stack && stack->list){
    wr_stack_node_t *tmp = stack->list;
    void* data = tmp->data;
    stack->list = stack->list->next;
    free(tmp);
    return data;
  }

  return NULL;
}

void wr_stack_init(wr_stack_t *stack){
  stack->list = NULL;
}

void wr_stack_free(wr_stack_t *stack){
  while(wr_stack_pop(stack));
}
