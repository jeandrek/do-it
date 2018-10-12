# do-it
Do-it is a _messy_ toy procedural imperative (although everything is an expression for simplicity) programming language I'm writing to gain experience in code generation. It uses Scheme S-Expression syntax and the compiler is written in Scheme.

## Why?
Because I want to learn about code generation.

### Should I use do-it to write programs/learn to program?
No.

## Limitations
* The compiler can only compile to 32-bit x86 AT&T Assembly.
  (I just use GCC's `-m32` switch)
* No types!! (The only type is a machine word.)
* Variables only have dynamic extent (like languages such as C/C++).

## Operating system support
|      Operating system     |           Status             |
| ------------------------- | ---------------------------- |
| GNU/Linux and OpenBSD     | Works fine out-of-the-box.   |
| Microsoft Windows (MinGW) | Also works, you just need to set `abi-underscore?` to `#t`. |
| macOS                     | Compiled programs don't run. |
| Other operating systems   | Not yet tested.              |

## Usage
Edit Makefile as necessary. Then run `make` to compile the library. Now you can
run `make <name>` to compile the source file \<name\>.do-it.

## Documentation
Do-it is fully documented in [the wiki](https://github.com/Jonathan50/do-it/wiki).
