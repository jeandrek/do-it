/*
 * This file is part of do-it.
 *
 * Do-it is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Do-it is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with do-it.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>

int
add(int a, int b)
{
	return a + b;
}

int
sub(int a, int b)
{
	return a - b;
}

int
mul(int a, int b)
{
	return a * b;
}

int
div(int a, int b)
{
	return a / b;
}

int
remainder(int a, int b)
{
	return a % b;
}

int
lt(int a, int b)
{
	return a < b;
}

int
eql(int a, int b)
{
	return a == b;
}

int
gt(int a, int b)
{
	return a > b;
}

int
not(int x)
{
	return !x;
}

void
display(const char *str)
{
	fputs(str, stdout);
}

long
peek(const long *addr)
{
	return *addr;
}

void
poke(long *addr, long x)
{
	*addr = x;
}
