EXAMPLES=	01-hello 02-greet 03-fibonacci 04-pair1 05-pair2 06-map
SCHEME=		guile
CFLAGS=		-m32 -Wall -O
KEEPASM=	false

.POSIX:
.SUFFIXES:
.SUFFIXES: .do-it
.PHONY: clean

all: $(EXAMPLES)

.do-it:
	(cd .. && $(SCHEME) compile.scm < example/$< > example/$@.s)
	$(CC) $(CFLAGS) -o $@ $@.s ../runtime.c
	$(KEEPASM) || rm -f $@.s

clean:
	rm -f $(EXAMPLES) *.s
