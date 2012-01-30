#!/usr/bin/perl -w

use strict;

my $last;

while (<>)
{
	while (/(\w+)/g)
	{
		my $new = lc($1);
		if (defined $last && $last eq $new)
		{
			print "$ARGV:$.: $1\n";
		} else
		{
			$last = $new;
		}
	} continue
	{
	       close(ARGV) if eof;
	}
}
