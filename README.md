# do-it
Do-it is a _messy_ toy procedural imperative (although everything is an expression for simplicity) programming language I'm writing to gain experience in code generation. It uses Scheme S-Expression syntax and the compiler is written in Scheme.

**Warning: messy code!** Suggestions are very welcome.

## Why?
Because I want to learn about code generation.

### Should I use do-it to write programs/learn to program?
No.

## Limitations
* No garbage collection.
* The compiler can only compile to 32-bit x86 AT&T Assembly.
  (I just use GCC's `-m32` switch)
* No types!! (The only type is a machine word.)
* Unstable and buggy.
* Language not standardized.
* Variables only have dynamic extent (like languages such as C/C++).

## Features
* Lexically scoped local variables (allocated on the stack) and assignment
* For and while loops
* Procedures (not first class, can take arguments and return a value)
* Conditionals (`if` is ternary)
* Last expression in a procedure is automatically returned &ndash; it would take pointless effort to *not* do that!
* Super easy to interface with C
* Macros, written in Scheme

## Operating system support
|      Operating system     |           Status             |
| ------------------------- | ---------------------------- |
| GNU/Linux and OpenBSD     | Works fine out-of-the-box.<sup>1</sup>   |
| Microsoft Windows (MinGW) | Also works, you just need to set `abi-underscore?` to `#t`.<sup>2</sup> |
| Apple macOS               | Compiled programs don't run. |
| Other operating systems   | Not yet tested.              |

<sup>1: I last tested it on OpenBSD 6.1, OpenBSD 6.2 switched from GCC to Clang on i386 and amd64 so no promises it will still work.</sup>

<sup>2: [This](/Jonathan50/do-it/blob/2c22eba20de3d978dde41119e608c1f6cbddadeb/compile.scm#L21) is the line that needs to be edited.</sup>

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
guile compile.scm <test.do-it >test.s
cc -m32 -o test test.s runtime.c
```

## Documentation
Do-it is fully documented in [the wiki](https://github.com/Jonathan50/do-it/wiki).

## Examples
Examples can be found in the `examples` folder. You can build them all with any POSIX-complaint make.

You can change into the examples folder and enter `make` to build all the examples, or you can enter `make` followed by the name of one or more examples if you don't want them all. You can also put `KEEPASM=true` at the end if you would like to look at the generated code.
