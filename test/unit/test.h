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
 *               List of Unit Test Cases
 *****************************************************************************/

#ifndef TEST_H_
#define TEST_H_

extern int ut_failed;
extern int ut_total;
extern int ut_passed;

/** SCGI unit test cases*/
void test_scgi();

/** YAML parser unit test cases*/
void test_yaml_parser();

/** Queue unit test cases*/
void test_queue();

/** Util unit test cases*/
void test_util();

/** Run all tests **/
void run_test();

#endif /*TEST_H_*/
