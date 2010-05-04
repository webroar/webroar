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
 *                 YAML Parser
 *****************************************************************************/

/**
 * Parse the YAML file and generate node tree.
 * These node tree used by 'configurator' module.
 */

#ifndef WR_YAML_PARSER_H_
#define WR_YAML_PARSER_H_

#include <stdio.h>
#include <string.h>

/** Macro definitions */
#define NODE_NEXT(node) node->next_result
#define NODE_VALUE(node) node->value

#define STR_NEW(new, str, len) new = (char*) malloc(sizeof(char)*(len+1));\
  strcpy(new, str);

#define NODE_NEW(node) node = (node_t*) malloc(sizeof(node_t));\
  node->name = NULL;\
  node->name_len =0;\
  node->value = NULL;\
  node->value_len = 0;\
  node->child = NULL;\
  node->next = NULL;\
  node->next_result = NULL;

typedef struct node_s node_t;

struct node_s {
  char* name;    /**< Node name */
  int name_len;  /**< Name length */
  char* value;  /**< Node value */
  int value_len;  /**< Value length */
  node_t* next;  /**< Pointer to sibling */
  node_t* child;  /**< Pointer to child nodes*/
  node_t* next_result;  /**< Pointer used by 'get_nodes' method*/
};

node_t* yaml_parse(const char*);
node_t* get_nodes(node_t *root, char* xpath);
char* get_node_value(node_t *root, char* xpath);
void node_free(node_t* node);
char* wr_validate_string(const char* str);

#endif /*WR_YAML_PARSER_H_*/
