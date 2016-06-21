# do-it
do-it is a toy procedural imperative programming language I wrote to gain experience in code generation. It uses Scheme S-Expression syntax and the compiler is written in Scheme. It is in very early stages.

**Perhaps messy code warning and not very many comments!** Suggestions are very welcome.

## Why?
Because I want to learn about code generation.

### Should I use do-it for my serious real-world program?
I would advise against it&hellip;

## Limitations
* No Garbage Collection
* The compiler can only compile to 32-bit x86 AT&T Assembly
  (It shouldn't be hard to adapt it to 64-bit, but I just use `gcc`'s `-m32` switch)
* No type checking!! Bad programs will probably crash or produce nonsense results!
* No global variables
* Probably unstable and buggy, not a mature project

## Features
* Local variables (allocated on the stack) and assignment
* For and while loops
* Procedures (not first class, can take arguments and return a value)
* Conditionals (if is ternary)
* Non-local exit (return)
* Last expression in a procedure is automatically returned &ndash; it would take pointless effort to *not* do that!
* Super easy to interface with C

## Todo
- [ ] Macros(?), make FOR and INC macros
- [ ] Garbage collection(?)
- [ ] Global variables

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
* Strings, e.g. `"Hello, world!"`

### Variable references
A variable reference is simply a symbol (identifier) that is the name of the variable to be referenced.

### Procedure applications
A procedure application takes the form `(<procedure name> <arguments> ...)`. \<procedure name\> is always symbol that is the name of a procedure. (Like LISP, do-it has seperate namespaces for variables and procedures.) The \<arguments\> can be any type of expression, and they are passed as arguments to the procedure.

do-it is call-by-value, so all the arguments are evaluated, then pushed onto the stack, and then the procedure is called.

### Special forms
do-it has several special forms, but all of them take the form `(<special form name> <arguments> ...)`. The \<arguments\> may or may not be evaluated, the special form chooses. Special forms can do things that procedures can't, like defining a variable or creating a procedure.

#### `(quote <obj>)`
The quote special form returns \<obj\> without evaluating it. (Note that not all objects that Scheme can read are supported by do-it at runtime, currently only the same objects that are self-evaluating.)

#### `(begin <exprs ...>)`
The begin special form evaluates all the \<exprs ...\> in sequential order and returns the last one.

#### `(while <test> <body ...>)`
The while special form repeatedly evaluates \<body ...\> (as by begin, in fact the compiler adds a begin around the body), as long as \<test\> evaluates to true.

#### `(return <expr ?>)`
The return special form immediately exits from the procedure or program, returning the result of \<expr\> if it is present.

#### `(proc <name> (<parameters ...>) <body ...>)`
The proc special form defines a procedure, like LISP's defun. (Like LISP, do-it has seperate namespaces for variables and procedures.) It creates a procedure named \<name\>. When the procedure is called, the \<parameters\> are bound to there respective arguments and the \<body\> is executed.

#### `(var <name> <init ?>)`
The var special form defines the variable \<name\>, and sets it to \<init\> if it is present.

#### `(set <name> <value>)`
The set special form is the assignment operator. It sets the variable \<name\> to the value \<value\>.

#### `(for <init> <test> <step> <body ...>)`
This is the same as

```scheme
(begin
  <init>
  (while <test>
    <body ...>
    <step>))
```

e.g.

```scheme
(for (var i 0) (< var 21) (inc var)
  (printf "%d\n" i))
```

will print all the integers from 0 to 20 (inclusive).

#### `(inc <name>)`
This is the same as `(set <name> (+ <name> 1))`

## Examples
```scheme
(proc greet (name)
  (printf "Hello, %s!\n" name))

;;; Greet everyone
;;; (the names are made up)
(greet "Thomas")
(greet "James")
(greet "David")
(greet "Whoever")
```
