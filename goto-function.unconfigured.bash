#!/usr/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# goto-function.bash - Quickly go to a destination / dir by alias.
#
# This script needs to be sourced from .bashrc for proper functionality of
# 'goto'.  The goto program is devided into two files, the present file
# 'goto-function.bash' and 'goto-script.bash'. To have the whole functionality
# in form of a script (to not pollute namespaces) would be preferable, however,
# as the idea is to change to a different directory in the current terminal
# shell, this is not possible (?).  When a script is called in the terminal
# shell, it is executed in a subshell, and hence affecting the calling
# (terminal) shell to change the PWD is not possible. By calling the script
# containing the main logic (goto-script.bash) from the function goto() it
# becomes possible to execute the cd in the current shell (terminal) and thus
# change to the desired directory.
# 
# @Name:         goto-function.bash 
# @Author:       Tobias Marczewski (mtoboid) <vortex@e.mail.de>
# @Version:      0.0.1
# @Location:     ! source from .bashrc
# @Depends:      goto-script.bash 
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


# Wrapper function for the goto-script, to allow changing of directory.
# For the reasoning behind this see top of this file.
# Arguments:
#   same as for goto-script -> will be passed through
#
function goto() {
    local goto_script
    local path

    # !The location for the script gets configured by the Makefile
    goto_script=@@goto-script-location@@
    readonly goto_script

    # For a normal action just call the goto-script; when jumping to a
    # destination by alias, get the path and change the working directory to it.
    #
    case "$1" in
	"add" | "delete" | "list" | "usage" | "help" | "version")
	    (self="${FUNCNAME[0]}" ${goto_script} "$@")
	    ;;
	*)
	    path=$(self="${FUNCNAME[0]}" ${goto_script} "$@")
	    cd "${path}"
	    ;;
    esac
    
    return 0
}


# Completion function to generate valid completions for 'goto' arguments.
#
function __goto_complete() {
    local command_name
    local current_word
    local preceeding_word
    declare -a -r actions=("add" "delete" "list" "usage" "help" "version")
    declare -a completions=()
    
    readonly command_name="$1"
    readonly current_word="$2"
    readonly preceeding_word="$3"

    COMPREPLY=();
    
    
    if [[ "${preceeding_word}" == "${command_name}" ]]; then
	# Could be either alias or an action...
	
	# add aliases
	completions+=($(goto list "completion"))
	# add actions to completion (uncomment to list actions)
	#completions+=("${actions[@]}")
	
    else
	case "${preceeding_word}" in
	    # If action delete, list defined aliases
	    "delete")
		completions+=($(goto list "completion"))	
		;;
	    # Nothing to be completed for the other cases.
	    "add" | "list" | "usage" | "help" | "version" )
		;;
	    # For the case 'goto add <alias> >x<'
	    # when we are at >x< then complete with system directories
	    *)
		if (( ${COMP_CWORD} == 3 )) && [[ "${COMP_WORDS[1]}" == "add" ]]; then
		    COMPREPLY=($(compgen -d "${current_word}"))
		fi
	esac	
    fi

    
    COMPREPLY+=($(compgen -W '"${completions[@]}"' -- "${current_word}"))
}


# Enable <tab> completion for the 'goto' function
#
complete -o nospace -F __goto_complete goto
# -F function call with:
#   $1 - name of the command
#   $2 - word being completed
#   $3 - word preceeding
