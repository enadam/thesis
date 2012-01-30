/*
 * figs/specialbh.st -- process "% special:" comments
 * in Postscript files as inserted by specialuh.st.
 *
 * Understood special:s are:
 * (literal	(<Postscript statement>)
 *		Insert <Postscript statement> after the innsermost "gsave"
 *		counted from the location of the special: comment.
 * (literalnow	(<Postscript statement>)
 *		Insert <Postscript statement> immediately.
 * (underline	(<text>))
 *		Underline the next node <text>.
 * (setfont	(<text>) <font> <height>)
 *		Change the font of the next node <text> to <font>,
 *		scaled to <height>.
 * (rotate	(<label>) (<text>) <angle>)
 *		Rotate the <label> of the next node by <angle> degrees,
 *		replace <label> with <text>.
 * (fill	<brightness>)
 *		Observe the next Postscript path and fill it with
 *		<brightness>.
 * (fillhsv	<hue> <saturation> <value>)
 *		Likewise, but you can specify all three components.
 */

/* Global lists storing what special to insert when time comes. */
Literals  = list();
Underline = list();
Setfont   = list();
Rotate    = list();
Fillcolor = list();
Currpath  = list();

Whitespace = regexp("[ 	]+");

/* Start parsing at 'toplevel'. */
start			{ check_startrules(); }
startrules		{ // toplevel; }

/* Examine the line, look for commands and insert whatever necessary. */
state toplevel
{
	/^% special:/	{ call(commands);			}

	/\bgsave\b/	{ print($0); call(do_literals);		}

	/^newpath +[0-9.-]+ +[0-9.-]+ +moveto\n$/
	{
		print($0);
		if (length(Fillcolor) > 0 && length(Currpath) == 0)
			Currpath[length(Currpath)] = list($0);
	}
	/^[0-9.-]+ +[0-9.-]+ +(lineto|[0-9.-]+ +[0-9.-]+ +[0-9.-]+ +[0-9.-]+ +curveto)\n$/
	{
		print($0);
		if (length(Fillcolor) > 0)
			Currpath[length(Currpath)] = list($0);
	}

	/^([0-9.-]+) ([0-9.-]+) moveto [0-9.-]+ ([0-9.-]+) \((.*)\) alignedtext\n$/
	{
		do_fill();
		do_setfont($4);
		if (!do_rotate(float($1), float($2), $4))
		{
			print($0);
			do_underline(float($1), float($2), float($3), $4, 0);
		}
	}
}

/* Search for commands addressed to us. */
state commands
{
	Whitespace	{ /* ignore */			}
	/\(/		{ call(command);		}
	/\n$/		{ return;			}
	//		{ panic("special error 1");	}
}

state command
{
	Whitespace
		{ /* ignore */			}

	/literal\b/
	{
		NTargets = 1;
		call(command_targets);
		Literals[length(Literals)] = Targets[0];
		return;
	}
	/literalnow\b/
	{
		NTargets = 1;
		call(command_targets);
		print(Targets[0], "\n");
		return;
	}
	/underline\b/
	{
		NTargets = 1;
		call(command_targets);
		Underline[length(Underline)] = Targets[0];
		return;
	}
	/setfont\b/
	{
		NTargets = 1; NArgs = 2;
		call(command_targets);
		call(command_args);
		Setfont[length(Setfont)] = list(
			Targets[0], Args[0], Args[1]);
		return;
	}
	/rotate\b/
	{
		NTargets = 2; NArgs = 1;
		call(command_targets);
		call(command_args);
		Rotate[length(Rotate)] = list(
			Targets[0], Targets[1], float(Args[0]));
		return;
	}
	/fill\b/
	{
		NArgs = 1;
		call(command_args);
		Fillcolor = list(0.0, 0.0, float(Args[0]));
		return;
	}
	/fillhsv\b/
	{
		NArgs = 3;
		call(command_args);
		Fillcolor = list(float(Args[0]),
			float(Args[1]), float(Args[2]));
		return;
	}

	//	{ panic("special error 2");	}
	END	{ call(gobble_paren);		}
}

state command_targets
{
	BEGIN	{ Targets = list();		}

	Whitespace
		{ /* ignore */			}
	/\(/
	{
		call(command_target);
		Targets[length(Targets)] = Target;
	}
	//
	{
		if (NTargets > 0 && NTargets != length(Targets))
			panic("special error 3");
		return;
	}
}

state command_target
{
	BEGIN	{ Target = ""; nest = 1;		}
	/\\\\./	{ Target = concat(Target, $0);		}
	/\(/	{ Target = concat(Target, $0); nest++;	}
	/\)/
	{
		nest--;
		if (nest == 0)
			return;
		Target = concat(Target, $0);
	}
	/./	{ Target = concat(Target, $0);		}
	/$/	{ panic("special error 4");		}
}

state command_args
{
	BEGIN	{ Args = list();			}
	Whitespace
		{ /* ignore */				}
	/([^() 	]+)/
		{ Args[length(Args)] = $1; }
	//
	{
		if (NArgs > 0 && NArgs != length(Args))
			panic(NArgs, "special error 5");
		return;
	}
}

/* Gobble whitespace until a closing paran. */
state gobble_paren	{ /[ 	]*\)/	{ return; } }

/* Find the last 'gsave' and insert all 'Literals' collected so far. */
state do_literals
{
	BEGIN	{ if (length(Literals) == 0) return;	}
	Whitespace
		{ print($0);				}
	/\bgsave\b/
		{ print($0);				}
	//
	{
		print("\n");
		for (i = 0; i < length(Literals); i++)
			print(Literals[i], "\n");
		Literals = list();
		return;
	}
}

sub do_underline(x, y, align, text, is_rotating)
{
	local i, o, matched, tmp;

	matched = 0;
	tmp = list();
	for (i = o = 0; i < length(Underline); i++)
	{
		if (!matched && !strcmp(text, Underline[i]))
		{
			matched = 1;

			/*
			 * Start underlining one point right to the
			 * beginning of 'text'.  Vertical placement
			 * and thickness are determined from /FontInfo.
			 * Clever, eh?  Except that I fail to grasp
			 * why the dimensions are multiplied by 100.
			 */
			print("currentpoint\n");
			if (!is_rotating)
			{
				print(sprintf("(%s) stringwidth pop\n", text));
				print(sprintf("dup %f mul %f add %f\n",
					align, x, y));
			} else
				print("3 -1 roll currentpoint\n");
			print("exch 1 add\n");
			print("exch ",
				"CurrentFontInfo /UnderlinePosition get ",
				"100 div add ",
				"moveto\n");
			print("1 sub 0 rlineto\n");
			print("currentlinewidth\n");
			print("CurrentFontInfo /UnderlineThickness get ",
				"100 div ",
				"setlinewidth\n");
			print("stroke\n");
			print("setlinewidth moveto\n");
		} else
			tmp[o++] = Underline[i];
	}
	Underline = tmp;
	return matched;
}

sub do_setfont(text)
{
	local i, o, matched, tmp;

	matched = 0;
	tmp = list();
	for (i = o = 0; i < length(Setfont); i++)
	{
		if (!matched && !strcmp(text, Setfont[i][0]))
		{
			matched = 1;
			print(	Setfont[i][2],
				" /", Setfont[i][1],
				" set_font\n");
		} else
			tmp[o++] = Setfont[i];
	}
	Setfont = tmp;
	return matched;
}

/*
test	[shape=record, fontsize=10,
	SPECIAL((underline	(Ha az altestem szorgos)),
		(underline	(nem tettem semmit)),
		(rotate (m)	(Artatlan vagyok--bunos?)	-90),
		(rotate (mm)	(Kurva zuros: mit tehetek\n
				Ha az altestem szorgos)		-90),
		(rotate (mmm)	(Azt mondta a Besenyo\n
				Pista bacsi, nem rossz\n
				dolog balnakkal halni)		-90),
		(rotate (mmmm)	(Bunos a lelkem, pedig\n
				nem tettem semmit\n
				nem bantottam en sose\n
				nem senkit)			-90),
		(rotate (wwww)	(Bunos a lelkem, pedig\n
				nem tettem semmit\n
				nem bantottam en sose\n
				nem senkit)			 90),
		(rotate (www)	(Azt mondta a Besenyo\n
				Pista bacsi, nem rossz\n
				dolog balnakkal halni)		 90),
		(rotate (ww)	(Kurva zuros: mit tehetek\n
				Ha az altestem szorgos)		 90),
		(rotate (w)	(Artatlan vagyok--bunos?)	 90)),
	label="m|mm|mmm|mmmm|\n\n\n\nwwww\n\n\n\n\n|www|ww|w"];
 */
sub do_rotate(x, y, mark)
{
	local i, o, j, matched, tmp, texts, angle;

	matched = 0;
	tmp = list();
	for (i = o = 0; i < length(Rotate); i++)
	{
		if (!matched && !strcmp(mark, Rotate[i][0]))
		{

			matched = 1;
			texts = split(regexp("\\\\n"), Rotate[i][1]);
			angle = Rotate[i][2];

			print(sprintf("%f 0.25 CurrentFontHeight mul", x));
			if (angle > 0)
				print(" add ");
			else
				print(" sub ");
			print(sprintf("%f 0.4 CurrentFontHeight mul add moveto\n", y));
			print(angle, " rotate\n");

			print("0 ");
			if (lmod(length(texts), 2) != 0)
				print(ldiv(length(texts), 2));
			else
				print(ldiv(length(texts), 2) + 0.45);
			print(" CurrentFontHeight mul rmoveto\n");

			for (j = 0; j < length(texts); j++)
			{
				print("currentpoint\n");
				print(sprintf("(%s) stringwidth pop\n", texts[j]));
				print("dup -.5 mul 0 rmoveto\n");
				if (!do_underline(0, 0, 0, texts[j], 1))
					print("pop\n");
				print(sprintf("(%s) show\n", texts[j]));


				print("CurrentFontHeight sub moveto\n");
			}
		} else
			tmp[o++] = Rotate[i];
	}
	Rotate = tmp;
	return matched;
}

sub do_fill()
{
	local i;

	if (length(Fillcolor) == 0 || length(Currpath) == 0)
		return 0;

	/* We need to /stroke the path a second time because
	 * we /fill (flood) it. */
	for (i = 0; i < length(Currpath); i++)
		print(Currpath[i]);
	print("closepath\n");
	print("gsave\n");
	print(sprintf("%f %f %f nodecolor\n",
		Fillcolor[0], Fillcolor[1], Fillcolor[2]));
	print("fill\n");
	print("grestore\n");
	print("stroke\n");

	Currpath = list();
	Fillcolor = list();
	return 1;
}

/* Return n % d */
sub lmod(n, d)
{
	local npd;

	for (npd = 0; n >= d; npd++)
		n -= d;
	return n;
}

/* Return n / d */
sub ldiv(n, d)
{
	local npd;

	for (npd = 0; n > d; npd++)
		n -= d;
	return npd;
}

/* End of figs/specialbh.st */
