#!/usr/bin/perl -w
#
# figs/relations.pl -- stolen right from the source repo
#
# Visualize the possible "has" relations between CSol:s and CAttr:s.
# If the first argument is "pmc" then a plain text table is printed.
# Otherwise a PostScript file is emitted on the stantard output
# (identical to relations.ps).  This mode requires Graphviz installed.
#

use strict;

# Adjacency matrix of the directed graph of the relations.
my %Rels =
(
	top	=> [ qw(ga pool compo)	],
	ga	=> [ qw(genome)		],
	pool	=> [ qw(atom)		],
	compo	=> [ qw(ga pool compo)	],
	atom	=> [ qw(atom bot)	],
	genome	=> [ qw(ga pool compo)	],
);

# Plain text output
# (Would be great if I could remember what the hell "pcm" stands for.
# Must be some obscenity.)
sub pmc
{
	my ($me, $parent, $seen, $res) = @_;

	defined $seen or $seen = { };
	defined $res  or $res  = [ ];

	if (defined $parent && !$$seen{$parent.$me})
	{
		$$seen{$parent.$me} = 1;
		push(@$res, map([ $parent, $me, $_ ], @{$Rels{$me}}));
	}

	if (!$$seen{$me})
	{
		$$seen{$me} = 1;
		pmc($_, $me, $seen, $res) foreach (@{$Rels{$me}});
	}

	if (!defined $parent)
	{
		$, = "\t";
		$res = [ sort({ $$a[1] cmp $$b[1] || $$a[0] cmp $$b[0] } @$res) ];
		print @$_ foreach (@$res);
	}

	return $res;
}

# dot/PostScript output
sub dot
{
	my $ft = shift;

	if (defined $ft && $ft eq 'ps')
	{
		# Pipe into `dot'.
		open(FH, "| dot -Tps");
	} else
	{
		*FH = *STDOUT;
	}

	print FH <<'__EOT__';
digraph relations
{
	rankdir=LR; rank=same;
	nodesep=.5; ranksep=.5;
	node[fontname=SANSSERIF,fontsize=10];
	node[width=.8,height=.3];

	top[label="TOP",shape=diamond];
	subgraph attrs
	{	node	[shape=box,style=filled,fillcolor=lightgray];
		ga	[label="GA"];
		pool	[label="POOL"];
		compo	[label="COMPOSIT"];
	}
	subgraph sols
	{	node	[shape=ellipse,style=filled,fillcolor=lightgray];
		atom	[label="ATOM"];
		genome	[label="GENOME"];
	}
	bot[label="BOT",shape=diamond];
__EOT__

	print FH '';
	foreach my $node (keys(%Rels))
	{
		foreach my $child (@{$Rels{$node}})
		{
			print FH "\t$node -> $child;";
		}
	}

	print FH '}';
	close(FH);
}

$\ = "\n";
@ARGV && $ARGV[0] eq 'pmc'
	? pmc('top') : dot($ARGV[0]);

exit 0;

# End of figs/relations.pl
