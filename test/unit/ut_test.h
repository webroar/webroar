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
 *                 Unit Test APIs
 *****************************************************************************/

#ifndef UT_TEST_H_
#define UT_TEST_H_

#define TEST_LOG_FILE "test.log"  //Result is logged in this file

/** Assertion functions */
void ut_assert_fun(int test, char* val1, char* val2, const char* file_name, const char* func, int line);
void ut_assert_int_fun(int test, int val1, int val2, const char* file_name, const char* func, int line);
void ut_test_end_fun(const char* testcase, const char* file_name);

/** Unit Test Macros */
#define UT_TEST_START ut_failed = ut_passed = ut_total = 0;
#define UT_TEST_END(testcase) ut_test_end_fun(testcase, __FILE__);
#define UT_ASSERT(test, val1, val2) ut_assert_fun(test,val1, val2, __FILE__, __FUNCTION__, __LINE__);
#define UT_ASSERT_INT(test, val1, val2) ut_assert_int_fun(test,val1, val2, __FILE__, __FUNCTION__, __LINE__);
#define UT_RUN_TEST(test) test();

#define UT_ASSERT_INT_EQUAL(val1, val2) UT_ASSERT_INT((val1==val2), val1, val2)
#define UT_ASSERT_INT_NOT_EQUAL(val1, val2) UT_ASSERT_INT((val1!=val2), val1, val2)

#define UT_ASSERT_STRING_EQUAL(val1, val2) UT_ASSERT(!strcmp(val1, val2), val1, val2)
#define UT_ASSERT_STRING_NOT_EQUAL(val1, val2) UT_ASSERT(strcmp(val1, val2), val1, val2)

#define UT_ASSERT_STRNCMP_EQUAL(val1, val2, len) UT_ASSERT(!strncmp(val1, val2, len), val1, val2)
#define UT_ASSERT_STRNCMP_NOT_EQUAL(val1, val2, len) UT_ASSERT(strncmp(val1, val2, len), var1, var2)

#define UT_ASSERT_PTR_NOT_NULL(ptr) UT_ASSERT_INT((ptr!=NULL), 0, 0)
#define UT_ASSERT_PTR_NULL(ptr) UT_ASSERT_INT((ptr==NULL), 0, 0)

#endif /*UT_TEST_H_*/

