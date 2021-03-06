(*
 * expr.ml
 *
 * bintrans
 *
 * Copyright (C) 2004 Mark Probst
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *)

let make_bind2 bind1 bind2 =
  fun value1 value2 fn ->
    bind1 value1
      (fun value1_expr ->
	bind2 value2
	  (fun value2_expr ->
	    fn value1_expr value2_expr))

let make_bind3 bind1 bind2 bind3 =
  fun value1 value2 value3 fn ->
    (make_bind2 bind1 bind2) value1 value2
      (fun value1_expr value2_expr ->
	bind3 value3
	  (fun value3_expr ->
	    fn value1_expr value2_expr value3_expr))
