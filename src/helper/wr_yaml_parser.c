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
#include <wr_stack.h>
#include <wr_logger.h>

node_t* create_node() {
  node_t *node = (node_t*) malloc(sizeof(node_t));
  node->child = node->next = NULL;
  node->key = node->value = NULL;
  node->key_len = node->value_len = node->level = 0;
  node->type = TYPE_NONE;
  return node;
}

/** Parse YAML file */
node_t* yaml_parse(const char*file_name) {
  FILE *file;
  yaml_parser_t parser;
  yaml_event_t event;
  node_t *node = NULL, *new, *head_node;
  int level = 0, done = 0;
  wr_stack_t stack;

  void create_child_node() {
    new = create_node();
    new->level = ++level;
    if (node) {
      wr_stack_push(&stack, node);
      node->child = new;
    }
    node = new;
  }

  void set_sibling_nodes() {
    head_node = (node_t*) wr_stack_pop(&stack);
    while (head_node && head_node->level == level) {
      head_node->next = node;
      node = head_node;
      head_node = (node_t*) wr_stack_pop(&stack);
    }
    if (head_node) {
      wr_stack_push(&stack, head_node);
    }
    level--;
    if (head_node) {
      if (head_node->child != node) {
        new = create_node();
        new->level = level;
        new->type = head_node->type;
        new ->child = node;
        wr_stack_push(&stack, new);
      }
      node = NULL;
    }
  }

  void create_scalar_node() {
    if (node) {
      wr_stack_push(&stack, node);
    }

    node = create_node();
    if (head_node = (node_t*) wr_stack_pop(&stack)) {
      node->type = head_node->type;
      wr_stack_push(&stack, head_node);
    } else {
      node->type = TYPE_NONE;
    }
    node->level = level;
    STR_NEW(node->key, event.data.scalar.value, event.data.scalar.length);
    node->key_len = event.data.scalar.length;
  }

  file = fopen(file_name, "rb");
  assert(file);

  assert(yaml_parser_initialize(&parser));
  yaml_parser_set_input_file(&parser, file);
  wr_stack_init(&stack);

  while (!done) {
    if (!yaml_parser_parse(&parser, &event)) {
      perror("Invalid YAML format.");
      break;
    }

    switch (event.type) {

    case YAML_NO_EVENT:
      printf("\nYAML_NO_EVENT");
      break;
    case YAML_STREAM_END_EVENT:
      done = 1;
      break;
    case YAML_SCALAR_EVENT:
      if (node == NULL) {
        create_scalar_node();
      } else if (node->key == NULL) {
        STR_NEW(node->key, event.data.scalar.value, event.data.scalar.length);
        node->key_len = event.data.scalar.length;
      } else if (node->type == TYPE_LIST) {
        create_scalar_node();
      } else if (node->value == NULL) {
        STR_NEW(node->value, event.data.scalar.value, event.data.scalar.length);
        node->value_len = event.data.scalar.length;
      } else {
        create_scalar_node();
      }
      break;
    case YAML_SEQUENCE_START_EVENT:
      create_child_node();
      node->type = TYPE_LIST;
      break;
    case YAML_SEQUENCE_END_EVENT:
      set_sibling_nodes();
      break;
    case YAML_MAPPING_START_EVENT:
      create_child_node();
      node->type = TYPE_ARRAY;
      break;
    case YAML_MAPPING_END_EVENT:
      set_sibling_nodes();
      break;
    }

    yaml_event_delete(&event);
  }

  yaml_parser_delete(&parser);
  assert(!fclose(file));

  if (done) {
    head_node = (node_t*) wr_stack_pop(&stack);
    if (head_node && !stack.list) {
      return head_node;
    } else if (node) {
      wr_stack_free(&stack);
      return node;
    }
  } else {
    head_node = (node_t*) wr_stack_pop(&stack);
    while (head_node && stack.list) {
      wr_stack_push(&stack, head_node);
      set_sibling_nodes();
      head_node = (node_t*) wr_stack_pop(&stack);
    }
    yaml_node_free(node);
    if (head_node) {
      yaml_node_free(head_node);
    }
  }

  return NULL;
}

/** Display YAML Structure */
void yaml_display(node_t * root) {

  if (root == NULL)
    return;
  printf("\n%*s", root->level * 4, " ");
  if (root->type == TYPE_LIST)
    printf("-  ");
  if (root->key)
    printf("%s", root->key);
  if (root->value)
    printf(": %s", root->value);
  yaml_display(root->child);
  yaml_display(root->next);
}

void yaml_node_free(node_t* node) {
  if (node == NULL)
    return;

  if (node->next) {
    yaml_node_free(node->next);
    node->next = NULL;
  }

  if (node->child) {
    yaml_node_free(node->child);
    node->child = NULL;
  }

  if (node->key)
    free(node->key);
  if (node->value)
    free(node->value);

  free(node);
}

/** Search node */
node_t* yaml_get_node(node_t *root, char *xpath) {
  char *str_ptr;
  node_t *node = root, *result = NULL;
  int len;

  str_ptr = strchr(xpath, '/');
  if (str_ptr) {
    len = str_ptr - xpath;

    if (len == 1 && xpath[0] == '*') {
      while (node && !result) {
        result = yaml_get_node(node->child, str_ptr + 1);
        node = node->next;
      }
    } else {
      while (node && !result) {
        if (node->key_len == len && strncmp(xpath, node->key, len) == 0) {
          result = yaml_get_node(node->child, str_ptr + 1);
        }
        node = node->next;
      }
    }
  } else if (strcmp(xpath, "*") == 0) {
    result = node;
  } else {
    while (node) {
      if (node->key && strcmp(xpath, node->key) == 0) {
        result = node;
        break;
      }
      node = node->next;
    }
  }
  return result;
}

/** Search node and get value */
char* yaml_get_value(node_t *root, char* xpath) {
  node_t *result = yaml_get_node(root, xpath);
  if (result && result->value) {
    return result->value;
  }
  return NULL;
}

/** Validate YAML tokens */
char* yaml_validate_string(const char* str) {
  int count, len, is_blank, is_comment;

  if (str == NULL)
    return NULL;

  //Set flags
  is_blank = 1;
  is_comment = 0;
  len = strlen(str);
  for (count = 0; count < len; count++) {
    //check for blank value
    if (str[count] != ' ') {
      is_blank = 0;
    }
    //check for comment '#' character
    if (str[count] == '#') {
      is_comment = 1;
      break;
    }
  }
  if (is_comment || is_blank) {
    LOG_ERROR(SEVERE,"Invalid token.");
    return NULL;
  }
  return (char*) str;
}
