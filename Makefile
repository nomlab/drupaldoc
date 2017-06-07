# -*- Makefile -*-

SRC_TOPDIR = org
DST_TOPDIR = html
SCRIPT_DIR = scripts

################################################################
## Use Emacs.app if available and anothr EMACS is not specified by user

COCOA_EMACS := /Applications/Emacs.app/Contents/MacOS/Emacs

ifneq ("$(wildcard $(COCOA_EMACS))", "")
	EMACS ?= $(COCOA_EMACS)
else
	EMACS ?= emacs
endif

################################################################
## Use cask if available and another CASK is not specified by user

CASK_VERSION := $(shell EMACS="$(EMACS)" cask --version 2>/dev/null)

ifdef CASK_VERSION
	CASK ?= cask
endif

ifdef CASK
	CASK_EXEC    ?= exec
	CASK_INSTALL ?= install
endif

################################################################
## cask, emacs and flags

COMPILER := $(CASK) $(CASK_EXEC) $(EMACS)
FLAGS    := -Q -batch -L . -l $(SCRIPT_DIR)/org-publish-all.el

publish:
	./scripts/make-skeletons.rb org/original-index.org
	$(COMPILER) $(FLAGS) $(OPTS) \
	--eval "(make-all \"$(SRC_TOPDIR)\" \"$(DST_TOPDIR)\")" 2>&1 | \
	egrep -v '^(OVERVIEW|Loading|\(No changes|Tangled|Skipping)'

open:
	open $(DST_TOPDIR)/index.html

clean:
	-rm -rf $(DST_TOPDIR)/*
	-rm -rf .org-timestamps

check-link:
	$(SCRIPT_DIR)/org-link-check.rb $(SCRIPT_DIR)

# + Standard directory layout for a project ::
#   + $(SRC_TOPDIR)/       ... project top
#     + *.org    ... org files
#     + dat/     ... static attachments linked from *.org
#     + dyn/     ... dinamically generated files from *.org
#     + pub/     ... files only needed on publishing
#       + css/   ... style sheets
#       + top/   ... top-level dot files such as.htaccess
#     + options/ ... org-mode options (not copied on publish)
#   + $(DST_TOPDIR)/      ... destination to publish
setup:
	$(CASK) $(CASK_INSTALL)
	-mkdir -p $(SRC_TOPDIR)/docs/8
	-mkdir -p $(SRC_TOPDIR)/options
	-mkdir -p $(SRC_TOPDIR)/pub/css
	-mkdir -p $(SRC_TOPDIR)/pub/top
	-mkdir -p $(DST_TOPDIR)
	-touch $(SRC_TOPDIR)/pub/top/.htaccess
