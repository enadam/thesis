#
# figs/Makefile
#
# Please note the (fortunate?) dependency on `states'.
# It comes with GNU enscript, in case you wonder.
#

# Configuration
# FMT: one of ps, pdf, png
# DPI: sample rate of png:s
# FNT: what fonts to use in the figures.
#   -- STD: standard Postscript ones,
#   -- CM: Computer Modern families
DPI := 300
FMT := pdf
FNT := CM

# The list of figures
figs := sysinf sysact sysarch
figs += ga mg
figs += dup cow gsmon gsavl gsxml
figs += fitness relations

# Needn't touch anything below.
CM_ENC	:= T1
ENC	:= $(wildcard $(patsubst %,%Encoding.ps,$($(FNT)_ENC)))
INC	:= $(ENC) konec.ps
DEPS	:= $(INC)

# specialuh.st must come first so fontdef.st will guess quotation right
# wrt to FONTNAMEs.  Sadly this ordering has unintuitive consequences.
DOT	:=   states -f specialuh.st
DOT	+= | states -f fontdef.st -s $(FNT)
DOT	+= | dot -Tps -Gmargin=0 $(patsubst %,-l %,$(INC)) -l dotfun.ps
DOT	+= | states -f specialbh.st
DOTDEPS	:= specialuh.st fontdef.st specialbh.st dotfun.ps

GNUPLOT	:= gnuplot

ifneq ($(wildcard $(FNT).fontmap),)
DOT	+= | ./fontres.pl $(FNT).fontmap
GNUPLOT	+= | ./fontres.pl $(FNT).fontmap -s 0.05 $(patsubst %,-a %,$(INC))
DEPS	+= fontres.pl $(FNT).fontmap
endif

# Rules
# The default target
all: $(figs)

# Implicit rules
# For `dot'
%.ps: %.dot $(DEPS) $(DOTDEPS)
	cat $< | $(DOT) > $@;
%.pdf: %.dot $(DEPS) $(DOTDEPS)
	cat $< | $(DOT) | ps2pdf - > $@;
%.png: %.dot $(DEPS) $(DOTDEPS)
	cat $< | $(DOT) | convert -density $(DPI) ps:- $@;

# For `gnuplot'
%.ps: %.gpl $(DEPS)
	cat $< | $(GNUPLOT) > $@;
%.pdf: %.gpl $(DEPS)
	cat $< | $(GNUPLOT) | epstopdf -filter > $@;
%.png: %.gpl $(DEPS)
	cat $< | $(GNUPLOT) | convert -density $(DPI) ps:- $@;

# For generated `dot' files
%.ps: %.pl $(DEPS) $(DOTDEPS)
	./$< | $(DOT) > $@;
%.pdf: %.pl $(DEPS) $(DOTDEPS)
	./$< | $(DOT) | ps2pdf - > $@;
%.png: %.pl $(DEPS) $(DOTDEPS)
	./$< | $(DOT) | convert -density $(DPI) ps:- $@;

# Explicit rules
$(figs): %: %.$(FMT)
fitness.ps:  fitness.pl
fitness.pdf: fitness.pl

# Commands
.PHONY: all $(figs) clean

clean:
	rm -f $(wildcard $(figs:%=%.ps) $(figs:%=%.pdf) $(figs:%=%.png*));

# End of figs/Makefile
