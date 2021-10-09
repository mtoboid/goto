#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# goto-script.bash - Maintain a list of aliases for destinations (directories).
#
# This script is not intended to be used as a standalone function; it is
# intended to be called from the goto() function defined in goto.bash.
# 
# @Name:         goto-script.bash 
# @Author:       Tobias Marczewski (mtoboid) <vortex@e.mail.de>
# @Version:      0.0.1
declare -r VERSION="0.0.1"
# @Location:     /usr/local/bin/goto-alias
# @Depends:
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

shopt -s extglob nullglob

set -o nounset
set -o pipefail


main() {
    declare -r DEBUG=false
    declare -r LIST_FILE_DIR="${HOME}/.config"
    declare -r LIST_FILE="${LIST_FILE_DIR%/}/goto-dirs.list"
    # Actions are reserved words, don't allow setting them as alias
    declare -a -r ACTIONS=("add" "delete" "list" "usage" "help" "version")
    # Vector to load aliases into (from the LIST_FILE)
    declare -A ENTRIES

    # When called from the goto() function in goto.bash
    # use the name goto as self
    #
    if [[ -n "${self:+x}" ]]; then
	declare -a self=("$self")
    else
	declare -a self=("${0##*/}")
    fi
        
    local action

    
    if [[ -z "${1:+x}" ]]; then
	echo "No action specified." >&2
	echo "See '${self} usage' for info." >&2
	exit 1
    fi

    readonly action="$1"
    shift
    self+=("${action}")

    ensure_list_file_exists
    
    case "$action" in
	"add")
	    add_alias "$@"
	    ;;
	"delete")
	    delete_alias "$@"
	    ;;
	"list")
	    list_defined_aliases "$@"
	    ;;
	"usage"|"help")
	    usage
	    ;;
	"version")
	    echo "$VERSION"
	    ;;
	*)
	    get_dest_for_alias "${action}"
    esac

    # exit with the return value from the action
    #
    exit
}


# Display usage information
# Variables:
#   self (main)
#
usage() {
        cat <<-EOF

   ${self[0]}  version ${VERSION}

   Navigate to a system directory by alias.

   Copyright (C) 2021 Tobias Marczewski (mtoboid)

   This program comes with ABSOLUTELY NO WARRANTY.  This is free software,
   and you are welcome to redistribute it under certain conditions.
   See the GNU General Public License for details.
   (https://www.gnu.org/licenses/)

   
   Usage: ${self[0]} ACTION
          ${self[0]} ALIAS
   
   ACTIONS:
   
       add  <alias> [<path/to/dest>]
           Add a new alias for the specified path.
           If no path is specified, make an alias for the current directory.

       delete  <alias>
           Delete an alias.
 
       list [<mode>]
           Print a list of all defined aliases with corresponding destinations.
           When specifying mode 'completion' only output a list of aliases;
           this is used to define bash completion in 'goto'.

       usage            Show this information.
       version          Print version of ${self[0]}.


   ALIAS:

       When the second argument is a defined alias, output the path to the
       destination for that alias.   


       For bug reports, comments and contributions go to XXX TODO
   
EOF

    return 0
}


# Create the list file if it does not exist, and check it has proper r/w permissions.
# Variables:
#   LIST_FILE_DIR (main),  LIST_FILE (main)
#
ensure_list_file_exists() {
    
    # File exists, only check permissions
    #
    if [[ -f "${LIST_FILE}" ]]; then
	if [[ ! -r "${LIST_FILE}" ]] || [[ ! -w "${LIST_FILE}" ]]; then
	    error "Insufficient read/write permissions for ${LIST_FILE}"
	fi
	return 0
    fi

    
    # File exists, but is not a regular file
    #
    if [[ -e "${LIST_FILE}" ]]; then
	error "${LIST_FILE} exists but is not a file"
    fi


    # File does not exist, create it
    #
    mkdir -p "${LIST_FILE_DIR}"

    if (( "$?" != 0 )); then
	error "Failed to create dir ${LIST_FILE_DIR}"
    fi

    cat >/dev/null 2>&1 <<-EOF > "${LIST_FILE}"
# List file for 'goto'"
# <<Alias>>::<<Destination>>"
EOF
    
    if (( "$?" != 0 )); then
	error "Failed to create file ${LIST_FILE}"
    fi

    
    return 0
}


# Get the corresponding destination for a defined alias
# Arguments:
#   $1 - alias
# Output:
#   (string) - path to destination
#
get_dest_for_alias() {
    local alias
    local path
    
    if [[ -z "${1+x}" ]]; then
	error "No alias provided."
    fi

    readonly alias="$1"
    
    if ! alias_is_defined "${alias}"; then
	error "Alias '${alias}' not defined"
    fi

    path=$(get_path_for_alias "${alias}")
    readonly path

    echo "${path}"

    return 0
}

# Add an alias with path to the list.
# If a path to the destination is not supplied, use the current directory
# Arguments:
#   $1  - the alias to use
#  [$2] - the path to the destination (optional)
# Variables:
#   ENTRIES (main)
# 
add_alias() {
    local alias
    local path
    
    if [[ -z "${1+x}" ]]; then
	error "No alias provided."
    fi
    
    readonly alias="$1"

    # ensure alias is not a reserved word
    #
    if is_reserved_action "${alias}"; then
	error "Provided alias is a reserved action word."
    fi
    

    # ensure alias not already defined
    #
    if alias_is_defined "${alias}"; then
	error "Alias '${alias}' already defined"
    fi

    if [[ -n "${2+x}" ]]; then
	path="$2"
	if [[ ! -d "${path}" ]]; then
	    error "'${path}' is not a valid destination."
	fi
    else
	path=$(pwd)
    fi


    # write an entry to the file
    #
    write_list_file_entry "${alias}" "${path}"

    echo "Added ${path} as '${alias}'"
    
    return 0
}


# Delete an alias from the list.
# If a path to the destination is not supplied, use the current directory
# Arguments:
#   $1  - the alias to delete
# Variables:
#   LIST_FILE (main),  ENTRIES (main)
# 
delete_alias() {
    local alias
    
    if [[ -z "${1:+x}" ]]; then
	error "No alias provided."
    fi
    alias="$1"
    readonly alias

    if ! alias_is_defined "${alias}"; then
	error "Alias '${alias}' not defined."
    fi
    
    sed --regexp-extended --in-place "/^${alias}::.*/d" "${LIST_FILE}"

    if alias_is_defined "${alias}"; then
	error "Failed to delete alias '${alias}'."
    fi
    
    return 0
}


# List all currently defined aliases
# Arguments:
#   [$1] - mode (optional)
#          One of 'normal' (default), 'completion' (only aliases)
# Variables:
#   ENTRIES (main)
#
list_defined_aliases() {
    local mode='normal'

    if [[ -n "${1:+x}" ]]; then
	mode="$1"
    fi

    readonly mode
    
    # refresh ENTRIES
    get_entries_from_list_file


    # No aliases defined
    #
    if (( ${#ENTRIES[@]} < 1 )); then
	case "${mode}" in
	    "normal")
		echo "No alias currently defined."
		echo "Use '${self[0]} add' to add an alias."
		;;
	    "completion")
		echo ""
		;;
	    *)
		error "Unknown mode: ${1}. Possible are 'normal' or 'completion'"
	esac
	
	return 2
    fi


    # List aliases
    #
    case "${mode}" in
	"normal")
	    # determine the length (in characters) of the longest alias
	    declare -i maxlength=$(expr length "[Alias]")
	    for key in "${!ENTRIES[@]}"; do
		declare -i len=$(expr length "${key}")
		if (( ${len} > ${maxlength} )); then
		    maxlength=${len}
		fi
	    done
	    # print the list to screen
	    printf "\n %-*s  %s\n" ${maxlength} "[Alias]" "[Destination]"
	    for key in "${!ENTRIES[@]}"; do
		printf " %-*s  %s\n" ${maxlength} "${key}" "${ENTRIES[${key}]}"
	    done
	    ;;
	"completion")
	    echo "${!ENTRIES[@]}"
	    ;;
	*)
	    error "Unknown mode: ${1}. Possible are 'normal' or 'completion'"
    esac
    
    return 0
}    

# Write an entry into the list file
# Arguments:
#   $1 - alias for the destination (string)
#   $2 - destination (path)
# Variables:
#   LIST_FILE (main)
#
write_list_file_entry() {
    local alias
    local destination

    if [[ -z "${1:+x}" ]]; then
	error "No alias provided."
    fi

    if [[ -z "${2:+x}" ]]; then
	error "No path to destination provided"
    fi

    readonly alias="$1"
    readonly destination="$2"

    echo "${alias}::${destination}" >> "${LIST_FILE}"

    return 0
}


# Get the corresponding path for an alias from the list file
# Arguments:
#   $1 - alias for the destination (string)
# Variables:
#   ENTRIES (main)
# Output:
#   (string)    - path saved for the alias
#   OR (error)  - when alias not found
# Returns:
#   0 - when the alias was found
#   1 - alias not found, no output
#
get_path_for_alias() {
    local alias
    local path
    
    if [[ -z "${1:+x}" ]]; then
	error "No alias passed."
    fi

    alias="$1"
    readonly alias

    get_entries_from_list_file

    if ! alias_is_defined "${alias}"; then
	error "Alias '${alias}' not defined"
    fi

    echo "${ENTRIES[${alias}]}"
    return 0
}


# Check if an alias is in use
# Arguments:
#   $1 - the alias to check
# Variables:
#   ENTRIES (main)
# Returns:
#   0 - alias IS (already) defined
#   1 - alias is NOT defined
#
alias_is_defined() {
    local alias
    
    if [[ -z "${1:+x}" ]]; then
	error "No alias passed."
    fi

    readonly alias="$1"
    
    # refresh ENTRIES
    get_entries_from_list_file

    if [[ -v ENTRIES["${alias}"] ]]; then
	return 0
    else
	return 1
    fi    
}


# Load all entries in the list file into an array (ENTRIES)
# Variables:
#   LIST_FILE (main),  ENTRIES (main)
#
get_entries_from_list_file() {
    original_IFS="${IFS}"
    IFS=$'\n'
    declare -r comment=$'^[[:space:]]*#'
    declare -r pattern=$'^([^:]+)::(.*)+$'
    
    # empty the array entries
    ENTRIES=()

    for line in $(cat "${LIST_FILE}"); do

	# ignore comments
	if [[ "${line}" =~ ${comment} ]]; then
	    continue
	fi
	
	if [[ "${line}" =~ ${pattern} ]]; then
	    local alias="${BASH_REMATCH[1]}"
	    local path="${BASH_REMATCH[2]}"
	    ENTRIES["$alias"]="$path"
	fi
    done

    IFS="${original_IFS}"
    return 0
}


# Check if the passed string is a reserved action word
# Arguments:
#   $1 - word to check
# Variables:
#   ACTIONS (main)
# Returns
#   0 - if the word IS a reserved action
#   1 - otherwise
#
is_reserved_action() {
    local word
    local action
    
    if [[ -z "${1:+x}" ]]; then
	error "No word provided"
    fi

    readonly word="$1"
    
    for action in "${ACTIONS[@]}"; do
	if [[ "$word" == "$action" ]]; then
	    return 0
	fi
    done

    return 1
}


# Display an error message and exit
# Arguments:
#   $1 - the message to display
# Variables:
#  self (main),  DEBUG (main)
#
error() {
    local message="$1"
    
    if ( $DEBUG ); then
	echo "Error in (${FUNCNAME[1]}): ${message}" >&2
    else
	echo "${self[*]} (error) - ${message}"
    fi
    
    exit 1
}	

main "$@"
