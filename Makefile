#!/usr/bin/make
#
# Makefile for goto script
#
#    Copyright (C) 2021 Tobias Marczewski
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
SHELL = /usr/bin/sh

INSTALL = install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644
MKDIR_P = mkdir -p

# Script to write the source line into the system-wide bashrc and also to delete
# the corresponding lines for a unistall.  (This is done in a script and not
# directly from the makefile, as I just couldn't figure out how to deal with the
# quotation marks that seem to behave differently for echo and sed.)
EDIT_BASHRC = ./edit-bash-bashrc.bash

# Needed system directories
prefix = /usr/local
libexecdir = $(prefix)/libexec
datadir = $(prefix)/share
bashdir = $(datadir)/bash

# Targets
script_file := "goto-script.bash"
function_file := "goto-function.bash"

script_file_dest := $(libexecdir)/$(script_file)
function_file_dest := $(bashdir)/$(function_file)


# File to which the source command for the goto-function.bash is written
# in Debian /etc/bash.bashrc is a system-wide bashrc
bashrc = /etc/bash.bashrc

# DESTDIR
# /usr/local/libexec
# /usr/local/share/bash
# /etc/bash.bashrc


# 1) Put goto-script into /usr/local/libexec
# 2) Put goto-function into /usr/local/share/bash
# 3) Add a line to /etc/bash.bashrc to source /usr/local/share/bash/goto-script

.PHONY: all
all: install

# install
.PHONY: install
install: install_scripts install_edit_bashrc

.PHONY: install_scripts
install_scripts: installdirs
	$(INSTALL_PROGRAM) $(script_file) $(DESTDIR)$(script_file_dest)
	$(INSTALL_DATA) $(function_file) $(DESTDIR)$(function_file_dest)

.PHONY: install_edit_bashrc
install_edit_bashrc: $(DESTDIR)$(bashrc) install_scripts
	@echo "Writing source entry to $(DESTDIR)$(bashrc)"
	@$(EDIT_BASHRC) write $(DESTDIR)$(function_file_dest) $(DESTDIR)$(bashrc)

# uninstall
# (FIXME: at the moment will leave some leftover dirs, and a non-standard
# install is not tracked via a manifest file)
.PHONY: uninstall
uninstall: uninstall_scripts uninstall_edit_bashrc

.PHONY: uninstall_scripts
uninstall_scripts:
	rm $(DESTDIR)$(script_file_dest)
	rm $(DESTDIR)$(function_file_dest)

.PHONY: uninstall_edit_bashrc
uninstall_edit_bashrc:
	@echo "Removing source entry from $(DESTDIR)$(bashrc)"
	@$(EDIT_BASHRC) delete $(DESTDIR)$(function_file_dest) $(DESTDIR)$(bashrc)


# create necessary directories
.PHONY: installdirs
installdirs: 
	$(MKDIR_P) $(DESTDIR)$(libexecdir)
	$(MKDIR_P) $(DESTDIR)$(bashdir)

# create the bashrc if it doesn't exist
$(DESTDIR)$(bashrc):
	@echo "Warning: specified bashrc does not exist!"
	@echo "Creating file: $(DESTDIR)$(bashrc)"
	$(MKDIR_P) $(dir $(DESTDIR)$(bashrc))
	touch $(DESTDIR)$(bashrc)
