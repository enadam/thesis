#!/usr/bin/perl -w

use strict;

my %LATIN2 =
(
	'á'	=> '\\\'a',
	'Á'	=> '\\\'A',
	'é'	=> '\\\'e',
	'É'	=> '\\\'E',
	'ó'	=> '\\\'o',
	'Ó'	=> '\\\'O',
	'ú'	=> '\\\'u',
	'Ú'	=> '\\\'U',

	'í'	=> '{\\\'\\i}',
	'Í'	=> '{\\\'\\I}',

	'ö'	=> '\\"o',
	'Ö'	=> '\\"O',
	'ü'	=> '\\"u',
	'Ü'	=> '\\"U',

	'õ'	=> '\\H{o}',
	'Õ'	=> '\\H{O}',
	'û'	=> '\\H{u}',
	'Û'	=> '\\H{U}',
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
