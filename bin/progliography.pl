#!/usr/bin/perl -w

use strict;

my %LATIN2 =
(
	'�'	=> '\\\'a',
	'�'	=> '\\\'A',
	'�'	=> '\\\'e',
	'�'	=> '\\\'E',
	'�'	=> '\\\'o',
	'�'	=> '\\\'O',
	'�'	=> '\\\'u',
	'�'	=> '\\\'U',

	'�'	=> '{\\\'\\i}',
	'�'	=> '{\\\'\\I}',

	'�'	=> '\\"o',
	'�'	=> '\\"O',
	'�'	=> '\\"u',
	'�'	=> '\\"U',

	'�'	=> '\\H{o}',
	'�'	=> '\\H{O}',
	'�'	=> '\\H{u}',
	'�'	=> '\\H{U}',
);

sub latin2
{
	my $in = shift;
	my $out = '';
	$out .= defined $LATIN2{$1} ? $LATIN2{$1} : $1
		while ($in =~ /\G(.)/g);
	return $out;
}

while (<>)
{
	my ($id, $lname, $desc, $url);

	/^(.*?):\s+/g;
	$id = $1;

	/\G\((.*?)\)\s*/gc
		and $lname = $1;

	if (/\G$/gc)
	{
		$_ = <>;
		/^\s+/g;
	}

	/\G(.*)$/;
	$desc = latin2($1);

	chop($_ = <>);
	s/^\s+//;
	$url = $_;

	print "\\DefProg{$id}";
	print "[$lname]"
		if defined $lname;
	print "\n";
	print "\t{$desc}\n\t{$url}\n";
}
