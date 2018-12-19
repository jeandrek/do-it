;;; This file is part of do-it.

;;; Do-it is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.

;;; Do-it is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with do-it.  If not, see <http://www.gnu.org/licenses/>.

(define (compile-input)
  (let loop ((accum '()))
    (let ((statement (read)))
      (if (eof-object? statement)
	  (compile-program (reverse accum))
	  (loop (cons statement accum))))))

(define *strings* '())

(define (compile-program program)
  (set! *strings* '())
  (let ((env (extend-environment (make-frame '() '()) '())))
    (call-with-values
     (lambda () (split program))
     (lambda (definitions expressions)
       (codegen-text)
       (for-each
	(lambda (def) (compile-definition def env))
	definitions)
       (if (not (null? expressions))
	   (compile-defproc (make-defproc 'main '() expressions) env))
       (if (not (null? *strings*))
	   (compile-strings))))))

(define (split statements)
  (let loop ((statements statements)
	     (definitions '())
	     (expressions '()))
    (if (null? statements)
	(values (reverse definitions) (reverse expressions))
	(let ((statement (car statements)))
	  (if (definition? statement)
	      (if (and (defvar? statement)
		       (defvar-has-value? statement))
		  (let ((def (make-defvar
			      (defvar-variable statement)))
			(exp (make-assignment
			      (defvar-variable statement)
			      (defvar-value statement))))
		    (loop (cdr statements)
			  (cons def definitions)
			  (cons exp expressions)))
		  (loop (cdr statements)
			(cons statement definitions)
			expressions))
	      (loop (cdr statements)
		    definitions
		    (cons statement expressions)))))))

;;;; Special form table

(define *operation-table* '())

(define (get name op)
  (let ((subtable (assq name *operation-table*)))
    (and subtable
	 (let ((record (assq op (cdr subtable))))
	   (and record (cdr record))))))

(define (put name op proc)
  (let ((subtable (assq name *operation-table*)))
    (if subtable
	(let ((record (assq op (cdr subtable))))
	  (if record
	      (set-cdr! record proc)
	      (set-cdr! subtable (cons (cons op proc) (cdr subtable)))))
	(set! *operation-table*
	      (cons (cons name (list (cons op proc))) *operation-table*)))))

;;;; Code generation

(define (compile exp env)
  (cond ((self-evaluating? exp) (compile-datum exp))
	((variable? exp) (compile-variable exp env))
	((special-form? exp)
	 => (lambda (compiler) (compiler exp env)))
	((application? exp) (compile-application exp env))
	(else (error "Unknown expression type" exp))))

(define (compile-definition definition env)
  (cond ((defproc? definition)
	 (compile-defproc definition env))
	((defvar? definition)
	 (compile-defvar definition env))
	((defmacro? definition)
	 (compile-defmacro definition env))))

(define (compile-defproc definition env)
  (let ((name (symbol->label (defproc-name definition)))
	(params (defproc-parameters definition))
	(body (defproc-body definition)))
    (call-with-values
     (lambda () (split body))
     (lambda (definitions expressions)
       (let* ((vars (map
		     (lambda (definition)
		       (if (defproc? definition)
			   (error "Nested procedures are not yet supported")
			   (defvar-variable definition)))
		     definitions))
	      (frame (make-frame
		      (append params vars)
		      (append (parameter-locations (length params))
			      (local-locations (length vars)))))
	      (env (extend-environment frame env)))
	 (codegen-global name)
	 (codegen-label name)
	 (codegen-enter-procedure (length vars))
	 (compile-sequence expressions env)
	 (codegen-leave-procedure))))))

(define (compile-defvar definition env)
  ;; Define a global variable
  (let ((var (defvar-variable definition)))
    (if (not (variable? var))
	(error "Not a variable in DEFVAR" var)
	(let ((l (make-label 'variable)))
	  (codegen-common l)
	  (environment-define! env var (make-address l))))))

(define (compile-defmacro definition env)
  (let ((lambda-exp
	 `(lambda (exp)
	    (apply (lambda ,(defmacro-parameters definition)
		     ,@(defmacro-body definition))
		   (cdr exp)))))
    (put (defmacro-name definition) 'compile
	 (derived-form (eval lambda-exp (scheme-report-environment 5))))))

(define (compile-datum obj)
  (cond ((integer? obj)
	 (codegen-move (make-immediate obj) reg-result))
	((char? obj)
	 (codegen-move (make-immediate (char->integer obj)) reg-result))
	((string? obj)
	 (let ((label (make-label 's)))
	   (set! *strings* (cons (cons label obj) *strings*))
	   (codegen-move (make-immediate label) reg-result)))
	(else (error "Unknown datum type" obj))))

(define (compile-strings)
  (codegen-rodata)
  (let loop ((strings *strings*))
    (if (not (null? strings))
	(let ((label (caar strings))
	      (string (cdar strings)))
	  (codegen-label label)
	  (codegen-string string)
	  (loop (cdr strings))))))

(define (compile-variable exp env)
  (codegen-move (environment-lookup env exp) reg-result))

(define (compile-arguments args locs env)
  (if (not (null? args))
      (begin (compile (car args) env)
	     (codegen-move reg-result (car locs))
	     (compile-arguments (cdr args) (cdr locs) env))))

(define (compile-application exp env)
  (cond ((get (operator exp) 'open-code)
	 => (lambda (proc)
	      (compile (car (operands exp)) env)
	      (proc)))
	(else
	 (let ((k (length (operands exp))))
	   (codegen-allocate-arguments k)
	   (compile-arguments (operands exp) (argument-locations k) env)
	   (codegen-call (symbol->label (operator exp)))
	   (codegen-release-arguments k)))))

(define (compile-quote exp env)
  (compile-datum (quoted-datum exp)))

(put 'quote 'compile compile-quote)

(define (compile-if exp env)
  (let ((end-label (make-label 'if))
	(predicate (if-predicate exp))
	(consequent (if-consequent exp)))
    (if (if-two-paths? exp)
	(let ((alt-label (make-label 'if))
	      (alternative (if-alternative exp)))
	  (compile predicate env)
	  (codegen-compare (make-immediate 0) reg-result)
	  (codegen-branch alt-label)
	  (compile consequent env)
	  (codegen-jump end-label)
	  (codegen-label alt-label)
	  (compile alternative env)
	  (codegen-label end-label))
	(begin
	  (compile predicate env)
	  (codegen-compare (make-immediate 0) reg-result)
	  (codegen-branch end-label)
	  (compile consequent env)
	  (codegen-label end-label)))))

(put 'if 'compile compile-if)

(define (compile-while exp env)
  (let ((loop-label (make-label 'while))
	(end-label (make-label 'while))
	(test (while-test exp))
	(body (while-body exp)))
    (codegen-label loop-label)
    (compile test env)
    (codegen-compare (make-immediate 0) reg-result)
    (codegen-branch end-label)
    (compile-sequence body env)
    (codegen-jump loop-label)
    (codegen-label end-label)))

(put 'while 'compile compile-while)

(define (compile-assignment exp env)
  (compile (assignment-value exp) env)
  (codegen-move reg-result (environment-lookup env (assignment-variable exp))))

(put 'set 'compile compile-assignment)

(define (compile-sequence exps env)
  (for-each
   (lambda (exp) (compile exp env))
   exps))

(define (compile-begin exp env)
  (compile-sequence (begin-actions exp) env))

(put 'begin 'compile compile-begin)

(define (compile-return exp env)
  (if (return-has-value? exp)
      (compile (return-value exp) env))
  (codegen-leave-procedure))

(put 'return 'compile compile-return)

(define (compile-procedure exp env)
  (codegen-move (make-immediate (symbol->label (procedure-name exp)))
		reg-result))

(put 'procedure 'compile compile-procedure)

(define (compile-call exp env)
  (let ((k (length (call-operands exp))))
    (codegen-allocate-arguments k)
    (compile-arguments (call-operands exp) (argument-locations k) env)
    (compile (call-operator exp) env)
    (codegen-call-indirect reg-result)
    (codegen-release-arguments k)))

(put 'call 'compile compile-call)

(put 'defproc 'compile
     (lambda (exp env)
       (error "Definition in expression context")))

(put 'defvar 'compile
     (lambda (exp env)
       (error "Definition in expression context")))

(put 'defmacro 'compile
     (lambda (exp env)
       (error "Definition in expression context")))

;;;; Derived special forms

(define (derived-form transformer)
  (lambda (exp env)
    (compile (transformer exp) env)))

(define (expand-for exp)
  (apply (lambda (init test step . body)
	   `(begin
	      ,init
	      (while ,test
		,@body
		,step)))
	 (cdr exp)))

(put 'for 'compile (derived-form expand-for))

;;;; Syntax

(define (definition? statement)
  (or (defproc? statement) (defvar? statement) (defmacro? statement)))

(define (defproc? statement)
  (tagged-list? statement 'defproc))
(define (make-defproc name params body)
  (cons 'defproc (cons name (cons params body))))
(define (defproc-name def) (cadr def))
(define (defproc-parameters def) (caddr def))
(define (defproc-body def) (cdddr def))

(define (defvar? statement)
  (tagged-list? statement 'defvar))
(define (make-defvar variable . value)
  (if (null? value)
      (list 'defvar variable)
      (list 'defvar variable (car value))))
(define (defvar-variable def) (cadr def))
(define (defvar-value def) (caddr def))
(define (defvar-has-value? def)
  (not (null? (cddr def))))

(define (defmacro? statement)
  (tagged-list? statement 'defmacro))
(define (defmacro-name def) (cadr def))
(define (defmacro-parameters def) (caddr def))
(define (defmacro-body def) (cdddr def))

(define (self-evaluating? exp)
  (or (number? exp)
      (boolean? exp)
      (char? exp)
      (string? exp)))

(define (variable? exp) (symbol? exp))

(define (special-form? exp)
  (and (pair? exp) (get (keyword exp) 'compile)))
(define (keyword exp) (car exp))

(define (quoted-datum exp) (cadr exp))

(define (make-if predicate consequent . alternative)
  (if (null? alternative)
      (list 'if predicate consequent)
      (list 'if predicate consequent (car alternative))))
(define (if-predicate exp) (cadr exp))
(define (if-consequent exp) (caddr exp))
(define (if-alternative exp) (cadddr exp))
(define (if-two-paths? exp)
  (not (null? (cdddr exp))))

(define (make-while test body)
  (cons 'while (cons test body)))
(define (while-test exp) (cadr exp))
(define (while-body exp) (cddr exp))

(define (make-assignment var val)
  (list 'set var val))
(define (assignment-variable exp) (cadr exp))
(define (assignment-value exp) (caddr exp))

(define (make-begin actions) (cons 'begin actions))
(define (begin-actions exp) (cdr exp))

(define (make-return . value) (cons 'return value))
(define (return-value exp) (cadr exp))
(define (return-has-value? exp)
  (not (null? (cdr exp))))

(define (procedure-name exp) (cadr exp))

(define (call-operator exp) (cadr exp))
(define (call-operands exp) (cddr exp))

(define (make-application operator operands)
  (cons operator operands))
(define (application? exp) (pair? exp))
(define (operator exp) (car exp))
(define (operands exp) (cdr exp))

(define (tagged-list? obj tag)
  (and (pair? obj)
       (eq? (car obj) tag)))

;;;; Open-coded primitives (must be monadic)

(define (open-code-not)
  (display-line "	testl	%eax,%eax")
  (display-line "	setz	%al"))

(put 'not 'open-code open-code-not)

(define (open-code-peek)
  (display-line "	movl	(%eax),%eax"))

(put 'peek 'open-code open-code-peek)

;;;; Compile-time environment

(define (first-frame env) (car env))
(define (extend-environment frame env)
  (cons frame env))

(define (environment-lookup env var)
  (if (null? env)
      (error "Unbound variable" var)
      (let loop ((vars (frame-variables (first-frame env)))
		 (locs (frame-locations (first-frame env))))
	(cond ((null? vars)
	       (environment-lookup (cdr env) var))
	      ((eq? (car vars) var) (car locs))
	      (else
	       (loop (cdr vars) (cdr locs)))))))

(define (environment-define! env var loc)
  (frame-add-binding! (first-frame env) var loc))

;;; Each lexical block introduces a new frame into the compile-
;;; time environment. These don't correspond to stack frames.
(define (make-frame vars locs) (cons vars locs))
(define (frame-variables frame) (car frame))
(define (frame-locations frame) (cdr frame))
(define (frame-add-binding! frame var loc)
  (set-car! frame (cons var (frame-variables frame)))
  (set-cdr! frame (cons loc (frame-locations frame))))

;;;; Machine-dependant code generation

(define word-size 4)
(define abi-underscore? #f)
(define abi-stack-align 16)

(define (mode loc) (vector-ref loc 0))
(define (immediate loc) (vector-ref loc 1))
(define (register loc) (vector-ref loc 1))
(define (base loc) (vector-ref loc 1))
(define (offset loc) (vector-ref loc 2))
(define (make-immediate n) (vector 'immediate n))
(define (make-register reg) (vector 'register reg))
(define (make-register-indirect reg off)
  (vector 'register-indirect reg off))
(define (make-address base) (vector 'address base))
(define (make-address-with-offset base off)
  (vector 'address-with-offset base off))
(define (immediate? loc) (eq? (mode loc) 'immediate))
(define (register? loc) (eq? (mode loc) 'register))
(define (register-indirect? loc) (eq? (mode loc) 'register-indirect))
(define (address? loc) (eq? (mode loc) 'address))
(define (address-with-offset? loc) (eq? (mode loc) 'address-with-offset))

(define reg-result '#(register eax))
(define reg-counter '#(register ecx))
(define reg-stack '#(register esp))
(define reg-frame '#(register ebp))

(define (parameter-locations k)
  (do ((k k (- k 1))
       (off (* 2 word-size) (+ off word-size))
       (accum '() (cons (make-register-indirect
			 (register reg-frame) off)
			accum)))
      ((zero? k) (reverse accum))))

(define (local-locations k)
  (do ((k k (- k 1))
       (off (- word-size) (- off word-size))
       (accum '() (cons (make-register-indirect
			 (register reg-frame) off)
			accum)))
      ((zero? k) (reverse accum))))

(define (argument-locations k)
  (do ((k k (- k 1))
       (off 0 (+ off word-size))
       (accum '() (cons (make-register-indirect
			 (register reg-stack) off)
			accum)))
      ((zero? k) (reverse accum))))

(define (codegen-text)
  (display-line "	.text"))

(define (codegen-rodata)
  (display-line "	.text"))

(define (codegen-common l)
  (display "	.comm	")
  (display l)
  (display-line ",4,4"))

(define (codegen-global l)
  (display "	.globl	")
  (display-line l))

(define (codegen-string s)
  (display "	.asciz	")
  (write-line s))

(define (codegen-enter-procedure k)
  (codegen-push reg-frame)
  (codegen-move reg-stack reg-frame)
  (if (or (> k 0) (not (= abi-stack-align word-size)))
      (begin
	(display "	subl	$")
	(display (- (* abi-stack-align
		       (ceiling (/ (* (+ 2 k) word-size) abi-stack-align)))
		    (* 2 word-size)))
	(display-line ",%esp"))))

(define (codegen-leave-procedure)
  (display-line "	leave")
  (display-line "	ret"))

(define (codegen-allocate-arguments k)
  (if (> k 0)
      (begin
	(display "	subl	$")
	(display (* abi-stack-align
		    (ceiling (/ (* k word-size) abi-stack-align))))
	(display-line ",%esp"))))

(define (codegen-release-arguments k)
  (if (> k 0)
      (begin
	(display "	addl	$")
	(display (* abi-stack-align
		    (ceiling (/ (* k word-size) abi-stack-align))))
	(display-line ",%esp"))))

(define (codegen-move a b)
  (display "	movl	")
  (display (location->assembly a))
  (display ",")
  (display-line (location->assembly b)))

(define (codegen-compare a b)
  (display "	cmpl	")
  (display (location->assembly a))
  (display ",")
  (display-line (location->assembly b)))

(define (codegen-label l)
  (display l)
  (display-line ":"))

(define (codegen-jump l)
  (display "	jmp	")
  (display-line l))

(define (codegen-branch l)
  (display "	jz	")
  (display-line l))

(define (codegen-call l)
  (display "	call	")
  (display-line l))

(define (codegen-call-indirect x)
  (display "	call	*")
  (display-line (location->assembly x)))

(define (codegen-push x)
  (display "	pushl	")
  (display-line (location->assembly x)))

(define (display-line obj)
  (display obj)
  (newline))

(define (write-line obj)
  (write obj)
  (newline))

(define make-label
  (let ((n 0))
    (lambda (name)
      (set! n (+ n 1))
      (string-append ".L" (symbol->string name) (number->string n)))))

(define operators
  ;; Arithmetic operators are replaced with these names to avoid "mangling"
  '((+ "add")
    (- "sub")
    (* "mul")
    (/ "div")
    (< "lt")
    (= "eql")
    (> "gt")
    (<= "lteql")
    (>= "gteql")))

(define (symbol->label sym)
  (define (remove-symbols str)
    (let loop ((lst (string->list str))
	       (accum '()))
      (cond ((null? lst)
	     (list->string (reverse accum)))
	    ((char=? (car lst) #\-)
	     (loop (cdr lst) (cons #\_ accum)))
	    ((char=? (car lst) #\?)
	     (loop (cdr lst) (cons #\P (cons #\_ accum))))
	    (else
	     (loop (cdr lst) (cons (car lst) accum))))))
  (let* ((record (assq sym operators))
	 (str
	  (if record
	      (cadr record)
	      (remove-symbols (symbol->string sym)))))
    (if abi-underscore?
	(string-append "_" str)
	str)))

(define (location->assembly loc)
  (cond ((immediate? loc)
	 (if (number? (immediate loc))
	     (string-append "$" (number->string (immediate loc)))
	     (string-append "$" (immediate loc))))
	((register? loc)
	 (string-append "%" (symbol->string (register loc))))
	((register-indirect? loc)
	 (if (not (zero? (offset loc)))
	     (string-append (number->string (offset loc))
			    "(%" (symbol->string (register loc)) ")")
	     (string-append "(%" (symbol->string (register loc)) ")")))
	((address? loc) (base loc))
	((address-with-offset? loc)
	 (string-append (base loc) "+"
			(number->string (offset loc))))))

(compile-input)
