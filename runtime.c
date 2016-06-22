#include <stdio.h>

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

// newline
void
newline(void)
{
  putchar('\n');
}

// ref
int
ref(int *x)
{
  return *x;
}

int
main(void)
{
  entry();
  return 0;
}
