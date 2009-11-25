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
 *               SCGI Unit Test Case
 *****************************************************************************/

#include <stdio.h>
#include <string.h>
#include <wr_scgi.h>
#include <ut_test.h>
#include <test.h>

/** Build SCGI request without headers & body */
void build_without_header_body()
{
  scgi_t* scgi = scgi_new();
  scgi_build(scgi);

  UT_ASSERT_STRNCMP_EQUAL("24:CONTENT_LENGTH\0000\0SCGI\0001\0,", 
          scgi->header + scgi->start_offset, 28)
  UT_ASSERT_INT_EQUAL(scgi->length, 28)

  scgi_free(scgi);
}

/** Build SCGI request only with header */
void build_only_with_header()
{
  scgi_t* scgi = scgi_new();
  scgi_header_add(scgi,"METHOD", strlen("METHOD"), "TEST", strlen("TEST"));
  scgi_build(scgi);

  UT_ASSERT_STRNCMP_EQUAL("36:CONTENT_LENGTH\0000\0SCGI\0001\0METHOD\0TEST\0,",
          scgi->header + scgi->start_offset, 40)
  UT_ASSERT_INT_EQUAL(scgi->length, 40)

  scgi_free(scgi);
}

/** Build SCGI request only with body */
void build_only_with_body()
{
  scgi_t* scgi = scgi_new();
  scgi_body_add(scgi, "Hello world!!!\r\nHi.\0",20);
  scgi_build(scgi);

  UT_ASSERT_STRNCMP_EQUAL("25:CONTENT_LENGTH\00020\0SCGI\0001\0,",
          scgi->header + scgi->start_offset, 29)
  UT_ASSERT_STRNCMP_EQUAL("Hello world!!!\r\nHi.\0",
          scgi->body, 20) 
  UT_ASSERT_INT_EQUAL(scgi->length, 49)

  scgi_free(scgi);
}

/** Build SCGI request with body & headers */
void build_with_header_body()
{
  scgi_t* scgi = scgi_new();
  scgi_header_add(scgi,"METHOD",strlen("METHOD"), "TEST", strlen("TEST"));
  scgi_body_add(scgi,"Hello world!!!\r\nHi.\0",20);
  scgi_build(scgi);
  
  UT_ASSERT_STRNCMP_EQUAL("37:CONTENT_LENGTH\00020\0SCGI\0001\0METHOD\0TEST\0,",
          scgi->header + scgi->start_offset, 41)
  UT_ASSERT_STRNCMP_EQUAL("Hello world!!!\r\nHi.\0",
          scgi->body, 20) 
  UT_ASSERT_INT_EQUAL(scgi->length, 61)

  scgi_free(scgi);
}

/** Parse SCGI request having only headers */
void parse_with_only_header()
{
  scgi_t* scgi = scgi_parse("24:CONTENT_LENGTH\0000\0SCGI\0001\0,",28);
  scgi_header_t* header = scgi->header_list;

  UT_ASSERT_PTR_NOT_NULL(header)
  
  UT_ASSERT_STRING_EQUAL(scgi->header + header->field_offset,"SCGI")
  UT_ASSERT_STRING_EQUAL(scgi->header + header->value_offset,"1")
  header = header->next;
  UT_ASSERT_STRING_EQUAL(scgi->header + header->field_offset,"CONTENT_LENGTH")
  UT_ASSERT_STRING_EQUAL(scgi->header + header->value_offset,"0")
  header = header->next;
  UT_ASSERT_PTR_NULL(header)

  UT_ASSERT_INT_EQUAL(scgi->body_length, 0)
  UT_ASSERT_PTR_NULL(scgi->body)

  scgi_free(scgi);
}

/** Parse SCGI request with request length less then actual length */
void parse_with_len_less_than_actual_len()
{
  scgi_t* scgi = scgi_parse("24:CONTENT_LENGTH\0000\0SCGI\0001\0,",10);

  UT_ASSERT_PTR_NULL(scgi)
}

/** Parse SCGI request with request length greater then actual length */
void parse_with_len_greated_than_actual_len()
{
  scgi_t* scgi = scgi_parse("24:CONTENT_LENGTH\0000\0SCGI\0001\0,",40);
  scgi_header_t* header = scgi->header_list;

  UT_ASSERT_STRING_EQUAL(scgi->header + header->field_offset,"SCGI")
  UT_ASSERT_STRING_EQUAL(scgi->header + header->value_offset,"1")
  header = header->next;
  UT_ASSERT_STRING_EQUAL(scgi->header + header->field_offset,"CONTENT_LENGTH")
  UT_ASSERT_STRING_EQUAL(scgi->header + header->value_offset,"0")
  header = header->next;

  UT_ASSERT_PTR_NULL(header)

  UT_ASSERT_INT_EQUAL(scgi->body_length, 12)
  UT_ASSERT_PTR_NOT_NULL(scgi->body)

  scgi_free(scgi);
}

/** Parse SCGI request having only request body */
void parse_with_only_body()
{
  scgi_t* scgi = scgi_parse("0:,Hi\r\nhi",9);
  scgi_header_t* header = scgi->header_list;

  UT_ASSERT_PTR_NULL(header)

  UT_ASSERT_INT_EQUAL(scgi->body_length, 6)
  UT_ASSERT_STRNCMP_EQUAL(scgi->body,"Hi\r\nhi",6)

  scgi_free(scgi);
}

/** Parse SCGI request having invalid header value pair */
void parse_with_invalid_header_value_pair()
{
  scgi_t* scgi = scgi_parse("24:CONTENT_LENGTH\0000\0SCGI\000,",26);

  UT_ASSERT_PTR_NULL(scgi)
}

/** Parse SCGI request without header length separator */
void parse_without_header_len_seperator()
{
  scgi_t* scgi = scgi_parse("24CONTENT_LENGTH\0000\0SCGI\0001\0,",27);

  UT_ASSERT_PTR_NULL(scgi)
}

/** Parse SCGI request without request body separator */
void parse_without_body_separator()
{
  scgi_t* scgi = scgi_parse("24:CONTENT_LENGTH\0000\0SCGI\0001\0",28);

  UT_ASSERT_PTR_NULL(scgi)
}


void test_scgi()
{
  UT_TEST_START

  UT_RUN_TEST(build_without_header_body)
  UT_RUN_TEST(build_with_header_body)
  UT_RUN_TEST(build_only_with_header)
  UT_RUN_TEST(build_only_with_body)
  UT_RUN_TEST(parse_without_header_len_seperator)
  UT_RUN_TEST(parse_without_body_separator)
  UT_RUN_TEST(parse_with_only_header)
  UT_RUN_TEST(parse_with_only_body)
  UT_RUN_TEST(parse_with_len_less_than_actual_len)
  UT_RUN_TEST(parse_with_len_greated_than_actual_len)
  UT_RUN_TEST(parse_with_invalid_header_value_pair)

  UT_TEST_END("SCGI test cases")
}

