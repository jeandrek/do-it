EXAMPLES=	fibonacci greet hello pair-1 pair-2
SCHEME=		guile
CFLAGS=		-m32 -Wall -O

all: $(EXAMPLES)

.SUFFIXES: .do-it

.do-it:
	(cd .. && $(SCHEME) compile.scm < example/$< > example/$@.s)
	$(CC) $(CFLAGS) -o $@ $@.s ../runtime.c

.PHONY: clean

clean:
	rm -f $(EXAMPLES) *.s *.o
