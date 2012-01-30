#!/usr/bin/perl -w
#
# figs/fitness.pl -- print tabulated value-fitness pairs for `gnuplot'
#

use strict;

use constant	CINT_MIN => 0;
use constant	CINT_OPT => 1;
use constant	CINT_MAX => 2;
use constant	CINT_VAL => 3;

sub odiff2
{
	my ($cint, $x) = @_;
	($$cint[CINT_OPT] - $x) * ($$cint[CINT_OPT] - $x)
}

sub badness1
{
	my ($cint, $val) = @_;

	my $bad = -odiff2($cint, $val);
	if ($val <= $$cint[CINT_MIN])
	{
		$bad += odiff2($cint, $$cint[CINT_MIN]) - 1;
	} elsif ($val <= $$cint[CINT_OPT])
	{
		$bad /= odiff2($cint, $$cint[CINT_MIN]);
	} elsif ($val <= $$cint[CINT_MAX])
	{
		$bad /= odiff2($cint, $$cint[CINT_MAX]);
	} else
	{
		$bad += odiff2($cint, $$cint[CINT_MAX]) - 1;
	}
	return $bad < 0 ? $bad : 0;
}

sub badness
{
	my ($cset, $val) = @_;

	my $badness = 0;
	$badness += badness1($_, $$_[CINT_VAL])
		foreach @$cset;
	return $badness;
}

# Main starts here
my $val;

if (@ARGV == 0)
{
	@ARGV = (1, 3, 7);
} elsif (@ARGV == 1)
{
	@ARGV = (0, $ARGV[0], 2*$ARGV[0]);
} elsif (@ARGV == 2)
{
	@ARGV = ($ARGV[0], ($ARGV[1] - $ARGV[0])/2, $ARGV[1]);
}

$, = "\t";
$\ = "\n";
for ($val = $ARGV[0] - 0.2; $val <= $ARGV[2] + 0.2; $val += 0.01)
{
	print $val, badness1(\@ARGV, $val);
}

exit;

# End of fitness.pl
