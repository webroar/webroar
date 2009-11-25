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
#ifndef WR_MACRO_H_
#define WR_MACRO_H_

#define TRUE     1
#define FALSE   0
// In most of the cases, in lack of memory, we are not continue to run process. Its better to
// check return value to malloc here and exit gracefully, rather than checking for !NULL here and there
#define wr_malloc(type) (type*)malloc(sizeof(type))
#define wr_min(a,b) ((a)<(b)?(a):(b))
#define wr_ramp(a) (a > 0 ? a : 0)
typedef unsigned short   wr_u_short;
typedef unsigned int     wr_u_int;
typedef unsigned long   wr_u_long;

#endif /*WR_MACRO_H_*/
