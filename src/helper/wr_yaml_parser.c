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
 *             YAML Parser implementation
 *****************************************************************************/

#include <yaml.h>
#include <stdlib.h>
#include <assert.h>
#include <wr_yaml_parser.h>

/** Free node */
void node_free(node_t* node) {

  if(node == NULL)
    return;

  //Free child
  if(node->child) {
    node_free(node->child);
  }

  // Free siblings
  if(node->next) {
    node_free(node->next);
  }

  if(node->name) {
    free(node->name);
    node->name = NULL;
  }
  if(node->value) {
    free(node->value);
    node->value = NULL;
  }

  free(node);
  node = NULL;
}

/** Fetch node value */
char* get_node_value(node_t *root, char* xpath) {
  char *str_ptr, *str_prev;
  node_t *node = root, *result;
  int len;

  str_prev = xpath;
  str_ptr = strchr(xpath,'/');

  //Find first match
  while(str_ptr) {
    len = str_ptr - str_prev;
    result = NULL;
    while(node) {
      if(node->name_len == len && strncmp(str_prev, node->name, len)==0) {
        result = node;
        break;
      }
      node = node->next;
    }

    if(!result) {
      return NULL;
    }

    node = result->child;

    str_prev = str_ptr + 1;
    str_ptr = strchr(str_prev,'/');
  }

  while(node) {
    if(strcmp(str_prev, node->name) == 0) {
      return node->value;
    }
    node = node->next;
  }

  return NULL;
}

/** Fetch set of nodes */
node_t* get_nodes(node_t *root, char* xpath) {
  char *str_ptr;
  node_t *node = root, *node_front, *node_rear, *result;
  int len;

  str_ptr = strchr(xpath,'/');
  node_front = node_rear = NULL;
  if(str_ptr) {
    len = str_ptr - xpath;
    node_front = node_rear = NULL;

    while(node) {
      if(node->name_len == len && strncmp(xpath, node->name, len)==0) {
        //Recursive call to match child nodes
        result = get_nodes(node->child, str_ptr+1);
        if(result) {
          if(!node_front)
            node_front = result;
          if(node_rear)
            node_rear->next_result = result;
          while(result->next_result) {
            result = result->next_result;
          }
          node_rear = result;
        }
      }
      node = node->next;
    }
  } else {
    while(node) {
      if(strcmp(xpath, node->name)==0) {
        if(node_rear)
          node_rear->next_result = node;
        node_rear = node;
        if(!node_front)
          node_front = node;
        node->next_result = NULL;
      }
      node = node->next;
    }
  }
  return node_front;
}

/** Parse YAML file */
node_t* yaml_parse(const char*file_name) {
  FILE *file;
  yaml_parser_t parser;
  yaml_event_t event;
  node_t *node, *config = NULL, *prev;
  int done = 0, is_key = 0, seq_count = -1, is_seq = 0;
  char seq[10][100];
  node_t* stack[100];
  int head = -1;


  file = fopen(file_name, "rb");
  assert(file);

  assert(yaml_parser_initialize(&parser));
  yaml_parser_set_input_file(&parser, file);

  while(!done) {
    if(!yaml_parser_parse(&parser, &event)) {
      perror("yaml_parser_parse()");
      break;
    }

    switch(event.type) {

    case YAML_STREAM_END_EVENT:
      done = 1;
      break;
    case YAML_SCALAR_EVENT:  //Handle Scalar event
      is_key = (is_key == 0);
      if(head != -1) {
        if(is_key) {
          STR_NEW(stack[head]->name, event.data.scalar.value, event.data.scalar.length)
          stack[head]->name_len = event.data.scalar.length;
        } else {  // Copy value and create next node
          STR_NEW(stack[head]->value, event.data.scalar.value, event.data.scalar.length)
          stack[head]->value_len = event.data.scalar.length;
          node = stack[head--];
          prev = node;
          NODE_NEW(node->next)
          stack[++head] = node->next;
        }
      }
      break;
    case YAML_MAPPING_START_EVENT:  //Handle Mapping Start event
      if(config) {
        node = stack[head];
        NODE_NEW(node->child)
        stack[++head] = node->child;
      } else {
        NODE_NEW(config)
        stack[++head] = config;
      }
      //if(!is_seq && is_key){
      //strcpy(map[map_count++], key);
      //printf("\n\n>>> Map:%s >>>",map[map_count-1]);
      is_key = 0;
      //}
      break;
    case YAML_MAPPING_END_EVENT:  //Handle Mapping End event
      if(head != -1) {
        node = stack[head--];
        if(prev->next->name)
          free(prev->next->name);
        if(prev->next->value)
          free(prev->next->value);
        free(prev->next);
        prev->next = NULL;
      }
      if(head != -1) {
        node = stack[head--];
        prev = node;
        NODE_NEW(node->next)
        stack[++head] = node->next;
      }
      if(is_seq && seq_count >= 0) {
        STR_NEW(stack[head]->name, seq[seq_count], strlen(seq[seq_count]))
        stack[head]->name_len = strlen(seq[seq_count]);
        //printf("\n<<< Map:%s <<<\n",map[--map_count]);
      }
      break;
    case YAML_SEQUENCE_START_EVENT:
      is_seq ++;
      strcpy(seq[++seq_count], stack[head]->name);
      is_key = 0;
      break;
    case YAML_SEQUENCE_END_EVENT:
      if(seq_count >= 0)
        seq_count--;
      is_seq --;
      break;
    }

    yaml_event_delete(&event);
  }

  yaml_parser_delete(&parser);
  assert(!fclose(file));

  if(done) {
    return config;
  } else {
    node_free(config);
    return NULL;
  }
}
