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
 *               Unit Test implementation
 *****************************************************************************/

#include <stdio.h>
#include "ut_test.h"

/** Number of failed test cases */
int ut_failed;

/** Number of passed test cases */
int ut_passed;

/** Total number of test cases */
int ut_total;

/** Assertion for integer value */
void ut_assert_int_fun(int test, int val1, int val2, const char* file_name,
    const char* func, int line) {
  ut_total++;
  if (!test) {
    FILE *file = fopen(TEST_LOG_FILE, "a+");
    if (file) {
      fprintf(
          file,
          "FAILED >> File : %s, Test : %s, line : %d, value1 : %d, value2 : %d\n",
          file_name, func, line, val1, val2);
      fclose(file);
    }
    ut_failed++;
  } else {
    ut_passed++;
  }

}

/** Basic assertion function */
void ut_assert_fun(int test, char* val1, char* val2, int len,
    const char* file_name, const char* func, int line) {
  int result;
  ut_total++;

  if (val1 && val2) {
    result = (len ? strncmp(val1, val2, len) : strcmp(val1, val2));
    test = (test ? result : !result);
  } else {
    test = 0;
  }

  if (!test) {
    FILE *file = fopen(TEST_LOG_FILE, "a+");
    if (file) {
      fprintf(
          file,
          "FAILED >> File : %s, Test : %s, line : %d, value1 : %s, value2 : %s\n",
          file_name, func, line, val1, val2);
      fclose(file);
    }
    ut_failed++;
  } else {
    ut_passed++;
  }
}

/** Function called at the end of unit test to report test result */
void ut_test_end_fun(const char* testcase, const char* file_name) {
  FILE *file = fopen(TEST_LOG_FILE, "a+");
  if (file) {
    printf("%s => Passed %d, Failed %d\n", testcase, ut_passed, ut_failed);
    fprintf(file, "REPORT >> File : %s,Test passed : %d, Test failed :%d\n",
        file_name, ut_passed, ut_failed);
    fclose(file);
  }
}
