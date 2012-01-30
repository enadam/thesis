/*
 * figs/fontdef.st -- replace ROMAN, BOLD etc. symbols
 * with actual font names.  Recognizes #define as well.
 */

/* Global variables */
Smarties	= list();
Smarties_str	= "";
Smarties_rex	= regexp("!");
Snickers	= list();
Snickers_str	= "";
Snickers_rex	= regexp("!");

/* Use standard Postscript fonts */
state STD extends run
{
	BEGIN
	{
		add_smartie("ROMAN",	       "Times-Roman");
		add_smartie("BOLD",	       "Times-Bold");
		add_smartie("SANSSERIF",       "Helvetica");
		add_smartie("SANSSERIF_BOLD",  "Helvetica-Bold");
		add_smartie("ASCII",	       "Courier");
		add_smartie("TYPEWRITER",      "Courier");
		add_smartie("TYPEWRITER_BOLD", "Courier-Bold");
	}
}

/* Use Computer Modern */
state CM extends run
{
	BEGIN
	{
		/* CM does not have TYPEWRITER_BOLD, but is is hardly
		 * a problem, because TYPEWRITER is already quite heavy. */
		add_smartie("ROMAN",	       "ComputerModern");
		add_smartie("BOLD",	       "ComputerModern-Bold");
		add_smartie("SANSSERIF",       "ComputerModern-SansSerif");
		add_smartie("SANSSERIF_BOLD",  "ComputerModern-SansSerif-Bold");
		add_smartie("ASCII",	       "ComputerModern-ASCII");
		add_smartie("TYPEWRITER",      "ComputerModern-Typewriter");
		add_smartie("TYPEWRITER_BOLD", "ComputerModern-Typewriter");
	}
}

state run
{
	BEGIN			{ In_string = Autocorrect = 0;	}

	/* Set the default fontname:s for nodes, edges and graphs,
	 * so Times-Roman will not be implicit anywhere. */
	/^(di)?graph [^{]*/
	{
		/* It is lame, but let us redefine all fontnames
		 * to our understanding of ROMAN. */
		print($0, "{\n");
		setdflt("node",  list("fontname"));
		setdflt("edge",  list("fontname", "labelfontname"));
		setdflt("graph", list("fontname"));
		call(gobble_brace);
	}

	/* Shall we attempt to correct() missing glyphs? */
	/* Currently it does nothing. */
	/^\s*AUTOCORRECT;/	{ Autocorrect = 1;			}
	/^\s*NOAUTOCORRECT;/	{ Autocorrect = 0;			}

	/* Symbol expansion */
	/^#define[ 	]+/	{ call(define);				}
	Smarties_rex		{ print(smartie($0));			}
	Snickers_rex		{ print(snicker($0));			}

	/* Escaped characters are NOP from our PoV. */
	/\\\\./			{ print($0);				}
	/"/		/*"*/	{ print($0); In_string = !In_string;	}
}

state define
{
	BEGIN
	{
		if (In_string)
		{
			print($0);
			return;
		}
	}

	/([A-Z_][A-Z0-9_]*)[ 	]+"(.*)"[ 	]*\n$/
	{
		add_smartie($1, $2);
		return;
	}
	/([A-Z_][A-Z0-9_]*)[ 	]*$/
	{
		add_snicker($1, "");
		return;
	}
	/([A-Z_][A-Z0-9_]*)[ 	]+/
	{
		Sym = $1;
		call(define_snicker);
		add_snicker(Sym, Meaning);
		return;
	}

	//	{ panic("improper #define");		}
}

state define_snicker
{
	BEGIN	{ Meaning = ""; line = "";		}

	Smarties_rex
		{ line = concat(line, smartie($0));	}
	Snickers_rex
		{ line = concat(line, snicker($0));	}
	/\\\\[^\n]/	{ line = concat(line, $0);	}
	/"/	/*"*/
	{
		In_string = !In_string;
		line = concat(line, $0);
	}
	/[^\n]/	{ line = concat(line, $0);		}

	/\n$/
	{
		tmp = regsub(line, regexp("[ 	]*\\\\[ 	]*$"), "");
		if (!strcmp(tmp, line))
		{
			Meaning = concat(Meaning,
				regsub(line, regexp("[ 	]*$"), ""));
			if (In_string)
				panic("unclosed string in #define");
			return;
		} else
		{
			Meaning = concat(Meaning, tmp);
			line = "";
		}
	}
}

state gobble_brace
{
	/{/			{ return; }
	//			{ }
}

/* Set ROMAN as the default font for graphs, edges and nodes. */
sub setdflt(elem, attrs)
{
	local i;

	/* Smarties[0] is exptected to be ROMAN. */
	if (length(attrs) == 0)
		return;
	print("\t", elem, "[");
	for (i = 0; i + 1 < length(attrs); i++)
		print(attrs[i], "=", Smarties[0][1], ",");
	print(attrs[i], "=", Smarties[0][1], "];\n");
}

/* Fake some character missing from the font. */
sub correct(when, orig, fake)
{
	if (Autocorrect && when)
		print(fake);
	else
		print(orig);
}

sub add_smartie(what, expn)
{
	local re;

	re = concat("\\b", what, "\\b");
	Smarties[length(Smarties)] = list(what, expn);
	if (length(Smarties) == 1)
		Smarties_str = re;
	else
		Smarties_str = concat(Smarties_str, "|", re);
	Smarties_rex = regexp(Smarties_str);
}

sub add_snicker(what, expn)
{
	local re;

	re = concat("\\b", what, "\\b");
	Snickers[length(Snickers)] = list(what, expn);
	if (length(Snickers) == 1)
		Snickers_str = re;
	else
		Snickers_str = concat(Snickers_str, "|", re);
	Snickers_rex = regexp(Snickers_str);
}

sub smartie(sym)
{
	local i;

	if (length(Smarties) == 0)
		return sym;

	for (i = 0; i < length(Smarties); i++)
	{
		if (!strcmp(Smarties[i][0], sym))
		{	/* Quote smartie if we are in a string. */
			if (In_string)
				return Smarties[i][1];
			else
				return concat("\"", Smarties[i][1], "\"");
		}
	}

	/* Should have find it. */
	panic(sym);
}

sub snicker(sym)
{
	local i;

	/* Snickers are not expanded in strings. */
	if (In_string || length(Snickers) == 0)
		return sym;

	for (i = 0; i < length(Snickers); i++)
		if (!strcmp(Snickers[i][0], sym))
			return Snickers[i][1];

	/* Should have find it. */
	panic(sym);
}

/* End of figs/fontdef.st */
