# do-it
Do-it is a toy procedural imperative (although everything is an expression for simplicity) programming language I'm writing to gain experience in code generation. It uses Scheme S-Expression syntax and the compiler is written in Scheme.

**Warning: perhaps messy code!** Suggestions are very welcome.

## Why?
Because I want to learn about code generation.

### Should I use do-it to write programs?
No

## Limitations
* No Garbage Collection
* The compiler can only compile to 32-bit x86 GNU Assembly
  (I just use GCC's `-m32` switch)
* No types!! (The only type is a machine word.)
* Unstable and buggy
* Language not standardized
* Imperative programs can get bugs that declarative programs are immune to

## Features
* Lexically scoped local variables (allocated on the stack) and assignment
* For and while loops
* Procedures (not first class, can take arguments and return a value)
* Conditionals (`if` is ternary)
* Last expression in a procedure is automatically returned &ndash; it would take pointless effort to *not* do that!
* Super easy to interface with C

## Todo
- [ ] Dynamic typing(?)
- [ ] Garbage collection(?)
- [ ] Macros(?), make `for` and `inc` macros
- [x] ~~Global variables~~ (added)
- [ ] Linking multiple files
- [ ] Abstract syntax(?)

## Usage
Something like
```sh
guile compile.scm < in.di > out.s
cc runtime.c out.s -o out
```
(It should work with any R<sup>5</sup>RS-conforming Scheme implementation with SRFI 6, please make an issue if it does not)

## Expressions
A program in do-it is made of a sequence of expressions.

do-it has these three types of expressions:

* Self-evaluating expressions
* Variable references
* Procedure applications
* Special forms

### Self-evaluating expressions
A self-evaluating expression is a constant. Currently the only self-evaluating expressions are:

* Fixnums (do-it currently doesn't bother to check that an integer will fit in a fixnum&hellip;), e.g. `4`
* Booleans, i.e. `#t` for true or `#f` for false
* Characters, e.g. `#\a`
* Strings of characters, e.g. `"Hello, world!"`

### Variable references
A variable reference is simply a symbol (identifier) that is the name of the variable to be referenced.

### Procedure applications
A procedure application takes the form `(<operator> <operands>)`. \<operator\> is always symbol that is the name of a procedure. (Like LISP, do-it has seperate namespaces for variables and procedures.) The \<operands\> can be any type of expression, and their values are passed as arguments to the procedure.

Do-it is call-by-value, so all the arguments are evaluated, then pushed onto the stack, and then the procedure is called.

### Special forms
Do-it has several special forms, but all of them take the form `(<special form name> <arguments>)`. The \<arguments\> may or may not be evaluated, the special form chooses. Special forms can do things that procedures can't, like defining a variable or creating a procedure.

#### `(quote <datum>)`
#### `'<datum>`
`Quote` returns \<datum\> without evaluating it. (Note that not all objects that Scheme can read are supported by do-it at runtime, currently only the same objects that are self-evaluating. Actually the only type of object in do-it is a machine word.) The second form is an abbreviation for the first form.

#### `(begin <body>)`
`Begin` evaluates all the expressions in \<body\> sequentially and returns the value of the last one.

#### `(if <test> <consequent> <alternative>)`
If \<test\> evaluates to #f or zero, then if \<alternative\> present it is evaluated, and if it is not present nothing happens. If \<test\> evaluates to #t, then \<consequent\> is evaluated.

#### `(while <test> <body>)`
`While` repeatedly evaluates \<body\> (as by `begin`, in fact the compiler adds a `begin` around the body), as long as \<test\> evaluates to true.

#### `(return <expression>)`
`Return` immediately exits from the procedure or program, returning the result of \<expression\> if it is present.

#### `(block <body>)`
`Block` evaluates all the expressions in \<body\> in a new lexical scope. All variables bound with `var` in the \<body\> are local to the block.

#### `(defproc <name> (<parameters>) <body>)`
`Defproc` defines a procedure, like LISP's `defun`. (Like LISP, do-it has seperate namespaces for variables and procedures.) It creates a procedure named \<name\>. When the procedure is called, the \<parameters\> are bound to their respective arguments and the \<body\> is executed as by begin. The parameters and all variables bound by the procedure are local to the procedure.

**Note:** `defproc` is (currently) only for use at the top level. Don't use it inside procedures.

#### `(procedure <name>)`
`Procedure` returns the address of the procedure named \<name\>, which can be called with the special form `call`.

#### `(call <procedure pointer> <operands>)`
`Call` evaluates \<procedure pointer\> and \<operands\>, then applies the procedure the value of \<procedure pointer\> points to to the values of the \<operands\>.

#### `(defvar <name> <init>)`
`Defvar` defines the variable \<name\>, and sets it to \<init\> if it is present.

#### `(set <name> <expression>)`
`Set` is the assignment operator. It replaces the value of the variable \<name\> with the value of \<expression\>.

#### `(inc <name>)`
This is the same as `(set <name> (+ <name> 1))`.

#### `(for <init> <test> <step> <body>)`
This is the same as

```scheme
(block
  <init>
  (while <test>
    <body>
    <step>))
```

e.g.

```scheme
(for (defvar i 0) (< i 21) (inc i)
  (printf "%d" i)
  (newline))
```

will print all the integers from 0 to 20 (inclusive).

## Primitives
Do-it provides these built-in procedures (primitives):

### Numbers

* `(< x y)`, `(= x y)`, `(> x y)` &ndash; compare two numbers `x` and `y` and return if `x` is less than `y`, equal to `y` or more than `y`, respectively.
* `(+ x y)`, `(- x y)` &ndash; for two numbers `x` and `y`, add them or subtract `y` from `x`, respectively.

### Characters (bytes)

* `(char=? char1 char2)` &ndash; return if two bytes `char1` and `char2` are equal.

### Booleans

* `(not obj)` &ndash; return `#t` if obj is false and `#f` otherwise.

### Pointers

* `(ref ptr)` &ndash; return the value stored at the address `ptr`.
* `(set* ptr obj)` &ndash; set the value stored at the address `ptr` to `obj`.

### Input and output

* `(display string)` &ndash; print the string `string` to standard output.
* `(display-line string)` &ndash; print the string `string` to standard output followed by a newline.
* `(newline)` &ndash; print a newline to standard output.

In addition to the primitives provided by do-it, you can call any C procedure from do-it (without any header files!).

## Examples
```scheme
(display-line "Hello, world!")
```

```scheme
(defproc greet (name)
  (printf "Hello, %s!" name)
  (newline))

;;; Greet everyone
;;; (the names are made up)
(greet "Thomas")
(greet "James")
(greet "David")
(greet "Tony")
```

```scheme
;;; Get the nth Fibonacci number
(defproc fib (n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(defproc <= (x y)
  (not (> x y)))

(for (defvar i 1) (<= i 20) (inc i)
  (printf "The %dth Fibonacci number is %d" i (fib i))
  (newline))
```
