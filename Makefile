SCHEME=	guile
CFLAGS=	-m32 -Wall -O

.SUFFIXES: .do-it
.PHONY: clean

.do-it:
	$(SCHEME) compile.scm < $< > $@.s
	$(CC) $(CFLAGS) -o $@ $@.s lib.a
	rm $@.s

lib.a: lib.o lib.do-it
	$(SCHEME) compile.scm < lib.do-it > lib.s
	$(CC) $(CFLAGS) -c -o lib2.o lib.s
	$(AR) $(ARFLAGS) $@ lib.o lib2.o
	rm -f lib.o lib2.o lib.s

clean:
	rm -f lib.a *.o *.s
