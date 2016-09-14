#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>

extern void entry(void);

// <
int
_60(int x, int y)
{
  return x < y;
}

// =
int
_61(int x, int y)
{
  return x == y;
}

// char=?
int
char_61_63(char x, char y)
{
  return x == y;
}

// >
int
_62(int x, int y)
{
  return x > y;
}

// +
int
_43(int x, int y)
{
  return x + y;
}

// -
int
_(int x, int y)
{
  return x - y;
}

// not
int
not(int x)
{
  return !x;
}

// display
void
display(char *str)
{
  fputs(str, stdout);
}

// display-line
void
display_line(char *str)
{
  printf("%s\n", str);
}

// newline
void
newline(void)
{
  putchar('\n');
}

// ref
uint32_t
ref(uint32_t *x)
{
  return *x;
}

// set*
void
set_42(uint32_t *x, uint32_t y)
{
  *x = y;
}

int
main(void)
{
  entry();
  return 0;
}
