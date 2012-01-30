#!/usr/bin/perl -w
#
# figs/fontres.pl -- resolve font names which come in multiple sizes
#

use strict;
use Getopt::Long;

use constant FONT_SIZE     => 0;
use constant FONT_ENCODING => 1;

# Return the difference from the size of the closest available font.
sub closest
{
	my ($sizes, $size) = @_;
	(sort({
		my $diff1 = abs($$a[FONT_SIZE] - $size);
		my $diff2 = abs($$b[FONT_SIZE] - $size);
		$diff1 <=> $diff2
	} @$sizes))[0]
}

# Main starts here
my (@include_first, @include_last);
my ($scaling, $fontmap);
my ($dfltenc, %fonts);

$scaling = 1;
Getopt::Long::Configure(qw(no_getopt_compat bundling no_ignore_case));
GetOptions(
	'above|a=s@'	=> \@include_first,
	'below|b=s@'	=> \@include_last,
	'scaling|s=f'	=> \$scaling);

die "usage: $0 <fontmap>"
	unless @ARGV;
$fontmap = shift;

# Read the Ghostscript fontmap.
open(FONTMAP, '<', $fontmap)
	or die "$fontmap: $!";
while (<FONTMAP>)
{
	if (/^\%\s*Encoding:\s*(-|\w+)/)
	{
		$dfltenc = $1 eq '-' ? undef : $1;
	} elsif (m!^/([\w-]+)-(\d+).*;(?:\s*\%\s*(-|\w+))?!)
	{
		my $thisenc = defined $3 ? $3 eq '-' ? undef : $3 : $dfltenc;
		push(@{$fonts{$1}}, [ $2, $thisenc ]);
	}
}
close(FONTMAP);

# Visit all set_font:s.
while (<>)
{
	my ($dotstyle, $name, $size, $best);

	if ($_ eq "\%\%EndComments\n")
	{
		print;
		print map("($_) run\n", @include_first);
		next;
	} elsif ($_ eq "\%\%EndProlog\n")
	{
		print map("($_) run\n", @include_last);
		print;
		next;
	} elsif (m!^(\d+(?:\.\d+)?) +/([^ ]*) +set_font$!)
	{
		$dotstyle = 1;
		($name, $size) = ($2, $1);
	} elsif (/^\((.*?)\) +findfont +(\d+(?:\.\d+)?) +scalefont +setfont$/)
	{
		$dotstyle = 0;
		($name, $size) = ($1, $2);
	} else
	{	# Not a font-switch, ignore it.
		print;
		next;
	}

	if (!$fonts{$name})
	{	# Didn't hear about this font, ignore it.
		print;
		next;
	}

	# Find the best approximate.
	$best  = closest($fonts{$name}, $size*$scaling);
	$name .= '-' . $$best[FONT_SIZE];

	# Set up the encoding of the replacement font
	# if it hasn't been, unless it's not supposed to be.
	# UPDATE: Oops, gsave seems to lose it sometimes?!?!
	if (defined $$best[FONT_ENCODING])
	{
		print "/$name $$best[FONT_ENCODING]Encoding EncodeFont\n";
		undef $$best[FONT_ENCODING];
	}

	# Replace.
	print $dotstyle
		? "$size /$name set_font\n"
		: "($name) findfont $size scalefont setfont\n";
}

exit 0;

# End of figs/fontres.pl
