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

(define (tagged-list? obj tag)
  (and (pair? obj)
       (eq? (car obj) tag)))

(define (quote? obj) (tagged-list? obj 'quote))
(define (begin? obj) (tagged-list? obj 'begin))
(define (while? obj) (tagged-list? obj 'while))
(define (if? obj) (tagged-list? obj 'if))
(define (return? obj) (tagged-list? obj 'return))
(define (proc? obj) (tagged-list? obj 'proc))
(define (var? obj) (tagged-list? obj 'var))
(define (set? obj) (tagged-list? obj 'set))
(define (for? obj) (tagged-list? obj 'for))
(define (inc? obj) (tagged-list? obj 'inc))

(define application? pair?)

(define variable? symbol?)

(define (immediate? obj)
  (or (integer? obj)
      (boolean? obj)
      (char? obj)))

(define (self-evaluating? expr)
  (or (immediate? expr)
      (string? expr)))

(define (immediate-rep obj)
  (cond ((number? obj) obj)
        ((boolean? obj) (if obj 1 0))
        ((char? obj) (char->integer obj))))

(define *data* #f)
(define *procedures* #f)

(define *stack* '())

(define unique-label
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      (string-append "L_" (number->string count)))))

(define (mangle sym)
  (define (mangle-aux lst)
    (if (null? lst)
        '()
        (let ((char (car lst)))
          (cond ((char=? (car lst) #\-)
                 (cons #\_ (mangle-aux (cdr lst))))
                ((or (char-alphabetic? char)
                     (char-numeric? char))
                 (cons char (mangle-aux (cdr lst))))
                (else
                 (append
                  '(#\_)
                  (string->list (number->string (char->integer char)))
                  (mangle-aux (cdr lst))))))))

  (list->string
   (mangle-aux (string->list (symbol->string sym)))))

(define (compile-datum obj port)
  (cond ((immediate? obj)
         (emit port "\tmovl $~n, %eax" (immediate-rep obj)))
        ((string? obj)
         (let ((label (unique-label)))
           (emit *data* "~s:" label)
           (emit *data* "\t.asciz ~v" obj)
           (emit port "\tmovl $~s, %eax" label)))
        (else
         (error "Unknown datum type" obj))))

(define (cadddr pair) (car (cdddr pair)))

(define (compile-if expr port env)
  (if (null? (cdddr expr))
      ;; No alternative
      (let ((end-label (unique-label))
            (test (cadr expr))
            (conseq (caddr expr)))
        (compile test port env)
        (emit port "\tcmpl $0, %eax")
        (emit port "\tje ~s" end-label)
        (compile conseq port env)
        (emit port "~s:" end-label))
      ;; Alternative
      (let ((alt-label (unique-label))
            (end-label (unique-label))
            (test (cadr expr))
            (conseq (caddr expr))
            (alt (cadddr expr)))
        (compile test port env)
        (emit port "\tcmpl $0, %eax")
        (emit port "\tje ~s" alt-label)
        (compile conseq port env)
        (emit port "\tjmp ~s" end-label)
        (emit port "~s:" alt-label)
        (compile alt port env)
        (emit port "~s:" end-label))))

(define (compile-while expr port env)
  (let ((loop-label (unique-label))
        (test (cadr expr))
        (body (cddr expr)))
    (if (and (self-evaluating? test)
             (not (or (eq? test 0)
                      (eq? test #f))))
        ;; Infinite loop
        (begin
          (emit port "~s:" loop-label)
          (compile `(begin ,@body) port env)
          (emit port "\tjmp ~s" loop-label))
        ;; Unknown loop length
        (let ((end-label (unique-label)))
          (emit port "~s:" loop-label)
          (compile test port env)
          (emit port "\tcmpl $0, %eax")
          (emit port "\tje ~s" end-label)
          (compile `(begin ,@body) port env)
          (emit port "\tjmp ~s" loop-label)
          (emit port "~s:" end-label)))))

(define (compile-return expr port env)
  (if (pair? (cdr expr))
      (compile (cadr expr) port env))
  (emit port "\tret"))

(define (compile-begin expr port env)
  (for-each
   (lambda (x) (compile x port env))
   (cdr expr)))

(define (compile-application expr port env)
  (for-each
   (lambda (x)
     (compile x port env)
     (emit port "\tpushl %eax"))
   (reverse (cdr expr)))
  (emit port "\tcall ~s" (mangle (car expr)))
  (for-each
   (lambda (x)
     (emit port "\taddl $~n, %esp" wordsize))
   (cdr expr)))

(define (cleanup port)
  (let loop ((i (car *stack*)))
    (if (< i 0)
        (begin
          (emit port "\taddl $~n, %esp" wordsize)
          (loop (+ i wordsize)))))
  (set! *stack* (cdr *stack*)))

(define (empty-environment)
  (cons '() '()))

(define (environment-lookup env var)
  (let loop ((vars (car env))
             (vals (cdr env)))
    (cond ((null? vars)
           (error "Unbound variable" var))
          ((eq? (car vars) var) (car vals))
          (else
           (loop (cdr vars)
                 (cdr vals))))))

(define (environment-define env var val)
  (set-car! env (cons var (car env)))
  (set-cdr! env (cons val (cdr env))))

(define (compile-proc expr port env)
  (let ((name (mangle (cadr expr)))
        (params (caddr expr))
        (body (cdddr expr))
        (new-env (empty-environment)))
    (emit *procedures* "\t.globl ~s" name)
    (emit *procedures* "~s:" name)
    (emit *procedures* "\tpushl %ebp")
    (emit *procedures* "\tmovl %esp, %ebp")
    (set! *stack* (cons 0 *stack*))
    (let loop ((i (* wordsize 2))
               (params params))
      (if (not (null? params))
          (begin
            (environment-define new-env (car params) i)
            (loop (+ i wordsize) (cdr params)))))
    (compile `(begin ,@body) *procedures* new-env)
    (cleanup *procedures*)
    (emit *procedures* "\tpopl %ebp")
    (emit *procedures* "\tret")))

(define (compile-var expr port env)
  (if (pair? (cddr expr))
      (compile (caddr expr) port env))
  (emit port "\tpushl %eax")
  (set-car! *stack* (- (car *stack*) wordsize))
  (environment-define env (cadr expr) (car *stack*)))

(define (compile-set expr port env)
  (compile (caddr expr) port env)
  (emit port "\tmovl %eax, ~n(%ebp)" (environment-lookup env (cadr expr))))

(define (compile-variable expr port env)
  (emit port "\tmovl ~n(%ebp), %eax" (environment-lookup env expr)))

(define (cddddr pair) (cdr (cdddr pair)))

(define (compile-for expr port env)
  (compile
   `(begin
      ,(cadr expr)
      (while ,(caddr expr)
        ,@(cddddr expr)
        ,(cadddr expr)))
   port env))

(define (compile-inc expr port env)
  (compile `(set ,(cadr expr) (+ ,(cadr expr) 1)) port env))

(define (compile expr port env)
  (cond ((begin? expr) (compile-begin expr port env))
        ((while? expr) (compile-while expr port env))
        ((return? expr) (compile-return expr port env))
        ((self-evaluating? expr) (compile-datum expr port))
        ((quote? expr) (compile-datum (cadr expr) port))
        ((if? expr) (compile-if expr port env))
        ((proc? expr) (compile-proc expr port env))
        ((var? expr) (compile-var expr port env))
        ((set? expr) (compile-set expr port env))
        ((for? expr) (compile-for expr port env))
        ((inc? expr) (compile-inc expr port env))
        ((variable? expr) (compile-variable expr port env))
        ((application? expr) (compile-application expr port env))
        (else
         (error "Unknown expression type" expr))))

(define (compile-program expr port)
  (set! *data* (open-output-string))
  (set! *procedures* (open-output-string))
  (set! *stack* '(0))
  (emit port "\t.text")
  (emit port "\t.globl entry")
  (emit port "entry:")
  (emit port "\tpushl %ebp")
  (emit port "\tmovl %esp, %ebp")
  (compile expr port (empty-environment))
  (cleanup port)
  (emit port "\tpopl %ebp")
  (emit port "\tret")
  (display (get-output-string *procedures*) port)
  (emit port "\t.data")
  (display (get-output-string *data*) port))

(define (compile-file input output)
  (let loop ((accum '(begin)))
    (let ((expr (read input)))
      (if (eof-object? expr)
          (compile-program (reverse accum) output)
          (loop (cons expr accum))))))

(compile-file (current-input-port) (current-output-port))
