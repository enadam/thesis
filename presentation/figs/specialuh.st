/*
 * figs/specialuh.st -- expand SPECIAL()s in .dot files
 * into comment="..." attributes which specialbh.st can process.
 *
 * The general syntax of SPECIAL() is:
 *    SPECIAL(<command> ...)
 * or SPECIAL((<command1> ...), (<command2> ...))
 *
 * It may appears in graph { } or among node attributes.
 */

/* Start parsing at 'toplevel'. */
start		{ check_startrules(); }
startrules	{ // toplevel; }

/* Search for SPECIAL()s. */
state toplevel
{
	/\bSPECIAL\(/
	{
		/* `dot' will see all specials in a `comment',
		 * which it will convert to a Postscript comment. */
		print("comment=\"special: ");
		call(specials);
		print("\"");
	}
}

/* Transform all specials in SPECIAL(). */
state specials
{
	/\([ 	]*/	{ call(special);	}
	/[,\n 	]+/	{ /* ignore */		}
	//		{ call(special); return;}
	/\)/		{ return;		}
}

/* Parse one special, as delimited by a pair of
 * balanced parantheses. */
state special
{
	BEGIN	{ spc = ""; nest = 1;		}
	/"/	{ spc = concat(spc, "\\", $0);	}	/*"*/
	/\\\\./	{ spc = concat(spc, $0);	}
	/\(/	{ spc = concat(spc, $0); nest++;}
	/\)/
	{
		nest--;
		if (nest == 0)
		{
			print("(", spc, ")");
			return;
		}
		spc = concat(spc, $0);
	}
	/\n/	{ /* ignore */			}
	/^[ 	]+/
		{ /* ignore */			}
	/./	{ spc = concat(spc, $0);	}
}

/* End of figs/specialuh.st */
