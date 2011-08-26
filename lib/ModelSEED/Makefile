#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

#
# seed_running_perl.fragement is the piece of perl code that
# checks to see if the seed server is up, and prints a message and returns
# if it is not.
#

PERLCGISCRIPTS := $(subst .pl,,$(wildcard *.cgi))

BINPERLSCRIPTS := $(wildcard *.pl)

PERL_LIB = $(wildcard *.pm) \
	$(wildcard Objects/*.pm) \
	$(wildcard ModelDB/*.pm) \
	$(wildcard StrainDB/*.pm) \
    $(wildcard SchedulerDB/*.pm) \
	$(wildcard ModelSEEDObject/*.pm) \
	$(wildcard ModelSEEDHandler/*.pm) \
	$(wildcard FIGMODEL/*.pm) \
	$(wildcard ModelSEEDUtilities/*.pm) \
	$(wildcard ModelSEEDServers/*.pm) 

WEBPAGES := $(wildcard templates/*.tmpl) \
	$(wildcard images/*.png) \
	$(wildcard images/*.gif) \
	$(wildcard images/*.jpg) \
	$(wildcard images/*.jpeg) \
    $(wildcard html/*.html) \
	$(wildcard js/*.js) \
	$(wildcard js/*.htc)

TUTORIALS := $(wildcard ModelSEEDTutorials/*.html) \
	$(wildcard ModelSEEDTutorials/*.png)
	
CSS_FILES := $(wildcard css/*.css)

INST_PERL_LIB = $(foreach var, $(PERL_LIB), $(libdir)/$(PKGNAME)/$(var))
INST_TUTORIALS = $(foreach var, $(TUTORIALS), $(cgidir)/Html/$(var))
INST_WEBPAGES = $(foreach var, $(WEBPAGES), $(cgidir)/Html/$(var)) 
INST_CSS_FILES = $(foreach var, $(CSS_FILE), $(cgidir)/Html/$(var)) 

all: lib

show:
	@echo cgis $(foreach var, $(PERLCGISCRIPTS), $(cgidir)/$(var))
	@echo top $(TOPDIR)
	@echo pkg $(PKGNAME)
	@echo toolhdr $(TOOL_HDR)
bin:

lib: $(foreach var, $(PERLCGISCRIPTS), $(cgidir)/$(var)) copy_htaccess $(INST_PERL_LIB) $(INST_WEBPAGES) $(INST_TUTORIALS) copy_css
#
# Gross hack.
#
copy_css: $(CSS_FILES)
	for css in $(CSS_FILES); do \
		f=`basename $$css`; \
		cp $$css $(cgidir)/Html/$$f; \
	done

htaccess_src = $(RTROOT)/config/all.htaccess
htaccess_dst = $(cgidir)/.htaccess

copy_htaccess: force
	if test -f $(htaccess_src); then \
		 cp $(htaccess_src) $(htaccess_dst) ; \
	fi

force:

schematools:
stDeclFiles:
stGeneratedFiles:

test:

clean:

$(cgidir)/%: $(TOPDIR)/$(PKGNAME)/% $(TOOL_HDR)
	( cat $(TOOL_HDR) $< > $@; chmod +x $@ )
ifneq (,$(findstring public_html, $(cgidir)))
	chmod go-w $@
endif

$(cgidir)/Html/%: $(TOPDIR)/$(PKGNAME)/%
	tgt_dir=`dirname $@`;  \
	if [ ! -d $$tgt_dir ] ; then \
		mkdir $$tgt_dir; \
	fi
	cp $< $@

$(libdir)/$(PKGNAME)/%.pm: $(TOPDIR)/$(PKGNAME)/%.pm
	tgt_dir=`dirname $@`;  \
	if [ ! -d $$tgt_dir ] ; then \
		mkdir $$tgt_dir; \
	fi
	cp  $< $@

include standard.mk
