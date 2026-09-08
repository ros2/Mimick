/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2026 openKylin ROS-SIG <ros@lists.openkylin.top>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * LoongArch64 (LP64D) trampoline, modeled on trampoline-riscv64.S from
 * https://github.com/ros2/Mimick/pull/31 (author: Ziyao <ziyao@disroot.org>).
 * Register use mirrors the RISC-V file one to one: integer arguments in
 * a0-a7, floating point arguments in fa0-fa7, both saved to the stack in
 * the same slot order, so the arch-independent C side sees an identical
 * frame layout.
 */

#include "mangling.h"

	.global		MANGLE(mmk_trampoline), MANGLE(mmk_trampoline_end)
MANGLE(mmk_trampoline):

/*
 *	struct mmk_stub*		8bytes
 *	plt_fn*				8bytes
 *	trampoline code			...
 *	=>
 *		start: pcaddi t0, 1	4bytes (t0 = start + 4)
 */
start:
	pcaddi	$t0,	1		// 4 bytes for an instruction
next:
	addi.d	$sp,	$sp,	-8 * 20		// a0 - a7 + t0 + ra +
							// *struct mmk_stub aligned to
							// 16bytes
	st.d	$t0,	$sp,	0		// 0(sp) label next
	ld.d	$t0,	$t0,	-20		// t0 -> struct mmk_stub*
	st.d	$t0,	$sp,	8		// 8(sp) struct mmk_stub*
	st.d	$ra,	$sp,	16

	/*	Save caller arguments	*/
	st.d	$a0,	$sp,	24
	st.d	$a1,	$sp,	32
	st.d	$a2,	$sp,	40
	st.d	$a3,	$sp,	48
	st.d	$a4,	$sp,	56
	st.d	$a5,	$sp,	64
	st.d	$a6,	$sp,	72
	st.d	$a7,	$sp,	80
	fst.d	$fa0,	$sp,	88
	fst.d	$fa1,	$sp,	96
	fst.d	$fa2,	$sp,	104
	fst.d	$fa3,	$sp,	112
	fst.d	$fa4,	$sp,	120
	fst.d	$fa5,	$sp,	128
	fst.d	$fa6,	$sp,	136
	fst.d	$fa7,	$sp,	144
	//	8 bytes padding

	or	$a0,	$t0,	$zero		// a0 = struct mmk_stub*
	ld.d	$ra,	$t0,	8		// ctx_set
	jirl	$ra,	$ra,	0

	ld.d	$t0,	$sp,	8		// t0 = struct mmk_stub*

	ld.d	$ra,	$t0,	0		// ctx_asked
	jirl	$ra,	$ra,	0
	or	$t0,	$a0,	$zero		// t0 = ctx_asked result

	/*	Restore caller arguments	*/
	ld.d	$a0,	$sp,	24
	ld.d	$a1,	$sp,	32
	ld.d	$a2,	$sp,	40
	ld.d	$a3,	$sp,	48
	ld.d	$a4,	$sp,	56
	ld.d	$a5,	$sp,	64
	ld.d	$a6,	$sp,	72
	ld.d	$a7,	$sp,	80
	fld.d	$fa0,	$sp,	88
	fld.d	$fa1,	$sp,	96
	fld.d	$fa2,	$sp,	104
	fld.d	$fa3,	$sp,	112
	fld.d	$fa4,	$sp,	120
	fld.d	$fa5,	$sp,	128
	fld.d	$fa6,	$sp,	136
	fld.d	$fa7,	$sp,	144

	bnez	$t0,	return_context
	/*	stub trampoline jump	*/
	ld.d	$t0,	$sp,	0		// label next
	ld.d	$t0,	$t0,	-12		// plt_fn*
	ld.d	$ra,	$sp,	16
	addi.d	$sp,	$sp,	8 * 20
	jirl	$zero,	$t0,	0		// jump to plt_fn

return_context:
	ld.d	$t0,	$sp,	8		// struct mmk_stub*
	ld.d	$ra,	$t0,	16		// ctx_get()
	jirl	$ra,	$ra,	0
	ld.d	$ra,	$sp,	16
	addi.d	$sp,	$sp,	8 * 20
	jirl	$zero,	$ra,	0		// ret

MANGLE(mmk_trampoline_end):
	nop

	.section .note.GNU-stack,"",@progbits
