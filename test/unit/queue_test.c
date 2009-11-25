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
 *             Circular Queue Unit Test Cases
 *****************************************************************************/

#include <stdio.h>
#include <ut_test.h>
#include <test.h>
#include <wr_helper.h>

/** Test queue */
void test_queue()
{
  UT_TEST_START
  wr_queue_t* queue = wr_queue_new(5);
  int retval, i, *ptr;

  UT_ASSERT_INT_EQUAL(WR_QUEUE_SIZE(queue),0)

  for(i = 0; i < 5; i++)
  {
    ptr = wr_malloc(int);
    *ptr = i+1;
    retval = wr_queue_insert(queue, ptr);
    UT_ASSERT_INT_EQUAL(retval,0)
  }

  retval = WR_QUEUE_SIZE(queue);
  UT_ASSERT_INT_EQUAL(retval, 5)

  ptr = wr_malloc(int);
  *ptr = i+1;

  retval = wr_queue_insert(queue, ptr);
  UT_ASSERT_INT_EQUAL(retval,-1)
  free(ptr);
  retval = WR_QUEUE_SIZE(queue);
  UT_ASSERT_INT_EQUAL(retval, 5)

  for(i = 0; i < 5; i++)
  {
    ptr = wr_queue_fetch(queue);
    UT_ASSERT_INT_EQUAL(*ptr,i+1);
    free(ptr);
  }

  ptr = wr_queue_fetch(queue);
  UT_ASSERT_PTR_NULL(ptr)
  retval = WR_QUEUE_SIZE(queue);
  UT_ASSERT_INT_EQUAL(retval,0)

  ptr = wr_malloc(int);
  *ptr = i+1;
  retval = wr_queue_insert(queue, ptr);

  UT_ASSERT_INT_EQUAL(retval,0)
  retval = WR_QUEUE_SIZE(queue);
  UT_ASSERT_INT_EQUAL(retval,1)

  retval = wr_queue_remove(queue, ptr);
  UT_ASSERT_INT_EQUAL(retval,0)

  retval = wr_queue_remove(queue, ptr);
  UT_ASSERT_INT_EQUAL(retval,-1)

  ptr = wr_queue_fetch(queue);
  UT_ASSERT_PTR_NULL(ptr)

  free(ptr);
  free(queue);
  UT_TEST_END("Queue test cases")
}
