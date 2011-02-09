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
 *                           Stack
 *****************************************************************************/

#ifndef WR_STACK_H_
#define WR_STACK_H_

typedef struct wr_stack_s wr_stack_t;
typedef struct wr_stack_node_s wr_stack_node_t;

/** Private structure to store stack elements */
struct wr_stack_s{
  wr_stack_node_t *list;
};

/** Push element to the Stack */
int wr_stack_push(wr_stack_t *stack, void *data);

/** Pop element from the Stack */
void* wr_stack_pop(wr_stack_t *stack);

/** Initialise the  Stack pointers */
/* NOTE: stack pointer should not be NULL */
void wr_stack_init(wr_stack_t *stack);

/** Free list nodes from the Stack */
/* NOTE: It only free the node list and not stack pointer */
void wr_stack_free(wr_stack_t *stack);

#endif /* WR_STACK_H_ */
