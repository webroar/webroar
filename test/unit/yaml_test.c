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
 *             YAML Parser Unit Test Cases
 *****************************************************************************/
#include <stdio.h>
#include <string.h>
#include <wr_yaml_parser.h>
#include <ut_test.h>
#include <test.h>

/** Test with key value pairs */
void test_key_value_pairs()
{
  node_t* root = yaml_parse("config/config1.yml");

  UT_ASSERT_PTR_NOT_NULL(root)
  UT_ASSERT_STRING_EQUAL(get_node_value(root,"item"),"keybord")
  UT_ASSERT_STRING_EQUAL(get_node_value(root,"price"),"100")
  UT_ASSERT_PTR_NULL(get_node_value(root,"code"))

  if(root)
  {
    node_free(root);
  }
}

/** Test with sequence */
void test_sequence()
{
  node_t *root = yaml_parse("config/config2.yml");
  node_t *node;

  UT_ASSERT_PTR_NOT_NULL(root)
  node = get_nodes(root,"Item List/item");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"keybord")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"mouse")

  node = get_nodes(root,"Item List/price");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"100")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"50")

  node = NODE_NEXT(node);
  UT_ASSERT_PTR_NULL(node)

  if(root)
  {
    node_free(root);
  }
}

/** Test with nested sequence */
void test_nested_sequence()
{
  node_t *root = yaml_parse("config/config3.yml");
  node_t *node;

  UT_ASSERT_PTR_NOT_NULL(root)
  node = get_nodes(root,"Item List/item");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"keybord")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"mouse")
  node = NODE_NEXT(node);

  node = get_nodes(root,"Item List/price");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"100")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"50")
  node = NODE_NEXT(node);

  node = get_nodes(root,"Item List/model/company");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"iball")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"sony")
  node = NODE_NEXT(node);

  node = get_nodes(root,"Item List/model/keys");
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"58")
  node = NODE_NEXT(node);
  UT_ASSERT_STRING_EQUAL(NODE_VALUE(node),"54")
  node = NODE_NEXT(node);

  UT_ASSERT_STRING_EQUAL(get_node_value(root,"Billing Address/Item"),"cpu")
  UT_ASSERT_STRING_EQUAL(get_node_value(root,"Billing Address/price"),"1500")


  if(root)
  {
    node_free(root);
  }
}

/** Test with test file */
void test_text_file()
{
  node_t* root = yaml_parse("config/config4.yml");

  UT_ASSERT_PTR_NULL(root)
}

void test_space_separated_value()
{
  node_t* root = yaml_parse("config/config5.yml");

  UT_ASSERT_PTR_NOT_NULL(root)
  UT_ASSERT_STRING_EQUAL(get_node_value(root,"item"),"mouse keybord")
  UT_ASSERT_STRING_EQUAL(get_node_value(root,"price"),"100")
  UT_ASSERT_PTR_NULL(get_node_value(root,"code"))

  if(root)
  {
    node_free(root);
  }
}

void test_yaml_parser()
{
  UT_TEST_START
  UT_RUN_TEST(test_key_value_pairs)
  UT_RUN_TEST(test_sequence)
  UT_RUN_TEST(test_nested_sequence)
  UT_RUN_TEST(test_text_file)
  UT_RUN_TEST(test_space_separated_value);
  UT_TEST_END("YAML test cases")
}

