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

;;; Return #t if obj is a pair and the
;;; car of obj is tag and #f otherwise.
(define (tagged-list? obj tag)
  (and (pair? obj)
       (eq? (car obj) tag)))

(define (return? obj) (tagged-list? obj 'return))
(define (quote? obj) (tagged-list? obj 'quote))
(define (begin? obj) (tagged-list? obj 'begin))
(define (while? obj) (tagged-list? obj 'while))
(define (block? obj) (tagged-list? obj 'block))
(define (proc? obj) (tagged-list? obj 'proc))
(define (var? obj) (tagged-list? obj 'var))
(define (set? obj) (tagged-list? obj 'set))
(define (for? obj) (tagged-list? obj 'for))
(define (inc? obj) (tagged-list? obj 'inc))
(define (if? obj) (tagged-list? obj 'if))

(define application? pair?)

(define identifier? symbol?)

;;; Return #t if obj is an immediate
;;; object and #f otherwise.
(define (immediate? obj)
  (or (integer? obj)
      (boolean? obj)
      (char? obj)))

;;; Return #t if expr is a self-evaluating
;;; expression and #f otherwise.
(define (self-evaluating? expr)
  (or (immediate? expr)
      (string? expr)))

;;; Return the immediate representation of obj.
(define (immediate-rep obj)
  (cond ((number? obj) obj)
        ((boolean? obj) (if obj 1 0))
        ((char? obj) (char->integer obj))))

;;; Port for constants
(define *data* #f)
;;; Port for procedures
(define *procedures* #f)

;;; Stack of the stack index and how many items
;;; need to be popped of the stack by cleanup
(define *stack* '())

;;; #t if compiling in the global environment,
;;; #f otherwise.
(define *toplevel* #f)

;;; Return a unique label.
(define unique-label
  (let ((count 0))
    (lambda ()
      (set! count (+ count 1))
      (string-append "L_" (number->string count)))))

;;; Turn a Scheme symbol into an x86 symbol.
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

;;; Compile a datum.
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
  (let ((end-label (unique-label))
        (test (cadr expr))
        (conseq (caddr expr)))
    (if (null? (cdddr expr))
        ;; No alternative
        (begin
          (compile test port env)
          (emit port "\tcmpl $0, %eax")
          (emit port "\tje ~s" end-label)
          (compile conseq port env)
          (emit port "~s:" end-label))
        ;; Alternative
        (let ((alt-label (unique-label))
              (alt (cadddr expr)))
          (compile test port env)
          (emit port "\tcmpl $0, %eax")
          (emit port "\tje ~s" alt-label)
          (compile conseq port env)
          (emit port "\tjmp ~s" end-label)
          (emit port "~s:" alt-label)
          (compile alt port env)
          (emit port "~s:" end-label)))))

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

;;; Compile a procedure application.
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

;;; Emit code to pop variables off the stack at the end
;;; of a procedure or block.
(define (cleanup port)
  (let loop ((i (caar *stack*)))
    (if (> i 0)
        (begin
          (emit port "\taddl $~n, %esp" wordsize)
          (loop (- i 1)))))
  (set! *stack* (cdr *stack*)))

(define (empty-environment)
  (list (cons '() '())))

;;; Get the assembly expression pointing to the value
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
;;; expression val in the frame frame.
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
;;; expression val in the environment env.
(define (environment-define! env var val)
  (frame-define! (car env) var val))

(define (compile-proc expr port env)
  (let ((name (mangle (cadr expr)))
        (params (caddr expr))
        (body (cdddr expr))
        (new-env (cons (cons '() '()) env))
        (old-toplevel *toplevel*))
    (emit *procedures* "\t.globl ~s" name)
    (emit *procedures* "~s:" name)
    (emit *procedures* "\tpushl %ebp")
    (emit *procedures* "\tmovl %esp, %ebp")
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
    (emit *procedures* "\tpopl %ebp")
    (emit *procedures* "\tret")

    (set! *toplevel* old-toplevel)))

(define (compile-var expr port env)
  (if *toplevel*
      ;; Define a global variable
      (let ((label (unique-label)))
        (emit *data* "~s:" label)
        (emit *data* "\t.fill 1, ~n, 0" wordsize)
        (if (pair? (cddr expr))
            (begin
              (compile (caddr expr) port env)
              (emit port "\tmovl %eax, ~s" label)))
        (environment-define! env (cadr expr) label))
      ;; Define a local variable
      (begin
        (if (pair? (cddr expr))
            (compile (caddr expr) port env))
        (emit port "\tpushl %eax")
        (set-car! *stack*
         (cons (+ (caar *stack*) 1)
               (- (cdar *stack*) wordsize)))
        (environment-define! env (cadr expr)
         (string-append
          (number->string (cdar *stack*))
          "(%ebp)")))))

(define (compile-set expr port env)
  (compile (caddr expr) port env)
  (emit port "\tmovl %eax, ~s" (environment-lookup env (cadr expr))))

;;; Compile a variable reference.
(define (compile-variable-ref expr port env)
  (emit port "\tmovl ~s, %eax" (environment-lookup env expr)))

(define (cddddr pair) (cdr (cdddr pair)))

(define (compile-for expr port env)
  (compile
   `(block
      ,(cadr expr)
      (while ,(caddr expr)
        ,@(cddddr expr)
        ,(cadddr expr)))
   port env))

(define (compile-inc expr port env)
  (compile `(set ,(cadr expr) (+ ,(cadr expr) 1)) port env))

(define (compile-block expr port env)
  (let ((old-toplevel *toplevel*))
    (set! *stack* (cons (cons 0 (cdar *stack*)) *stack*))
    (set! *toplevel* #f)
    (compile `(begin ,@(cdr expr))
             port (cons (cons '() '()) env))
    (cleanup port)
    (set! *toplevel* old-toplevel)))

;;; Compile an expression.
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
        ((block? expr) (compile-block expr port env))
        ((identifier? expr) (compile-variable-ref expr port env))
        ((application? expr) (compile-application expr port env))
        (else
         (error "Unknown expression type" expr))))

;;; Compile a program.
(define (compile-program expr port)
  ;; Intialize global variables.
  (set! *data* (open-output-string))
  (set! *procedures* (open-output-string))
  (set! *stack* (list (cons 0 0)))
  (set! *toplevel* #t)

  (emit port "\t.text")

  (emit port "\t.globl entry")
  (emit port "entry:")
  (emit port "\tpushl %ebp")
  (emit port "\tmovl %esp, %ebp")
  (compile expr port (empty-environment))
  (cleanup port)
  (emit port "\tpopl %ebp" wordsize)
  (emit port "\tret")

  ;; Emit procedures.
  (display (get-output-string *procedures*) port)

  ;; Emit data.
  (emit port "\t.data")
  (display (get-output-string *data*) port))

;;; Read a program from the port input and
;;; compile it to the port output.
(define (compile-file input output)
  (let loop ((accum '(begin)))
    (let ((expr (read input)))
      (if (eof-object? expr)
          (compile-program (reverse accum) output)
          (loop (cons expr accum))))))

(compile-file (current-input-port) (current-output-port))
