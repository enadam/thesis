/*
 * figs/fixpagesize.st -- 'states' program to add a correct /PageSize
 * to every %%Page output by 'dot'.
 *
 * This program is obsoleted by /pdfmark of konec.ps.
 * However, it may come handy if postprocessing PS is the only option.
 */

/* Start parsing at 'toplevel'. */
start		{ check_startrules(); }
startrules	{ // toplevel; }
state toplevel	{ /^%%Page:.*/ { print($0); call(page); } }

/* We are between %%Page ... %%EndPage. */
state page
{
	BEGIN	{ BBox_found = 0; call(headers); }
	/^%%PageTrailer$/
	{
		if (BBox_found)
		{
			print("grestore\n");
			print($0);
		}
	}
	/^%%EndPage\b/
		{ print($0); return; }
}

/* Process %%Page headers.
 * Add /PageSize at the end if we see a %%PageBoundingBox. */
state headers
{
	/^%%/	{ print($0); call(header); }
	//
	{
		if (BBox_found)
		{
			print(sprintf(
				"<< /PageSize [ %d %d ] >> setpagedevice\n",
				Width, Height));
			print("gsave\n");
			print(sprintf("%d %d translate\n", 0-XOrig, 0-YOrig));
		}
		return;
	}
}

/* Take note of the bounding box dimensions if we see
 * the appropriate header. */
state header
{
	/PageBoundingBox: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+)\n$/
	{
		print($0);
		BBox_found = 1;
		XOrig	= int($1);
		YOrig	= int($2);
		Width	= int($3) - int($1) + 1;
		Height	= int($4) - int($2) + 1;
		return;
	}
	//	{ call(gobble); return; }
}

/* Gobble everything till end-of-line. */
state gobble	{ /.*$/ { print($0); return; } }

/* End of figs/fixpagesize.st */
