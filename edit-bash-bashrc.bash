#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# edit-bash-bashrc.bash - (Needed by the Makefile)
# Write the 'source' command for the goto() function (goto-function.bash) to the
# specified bashrc.
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
set -o errexit
#
# Arguments:
#   $1 - action (eiter 'write' or 'delete')
#   $2 - path to the goto-function.bash script to be sourced
#   $3 - path to the system-wide bashrc file
#
main() {
    local action
    local path_goto_script
    local path_bashrc
    declare -a bashrc_lines=()
    
    if [[ -z "${1:+x}" ]]; then
	echo "No action passed (valid are 'write' or 'delete')." >&2
	exit 1
    fi

    if [[ -z "${2:+x}" ]]; then
	echo "No path to goto-function.bash passed." >&2
	exit 1
    fi

    if [[ -z "${3:+x}" ]]; then
	echo "No path to the system bashrc passed." >&2
	exit 1
    fi

    readonly action="$1"
    readonly path_goto_script="$2"
    readonly path_bashrc="$3"
    
    # Text to be inserted to (or deleted from) bashrc
    bashrc_lines+=("# Make the 'goto' function available in a terminal shell.")
    bashrc_lines+=("source ${path_goto_script}")

    if [[ ! -f "${path_bashrc}" ]]; then
	echo "Bashrc file: ${path_bashrc} does not exist." >&2
	exit 1
    fi

    case "${action}" in
	"write")
	    # When writing enforce existence of the script to be sourced
	    if [[ ! -f "${path_goto_script}" ]]; then
		echo "Script file: ${path_goto_script} does not exist." >&2
		exit 1
	    fi
	    # Write the comment and source instruction to the bashrc
	    echo "" >> "${path_bashrc}"
	    for line in "${bashrc_lines[@]}"; do
		echo "${line}" >> "${path_bashrc}"
	    done
	;;
	"delete")
	    # Make a backup of the bashrc
	    cp "${path_bashrc}" "${PWD}/${path_bashrc##*/}.backup"
	    echo "Made backup copy of current ${path_bashrc} to:"
	    echo "${PWD}/${path_bashrc##*/}.backup"
	    
	    # Delete the source lines
	    for line in "${bashrc_lines[@]}"; do
		sed --in-place "\|${line}|d" "${path_bashrc}"
	    done
	;;
	*)
	    echo "Unknown action: ${action}." >&2
	    exit 1
    esac
    
    exit 0
}

main "$@"
