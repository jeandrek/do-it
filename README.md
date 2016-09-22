# do-it
Do-it is a _messy_ toy procedural imperative (although everything is an expression for simplicity) programming language I'm writing to gain experience in code generation. It uses Scheme S-Expression syntax and the compiler is written in Scheme.

**Warning: messy code!** Suggestions are very welcome.

## Why?
Because I want to learn about code generation.

### Should I use do-it to write programs/learn to program?
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
* Macros, written in Scheme

## Todo
- [ ] Dynamic typing(?)
- [ ] Garbage collection(?)
- [x] ~~Macros(?), make `for` and `inc` macros~~
- [x] ~~Global variables~~
- [ ] Linking multiple files
- [ ] Abstract syntax(?)

## Usage
Something like
```sh
guile compile.scm < in.di > out.s
cc runtime.c out.s -o out
```
(It should work with any R<sup>5</sup>RS-conforming Scheme implementation with SRFI 6, please make an issue if it does not)

## Documentation
Do-it is documented in [the wiki](https://github.com/Jonathan50/do-it/wiki).

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
