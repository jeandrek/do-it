;;; This file is part of do-it.

;;; do-it is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.

;;; do-it is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with do-it.  If not, see <http://www.gnu.org/licenses/>.

(define wordsize 4)

;;; Common Lisp FORMAT-style output.
(define (emit port fmt . args)
  (let loop ((lst (string->list fmt))
             (args args))
    (if (not (null? lst))
        (let ((char (car lst)))
          (if (char=? char #\~)
              (if (char=? (cadr lst) #\~)
                  (begin
                    (write-char #\~ port)
                    (loop (cddr lst) args))
                  (begin
                    (case (cadr lst)
                      ((#\c) (write-char (car args) port))
                      ((#\v) (write (car args) port))
                      ((#\n) (display (number->string (car args)) port))
                      ((#\s) (display (car args) port)))
                    (loop (cddr lst) (cdr args))))
              (begin
                (write-char char port)
                (loop (cdr lst) args))))))
  (newline port))

(define (special-form? exp)
  (and (pair? exp)
       (get-special-form (car exp))))

(define (quotation? exp)
  (tagged-list? exp 'quote))

(define (application? exp)
  (pair? exp))

(define (variable? exp) (symbol? exp))

;;; Return #T if OBJ is an immediate
;;; object and #F otherwise.
(define (immediate? obj)
  (or (integer? obj)
      (boolean? obj)
      (char? obj)))

;;; Return #T if EXP is a self-evaluating
;;; expession and #F otherwise.
(define (self-evaluating? exp)
  (or (immediate? exp)
      (string? exp)))

;;; Return #T if OBJ is a pair and the
;;; CAR of OBJ is TAG and #F otherwise.
(define (tagged-list? obj tag)
  (and (pair? obj)
       (eq? (car obj) tag)))

;;; Return the immediate representation of OBJ.
(define (immediate-rep obj)
  (cond ((number? obj) obj)
        ((boolean? obj) (if obj 1 0))
        ((char? obj) (char->integer obj))))

;;; Port for constants
(define *data* #f)
;;; Port for procedures
(define *procedures* #f)

;;; Stack of the stack index and how many items
;;; need to be popped of the stack by CLEANUP
(define *stack* '())

;;; #T if compiling in the global environment,
;;; #F otherwise.
(define *toplevel* #f)

;;; Return a new unique label containing NAME.
(define make-label
  (let ((count 0))
    (lambda (name)
      (set! count (+ count 1))
      (string-append name
                     "_"
                     (number->string count)))))

;;; Turn a Scheme symbol into an x86 symbol.
(define (mangle sym)
  (define (helper lst)
    (if (null? lst)
        '()
        (let ((char (car lst)))
          (cond ((char=? (car lst) #\-)
                 (cons #\_ (helper (cdr lst))))
                ((or (char-alphabetic? char)
                     (char-numeric? char))
                 (cons char (helper (cdr lst))))
                (else
                 (append
                  '(#\_)
                  (string->list (number->string (char->ascii-code char)))
                  (helper (cdr lst))))))))
  (list->string
   (helper (string->list (symbol->string sym)))))

(define ascii-table
  '((#\newline 10)
    (#\space 32)
    (#\! 33) (#\" 34) (#\# 35) (#\$ 36) (#\% 37) (#\& 38) (#\' 39)
    (#\( 40) (#\) 41) (#\* 42) (#\+ 43) (#\, 44) (#\- 45) (#\. 46)
    (#\/ 47) (#\0 48) (#\1 49) (#\2 50) (#\3 51) (#\4 52) (#\5 53)
    (#\6 54) (#\7 55) (#\8 56) (#\9 57) (#\: 58) (#\; 59) (#\< 60)
    (#\= 61) (#\> 62) (#\? 63) (#\@ 64) (#\A 65) (#\B 66) (#\C 67)
    (#\D 68) (#\E 69) (#\F 70) (#\G 71) (#\H 72) (#\I 73) (#\J 74)
    (#\K 75) (#\L 76) (#\M 77) (#\N 78) (#\O 79) (#\P 80) (#\Q 81)
    (#\R 82) (#\S 83) (#\T 84) (#\U 85) (#\V 86) (#\W 87) (#\X 88)
    (#\Y 89) (#\Z 90) (#\[ 91) (#\\ 92) (#\] 93) (#\^ 94) (#\_ 95)
    (#\` 96) (#\a 97) (#\b 98) (#\c 99) (#\d 100) (#\e 101) (#\f 102)
    (#\g 103) (#\h 104) (#\i 105) (#\j 106) (#\k 107) (#\l 108) (#\m 109)
    (#\n 110) (#\o 111) (#\p 112) (#\q 113) (#\r 114) (#\s 115) (#\t 116)
    (#\u 117) (#\v 118) (#\w 119) (#\x 120) (#\y 121) (#\z 122) (#\{ 123)
    (#\| 124) (#\} 135) (#\~ 136)))

(define (char->ascii-code char)
  (let ((pair (assv char ascii-table)))
    (if pair
        (cadr pair)
        (error "Not a valid character" char))))

(define *special-forms* '())

(define (put-special-form name proc)
  (let ((pair (assq name *special-forms*)))
    (if pair
        (set-cdr! pair proc)
        (set! *special-forms*
              (cons (cons name proc) *special-forms*)))))

(define (get-special-form name)
  (let ((pair (assq name *special-forms*)))
    (and pair (cdr pair))))

;;; Compile a datum.
(define (compile-datum obj port)
  (cond ((immediate? obj)
         (emit port "  movl $~n, %eax" (immediate-rep obj)))
        ((string? obj)
         (let ((label (make-label "string")))
           (emit *data* "~s:" label)
           (emit *data* "  .asciz ~v" obj)
           (emit port "  movl $~s, %eax" label)))
        (else
         (error "Unknown datum type" obj))))

(put-special-form 'quote
                  (lambda (exp port env)
                    (compile-datum (cadr exp) port)))

(define (compile-if exp port env)
  (let ((end-label (make-label "if_end"))
        (test (cadr exp))
        (conseq (caddr exp)))
    (if (null? (cdddr exp))
        ;; No alternative
        (begin
          (compile test port env)
          (emit port "  cmpl $0, %eax")
          (emit port "  je ~s" end-label)
          (compile conseq port env)
          (emit port "~s:" end-label))
        ;; Alternative
        (let ((alt-label (make-label "if_alt"))
              (alt (cadddr exp)))
          (compile test port env)
          (emit port "  cmpl $0, %eax")
          (emit port "  je ~s" alt-label)
          (compile conseq port env)
          (emit port "  jmp ~s" end-label)
          (emit port "~s:" alt-label)
          (compile alt port env)
          (emit port "~s:" end-label)))))

(put-special-form 'if compile-if)

(define (compile-while exp port env)
  (let ((loop-label (make-label "while_loop"))
        (test (cadr exp))
        (body (cddr exp)))
    (if (not (always-falsey? exp))
        (if (always-truthy? exp)
            ;; Infinite loop
            (begin
              (emit port "~s:" loop-label)
              (compile `(begin ,@body) port env)
              (emit port "  jmp ~s" loop-label))
            ;; Unknown loop length
            (let ((end-label (make-label "while_end")))
              (emit port "~s:" loop-label)
              (compile test port env)
              (emit port "  cmpl $0, %eax")
              (emit port "  je ~s" end-label)
              (compile `(begin ,@body) port env)
              (emit port "  jmp ~s" loop-label)
              (emit port "~s:" end-label))))))

(put-special-form 'while compile-while)

;;; Return #T if OBJ is considered falsey
;;; by do-it.
(define (falsey? obj)
  (or (eq? obj #f)
      (= obj 0)))

;;; Return #T if OBJ is considered truthy
;;; by do-it.
(define (truthy? obj)
  (not (falsey? obj)))

;;; Try to determine if EXP will always
;;; evaluate to a falsey value.
(define (always-falsey? exp)
  (cond ((self-evaluating? exp) (falsey? exp))
        ((quotation? exp) (falsey? (cadr exp)))
        (else #f)))

;;; Try to determine if EXP will always
;;; evaluate to a truthy value.
(define (always-truthy? exp)
  (cond ((self-evaluating? exp) (truthy? exp))
        ((quotation? exp) (truthy? (cadr exp)))
        (else #f)))

(define (compile-return exp port env)
  (if (pair? (cdr exp))
      (compile (cadr exp) port env))
  (emit port "  popl %ebp")
  (emit port "  ret"))

(put-special-form 'return compile-return)

(define (compile-begin exp port env)
  (for-each
   (lambda (x) (compile x port env))
   (cdr exp)))

(put-special-form 'begin compile-begin)

;;; Compile a procedure application.
(define (compile-application exp port env)
  (for-each
   (lambda (x)
     (compile x port env)
     (emit port "  pushl %eax"))
   (reverse (cdr exp)))
  (emit port "  call ~s" (mangle (car exp)))
  (for-each
   (lambda (x)
     (emit port "  addl $~n, %esp" wordsize))
   (cdr exp)))

;;; Emit code to pop variables off the stack at the end
;;; of a procedure or block.
(define (cleanup port)
  (let loop ((i (caar *stack*)))
    (if (> i 0)
        (begin
          (emit port "  addl $~n, %esp" wordsize)
          (loop (- i 1)))))
  (set! *stack* (cdr *stack*)))

(define (empty-environment)
  (list (cons '() '())))

;;; Get the assembly expession pointing to the value
;;; of the variable var from the environment env.
(define (environment-lookup env var)
  (if (null? env)
      (error "Unbound variable" var)
      (let loop ((vars (caar env))
                 (vals (cdar env)))
        (cond ((null? vars)
               (environment-lookup (cdr env) var))
              ((eq? (car vars) var) (car vals))
              (else
               (loop (cdr vars)
                     (cdr vals)))))))

;;; Define the variable var to be the assembly
;;; expession val in the frame frame.
(define (frame-define! frame var val)
  (let loop ((vars (car frame))
             (vals (cdr frame)))
    (cond ((null? vars)
           ;; The frame doesn't already have a variable
           ;; of this name, create a new binding.
           (set-car! frame (cons var (car frame)))
           (set-cdr! frame (cons val (cdr frame))))
          ((eq? (car vars) var)
           ;; The frame already has a variable of this
           ;; name, replace it.
           (set-car! vals val))
          (else
           (loop (cdr vars) (cdr vals))))))

;;; Define the variable var to be the assembly
;;; expession val in the environment env.
(define (environment-define! env var val)
  (frame-define! (car env) var val))

(define (compile-defproc exp port env)
  (let ((name (mangle (cadr exp)))
        (params (caddr exp))
        (body (cdddr exp))
        (new-env (cons (cons '() '()) env))
        (old-toplevel *toplevel*))
    (emit *procedures* "  .globl ~s" name)
    (emit *procedures* "~s:" name)
    (emit *procedures* "  pushl %ebp")
    (emit *procedures* "  movl %esp, %ebp")
    (set! *stack* (cons (cons 0 0) *stack*))
    (set! *toplevel* #f)
    ;; Bind parameters to arguments.
    (let loop ((i (* wordsize 2))
               (params params))
      (if (not (null? params))
          (begin
            (environment-define! new-env (car params)
             (string-append (number->string i) "(%ebp)"))
            (loop (+ i wordsize) (cdr params)))))
    ;; Compile the procedure body.
    (compile `(begin ,@body) *procedures* new-env)
    ;; Emit cleanup code.
    (cleanup *procedures*)
    (emit *procedures* "  popl %ebp")
    (emit *procedures* "  ret")
    (set! *toplevel* old-toplevel)))

(put-special-form 'defproc compile-defproc)

(define (compile-defvar exp port env)
  (if *toplevel*
      ;; Define a global variable
      (let ((label (make-label "variable")))
        (emit *data* "~s:" label)
        (emit *data* "  .fill 1, ~n, 0" wordsize)
        (if (pair? (cddr exp))
            (begin
              (compile (caddr exp) port env)
              (emit port "  movl %eax, ~s" label)))
        (environment-define! env (cadr exp) label))
      ;; Define a local variable
      (begin
        (if (pair? (cddr exp))
            (compile (caddr exp) port env))
        (emit port "  pushl %eax")
        (set-car! *stack*
         (cons (+ (caar *stack*) 1)
               (- (cdar *stack*) wordsize)))
        (environment-define! env (cadr exp)
         (string-append
          (number->string (cdar *stack*))
          "(%ebp)")))))

(put-special-form 'defvar compile-defvar)

(define (compile-set exp port env)
  (compile (caddr exp) port env)
  (emit port "  movl %eax, ~s" (environment-lookup env (cadr exp))))

(put-special-form 'set compile-set)

;;; Compile a variable reference.
(define (compile-variable exp port env)
  (emit port "  movl ~s, %eax" (environment-lookup env exp)))

(define (compile-for exp port env)
  (compile
   `(block
      ,(cadr exp)
      (while ,(caddr exp)
        ,@(cddddr exp)
        ,(cadddr exp)))
   port env))

(put-special-form 'for compile-for)

(define (compile-inc exp port env)
  (compile `(set ,(cadr exp) (+ ,(cadr exp) 1)) port env))

(put-special-form 'inc compile-inc)

(define (compile-block exp port env)
  (let ((old-toplevel *toplevel*))
    (set! *stack* (cons (cons 0 (cdar *stack*)) *stack*))
    (set! *toplevel* #f)
    (compile `(begin ,@(cdr exp))
             port (cons (cons '() '()) env))
    (cleanup port)
    (set! *toplevel* old-toplevel)))

(put-special-form 'block compile-block)

;;; Compile an expession.
(define (compile exp port env)
  (cond ((self-evaluating? exp) (compile-datum exp port))
        ((variable? exp) (compile-variable exp port env))
        ((special-form? exp)
         ((get-special-form (car exp)) exp port env))
        ((application? exp) (compile-application exp port env))
        (else (error "Unknown expession type" exp))))

;;; Compile a program.
(define (compile-program exp port)
  ;; Intialize global variables.
  (set! *data* (open-output-string))
  (set! *procedures* (open-output-string))
  (set! *stack* (list (cons 0 0)))
  (set! *toplevel* #t)
  (emit port "  .text")
  (emit port "  .globl entry")
  (emit port "entry:")
  (emit port "  pushl %ebp")
  (emit port "  movl %esp, %ebp")
  (compile exp port (empty-environment))
  (cleanup port)
  (emit port "  popl %ebp")
  (emit port "  ret")
  ;; Emit procedures.
  (display (get-output-string *procedures*) port)
  ;; Emit data.
  (emit port "  .data")
  (display (get-output-string *data*) port))

;;; Read a program from the port INPUT and
;;; compile it to the port OUTPUT.
(define (compile-file input output)
  (let loop ((accum '(begin)))
    (let ((exp (read input)))
      (if (eof-object? exp)
          (compile-program (reverse accum) output)
          (loop (cons exp accum))))))

(compile-file (current-input-port) (current-output-port))
