/*
 * spoiler.c -- rot13 encoder/decoder
 */

#include <stdio.h>

#define THIRTEEN	13
#ifndef DEROT
# define CODEC		rot13
#else
# define CODEC		derot13
#endif

static char rot13(char c, char a, char z)
{
	unsigned d;

	d = z - c;
	return d >= THIRTEEN
		? c + THIRTEEN
		: a + THIRTEEN - d - 1;
}

static char derot13(char c, char a, char z)
{
	unsigned d;

	d = c - a;
	return d >= THIRTEEN
		? c - THIRTEEN
		: z - THIRTEEN + d + 1;
}

int main(void)
{
	char c;

	while ((c = getchar()) != EOF)
		if ('a' <= c && c <= 'z')
			putchar(CODEC(c, 'a', 'z'));
		else if ('A' <= c && c <= 'Z')
			putchar(CODEC(c, 'A', 'Z'));
		else
			putchar(c);

	return 0;
}

/* End of spoiler.c */
