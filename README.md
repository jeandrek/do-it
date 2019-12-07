# do-it
Do-it is a _messy_ toy procedural imperative (although everything is an expression for simplicity) programming language I wrote to learn about code generation, initially derived from [_An Incremental Approach to Compiler Construction_](http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf) by Abdulaziz Ghuloum. It uses Scheme S-Expression syntax and the compiler is written in Scheme.

## Limitations
* The compiler can only compile to 32-bit x86 Assembly. (Use the `-m32` option
  for 64-bit GCC/Clang)
* No types!! (The only type is a machine word.)
* Variables only have dynamic extent (like C/C++).

## Operating system support
|      Operating system       |           Status               |
| --------------------------- | ------------------------------ |
| GNU/Linux, OpenBSD, Solaris | Works fine out-of-the-box.     |
| macOS                       | Set `abi-underscore?` to `#t`. |
| Microsoft Windows (MinGW)   | Set `abi-underscore?` to `#t`. |
| Other operating systems     | Not yet tested.                |

## Usage
Edit Makefile as necessary. Then run `make` to compile the library. Now you can
run `make <name>` to compile the source file \<name\>.do-it.

## Documentation
Do-it is fully documented in [the wiki](https://github.com/Jonathan50/do-it/wiki).
