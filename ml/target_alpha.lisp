;; target_alpha.lisp

;; bintrans

;; Copyright (C) 2004 Mark Probst

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 675 Massachusetts Avenue; Cambridge, MA 02139, USA.

(setq *matchers* '())

(defmacro defopmatcher (name rhs c-format)
  (let ((a-rhs (subst '(register ?ra) 'a rhs)))
    `(progn
      (defmatcher ,name
	  (set ?rs ,(subst '(register ?rb) 'b a-rhs))
	1
	(,(format nil "~~A = ~A;" c-format) rs ra rb)
	(,(format nil "emit(COMPOSE_~A(~~A, ~~A, ~~A));" name) ra rb rs))
      (defmatcher ,(intern (string-concat (string name) "_IMM"))
	  (set ?rs ,(subst '(any-int ?i) 'b a-rhs))
	(when (int-zero-p 8 (lshiftr 8 i 8))
	  1)
	(,(format nil "~~A = ~A;" c-format) rs ra i)
	(,(format nil "emit(COMPOSE_~A_IMM(~~A, ~~A, ~~A));" name) ra i rs)))))

; we don't add the immediate version of addq because it performs a subset of
; the functionality of lda
(defmatcher addq
  (set ?rs (+i (register ?ra) (register ?rb)))
  1
  ("~A = ~A + ~A;" rs ra rb)
  ("emit(COMPOSE_ADDQ(~A, ~A, ~A));" ra rb rs))

(defopmatcher addl (sex 4 (+i a b)) "sex_32(~A + ~A)")

(defmatcher addl-31
  (set ?rs (sex 4 (register ?ra)))
  1
  ("~A = sex_32(~A);" rs ra)
  ("emit(COMPOSE_ADDL(~A, 31, ~A));" ra rs))

(defopmatcher eqv (bit-xor a (bit-neg b)) "~A ^ ~~(~A)")

(defmatcher lda
  (set ?rs (+i (register ?ra) (any-int ?i)))
  (when (zero-or-full-p 8 (ashiftr 8 i 15))
    1)
  ("~A = ~A + ~A;" rs ra i)
  ("emit(COMPOSE_LDA(~A, ~A & 0xffff, ~A));" rs i ra))

(defmatcher lda-31
  (set ?rs (any-int ?i))
  (when (zero-or-full-p 8 (ashiftr 8 i 15))
    1)
  ("~A = ~A;" rs i)
  ("emit(COMPOSE_LDA(~A, ~A & 0xffff, 31));" rs i))

(defmatcher ldah
  (set ?rs (+i (register ?ra) (any-int ?i)))
  (when (and (int-zero-p 8 (bit-and i #xffff))
	     (zero-or-full-p 8 (ashiftr 8 i 31)))
    1)
  ("~A = ~A + ~A;" rs ra i)
  ("emit(COMPOSE_LDAH(~A, (~A >> 16) & 0xffff, ~A));" rs i ra))

(defmatcher ldah-31
  (set ?rs (any-int ?i))
  (when (and (int-zero-p 8 (bit-and i #xffff))
	     (zero-or-full-p 8 (ashiftr 8 i 31)))
    1)
  ("~A = ~A;" rs i)
  ("emit(COMPOSE_LDAH(~A, (~A >> 16) & 0xffff, 31));" rs i))

(defmatcher load-int
  (set ?rs (any-int ?i))
  2
  ("~A = ~A;" rs i)
  ("emit_load_integer_64(~A, ~A);" rs i))

(defmatcher mov
  (set ?rs (register ?ra))
  1
  ("~A = ~A;" rs ra)
  ("emit(COMPOSE_MOV(~A, ~A));" ra rs))

(defopmatcher and (bit-and a b) "~A & ~A")

(defmatcher bic-imm-for-and
  (set ?rs (bit-and (register ?ra) (any-int ?i)))
  (when (full-mask-p 8 (ashiftr 8 i 8))
    1)
  ("~A = ~A & ~A;" rs ra i)
  ("emit(COMPOSE_BIC_IMM(~A, unary_BitNeg(~A), ~A));" ra i rs))

(defmatcher zapnot-imm
  (set ?rs (bit-and (register ?ra) (any-int ?i)))
  (when (user-op "IsMaskMask" i 8)
    1)
  ("~A = ~A & ~A;" rs ra i)
  ("emit(COMPOSE_ZAPNOT_IMM(~A, reverse_maskmask(~A, 8), ~A));" ra i rs))

(defopmatcher bis (bit-or a b) "~A | ~A")
(defopmatcher bic (bit-and a (bit-neg b)) "~A | ~A")

(defmatcher neg
  (set ?rs (bit-neg (register ?rb)))
  1
  ("~A = ~~~A;" rs rb)
  ("emit(COMPOSE_NEG(~A, ~A));" rb rs))

(defopmatcher sll (shiftl a b) "~A << ~A")

(defmatcher zapnot-imm-srl
  (set ?rs (lshiftr (?width (1 2 4)) (register ?ra) (register ?rb)))
  2
  ("~A = (~A & width_mask(~A)) >> ~A;" rs ra width rb)
  ("emit(compose_width_zapnot(~A, ~A, ~A)); emit(COMPOSE_SRL(~A, ~A, ~A));" ra width rs rs rb rs))

(defmatcher zapnot-imm-srl-imm
  (set ?rs (lshiftr (?width (1 2 4)) (register ?ra) (any-int ?i)))
  2
  ("~A = (~A & width_mask(~A)) >> ~A;" rs ra width i)
  ("emit(compose_width_zapnot(~A, ~A, ~A)); emit(COMPOSE_SRL_IMM(~A, ~A, ~A));" ra width rs rs i rs))

(defopmatcher srl (lshiftr 8 a b) "~A >> ~A")

(defmatcher extbl-imm-8
  (set ?rs (bit-and (lshiftr 8 (register ?ra) (any-int ?i)) #xff))
  (when (and (int-zero-p 8 (bit-and i 7))
	     (int-zero-p 8 (lshiftr 8 i 6)))
    1)
  ("~A = (~A >> ~A) & 0xff;" rs ra i)
  ("emit(COMPOSE_EXTBL_IMM(~A, ~A >> 3, ~A));" ra i rs))

(defmatcher extbl-imm-4
  (set ?rs (bit-and (lshiftr 4 (register ?ra) (any-int ?i)) #xff))
  (when (and (int-zero-p 8 (bit-and i 7))
	     (int-zero-p 8 (lshiftr 8 i 5)))
    1)
  ("~A = (~A >> ~A) & 0xff;" rs ra i)
  ("emit(COMPOSE_EXTBL_IMM(~A, ~A >> 3, ~A));" ra i rs))

(defmatcher extwl-imm-8
  (set ?rs (bit-and (lshiftr 8 (register ?ra) (any-int ?i)) #xffff))
  (when (and (int-zero-p 8 (bit-and i 7))
	     (int-zero-p 8 (lshiftr 8 i 6)))
    1)
  ("~A = (~A >> ~A) & 0xffff;" rs ra i)
  ("emit(COMPOSE_EXTWL_IMM(~A, ~A >> 3, ~A));" ra i rs))

(defmatcher extwl-imm-4
  (set ?rs (bit-and (lshiftr 4 (register ?ra) (any-int ?i)) #xffff))
  (when (and (int-zero-p 8 (bit-and i 7))
	     (int-zero-p 8 (lshiftr 8 i 5)))
    1)
  ("~A = (~A >> ~A) & 0xffff;" rs ra i)
  ("emit(COMPOSE_EXTWL_IMM(~A, ~A >> 3, ~A));" ra i rs))

(defmatcher ldbu
  (set ?ra (load-byte (register ?rb)))
  2
  ("~A = mem_load_8(~A);" ra rb)
  ("emit(COMPOSE_LDBU(~A, 0, ~A));" ra rb))

(defmatcher ldbu-disp
  (set ?ra (load-byte (+i (register ?rb) (any-int ?disp))))
  (when (zero-or-full-p 8 (ashiftr 8 disp 16))
    2)
  ("~A = mem_load_8(~A + ~A);" ra rb disp)
  ("emit(COMPOSE_LDBU(~A, ~A & 0xffffLL, ~A));" ra disp rb))

(defmatcher ldbu-zex
  (set ?ra (zex 1 (load-byte (register ?rb))))
  2
  ("~A = mem_load_8(~A);" ra rb)
  ("emit(COMPOSE_LDBU(~A, 0, ~A));" ra rb))

(defmatcher ldbu-zex-disp
  (set ?ra (zex 1 (load-byte (+i (register ?rb) (any-int ?disp)))))
  (when (zero-or-full-p 8 (ashiftr 8 disp 16))
    2)
  ("~A = mem_load_8(~A + ~A);" ra rb disp)
  ("emit(COMPOSE_LDBU(~A, ~A & 0xffffLL, ~A));" ra disp rb))

(defmatcher sextb
  (set ?rs (sex 1 (register ?rb)))
  1
  ("~A = sex_8(~A);" rs rb)
  ("emit(COMPOSE_SEXTB(~A, ~A));" rb rs))

(defmatcher sextw
  (set ?rs (sex 2 (register ?rb)))
  1
  ("~A = sex_16(~A);" rs rb)
  ("emit(COMPOSE_SEXTW(~A, ~A));" rb rs))

(defopmatcher subq (-i a b) "~A - ~A")

(defopmatcher xor (bit-xor a b) "~A ^ ~A")

(defmatcher zapnot-imm-1
  (set ?rs (zex 1 (register ?ra)))
  1
  ("~A = zex_8(~A);" rs ra)
  ("emit(COMPOSE_ZAPNOT_IMM(~A, 1, ~A));" ra rs))

(defmatcher zapnot-imm-3
  (set ?rs (zex 2 (register ?ra)))
  1
  ("~A = zex_16(~A);" rs ra)
  ("emit(COMPOSE_ZAPNOT_IMM(~A, 3, ~A));" ra rs))

(defmatcher zapnot-imm-15
  (set ?rs (zex 4 (register ?ra)))
  1
  ("~A = zex_32(~A);" rs ra)
  ("emit(COMPOSE_ZAPNOT_IMM(~A, 15, ~A));" ra rs))

(defmatcher zapnot-imm-sll-srl-imm-bis
  (set ?rs (rotl 4 (register ?ra) (register ?rb)))
  4
  ("{ word_64 tmp = (~A & 0xffffffff) << ~A; ~A = tmp | (tmp >> 32); }" ra rb rs)
  ("{ reg_t tmp;
      emit(COMPOSE_ZAPNOT_IMM(~A, 15, ~A));
      emit(COMPOSE_SLL(~A, ~A, ~A));
      tmp = alloc_tmp_integer_reg();
      emit(COMPOSE_SRL_IMM(~A, 32, tmp));
      emit(COMPOSE_BIS(~A, tmp, ~A));
      free_tmp_integer_reg(tmp); }"
   ra rs				;zapnot_imm
   rs rb rs				;sll
   rs					;srl
   rs rs))				;bis
