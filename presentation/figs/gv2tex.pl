#!/usr/bin/perl -w
#
# gv2tex.pl
#

# Modules
use strict;
use HTML::TreeBuilder;
use Getopt::Long;

# Private constants
my $REAL = qr/[\d.]+/;

# Private variables
my ($Opt_stdin, $Opt_fullid, $Opt_offby1, $Opt_no_fillstroke);

# Private functions
sub isnode
{
	my ($node, $tag) = @_;

	ref $node
		&& $node->isa('HTML::Element')
		&& (!defined $tag || $node->tag() eq $tag)
}

sub attrof
{
	my ($node, $key) = @_;
	my $val;

	defined ($val = $node->attr($key))
		or die;
	return $val;
}

sub children
{
	my $node = shift;
	grep(isnode($_), $node->content_list())
}

sub first_child
{
	my $node = shift;
	my $chnode;

	foreach $chnode ($node->content_list())
	{
		isnode($chnode)
			and return $chnode;
	}
	return undef;
}

sub pgfxy
{
	sprintf('{\\pgfxy(%s,%s)}', @_)
}

sub proc_g
{
	my ($node, $dostroke, $dofill) = @_;
	my $style;

	if (defined ($style = $node->attr('style')))
	{
		$style =~ /\bstroke:(\w+)/
			and $dostroke = $1 ne 'none';
		$style =~ /\bfill:(\w+)/
			and $dofill = $1 eq 'black';
	}

	$Opt_no_fillstroke && $dofill
		and $dostroke = 0;
	$style = '';
	$style .= 'fill' if $dofill;
	$style .= 'stroke' if $dostroke;

	if ($node->tag() eq 'g')
	{
		proc_g($_, $dostroke, $dofill)
			foreach children($node);
	} elsif ($node->tag() eq 'ellipse')
	{
		print	"\n\t\t\\pgfellipse[$style]",
			pgfxy(attrof($node, 'cx'), attrof($node, 'cy')),
			pgfxy(attrof($node, 'rx'), 0),
			pgfxy(0, attrof($node, 'ry'));
	} elsif ($node->tag() eq 'polygon' || $node->tag() eq 'polyline')
	{
		my $isfirst = 1;
		my $points = attrof($node, 'points');
		while ($points =~ /\G($REAL),($REAL)(?: *|$)/go)
		{
			print	"\n\t\t",
				$isfirst ? "\\pgfmoveto" : "\\pgflineto",
				pgfxy($1, $2);
			$isfirst = 0;
		}
		print "\n\t\t\\pgf",
			($node->tag() eq 'polyline' || $dofill) ? '' : 'close',
			$style;
	} elsif ($node->tag() eq 'path')
	{
		my $path = attrof($node, 'd');
		$path =~ /^M *($REAL) *($REAL) *C */g
			or die;
		print "\n\t\t\\pgfmoveto", pgfxy($1, $2);
		while ($path =~ /\G($REAL) *($REAL) *($REAL) *($REAL) *($REAL) *($REAL)(?: *|$)/go)
		{
			print	"\n\t\t\\pgfcurveto",
				pgfxy($1, $2), pgfxy($3, $4), pgfxy($5, $6);
		}
		print "\n\t\t\\pgf$style";
	}
}

# Main starts here
my ($parser, $ret);
my ($fname, $pageno);

# Parse the command line
$Opt_stdin = $Opt_fullid = $Opt_offby1 = $Opt_no_fillstroke = 0;
Getopt::Long::Configure(qw(no_getOpt_compat bundling no_ignore_case));
exit 1 unless GetOptions(
	's'	=> \$Opt_stdin,
	'f'	=> \$Opt_fullid,
	'1'	=> \$Opt_offby1,
	'nofs'	=> \$Opt_no_fillstroke);
@ARGV > 0
	or die "includegraphics fname?";
$fname = shift;

# Init
$parser = HTML::TreeBuilder->new();
$parser->ignore_unknown(0);
$parser->implicit_tags(0);
$parser->implicit_body_p_tag(0);
$parser->p_strict(1);
$parser->xml_mode(1);

if ($Opt_stdin)
{
	$ret = $parser->parse_file(\*STDIN);
} elsif (-f $fname)
{
	$ret = $parser->parse_file($fname);
	$fname =~ s/\..*$//;
} elsif (-f "$fname.svg")
{
	$ret = $parser->parse_file("$fname.svg");
} elsif (-f "$fname.xml")
{
	$ret = $parser->parse_file("$fname.xml");
} else
{
	die "$fname: where's it?";
}
exit 1 if !$ret;
$fname =~ s!^.*/+!!;

# Run
$pageno = 1;
foreach my $node (children($parser->root()))
{
	my ($id, $width, $height, $xoff, $yoff);

	$node->tag() eq 'svg'
		or die;
	$width  = attrof($node, 'width');
	$height = attrof($node, 'height');
	$width =~ s/px$//;
	$height =~ s/px$//;

	$xoff = 0;
	$yoff = $height;
	if ($Opt_offby1)
	{
		$xoff--;
		$yoff--;
	}

	$node = first_child($node);
	defined $node
		&& $node->tag() eq 'g'
		&& attrof($node, 'class') eq 'graph'
		or die;

	$id = attrof($node, 'id');
	print "\n" if $pageno > 1;
	print $Opt_fullid
		? "\\newenvironment{gv_${fname}_${id}}"
		: "\\newenvironment{gv_${id}}",
		"[1][$fname]\n";
	print <<"__EOT__";
{	\\begin{pgfpicture}{0bp}{0bp}{${width}bp}{${height}bp}
	\\pgfbox[left,bottom]{\\pgfuseimage{#1}}

	\\pgfsetxvec{\\pgfpoint{1bp}{0bp}}
	\\pgfsetyvec{\\pgfpoint{0bp}{-1bp}}
	\\pgftranslateto{\\pgfxy($xoff,-$yoff)}
	\\pgfsetlinewidth{1pt}

	\\def\\gv##1{\\expandafter\\csname gv\@##1\\endcsname}
__EOT__

	foreach $node (children($node))
	{
		$id = attrof($node, 'id');
		print "\n\t\\expandafter\\def\\csname gv\@$id\\endcsname\{\%";
		proc_g($_) foreach children($node);
		print "}";
	}
	print "}\n{\t\\end{pgfpicture}}\n";
} continue
{
	$pageno++;
}

# Done
exit 0;

# End of gv2tex.pl
