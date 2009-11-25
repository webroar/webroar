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
 *             Utility function Unit Test Cases
 *****************************************************************************/
#include <stdio.h>
#include <string.h>
#include <wr_util.h>
#include <ut_test.h>
#include <test.h>

/** test itoa */
void test_hash()
{
  unsigned long hash1, hash2;

  hash1 = uri_hash("admin-panel");
  hash2 = uri_hash("admin-panel");

  UT_ASSERT_INT_EQUAL(hash1, hash2);
  hash2 = uri_hash("admin-Panel");
  UT_ASSERT_INT_NOT_EQUAL(hash1, hash2);

  hash1 = uri_hash_len("/admin-panle",5);
  hash2 = uri_hash_len("/Admin-panle",5);

  UT_ASSERT_INT_EQUAL(hash1, hash2);

  hash1 = uri_hash_len("admin-panle",5);
  hash2 = uri_hash_len("admin-Panle",5);

  UT_ASSERT_INT_EQUAL(hash1, hash2);

}

void test_util()
{
  UT_TEST_START
  UT_RUN_TEST(test_hash)
  UT_TEST_END("Util test cases")
}
