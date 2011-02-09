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
 *
 * NOTE: Anchors and Aliases are not handled.
 */

#ifndef WR_YAML_PARSER_H_
#define WR_YAML_PARSER_H_

#include <stdio.h>
#include <string.h>

/** Macro definitions */

#define STR_NEW(new, str, len) do { new = (char*) malloc(sizeof(char)*(len+1));\
  strcpy(new, str); } while(0);

typedef enum type_e {
  TYPE_NONE = 0, TYPE_VALUE, TYPE_PAIR, TYPE_LIST, TYPE_ARRAY
} type_t;

typedef struct node_s node_t;

struct node_s {
  type_t type;
  char *key, *value;
  int key_len, value_len;
  short level;
  node_t *child, *next;
};

/** Print YAML structure */
void yaml_display(node_t *);

/** Parse the YAML file and create node structure */
node_t* yaml_parse(const char*);

/** Release node memory */
void yaml_node_free(node_t*);

/** Search node */
node_t* yaml_get_node(node_t *root, char *xpath);

/** Search node and get value */
char* yaml_get_value(node_t *root, char* xpath);

/** Validate YAML token */
char* yaml_validate_string(const char* str);

#endif /*WR_YAML_PARSER_H_*/
