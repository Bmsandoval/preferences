#!/bin/bash

# Load the env for this script
__QIKBASH_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
_bash-src-env "${__QIKBASH_SCRIPT_DIR}"


alias bf="bashify"
bashify() {
  local name
# Purpose: Take one or more recently run commands and convert them into a function/alias
  local history_selections=($(history | fzf -m --tac | sort | perl -ne 's/\s+([0-9]+).*/$1/ && print'))
  # stop if nothing selected
  if [[ "${#history_selections[@]}" != "0" ]]; then
    local current_history_id=$(history | tail -n1 | perl -ne 's/\s+([0-9]+).*/$1/ && print')

    local bash_type=""
    [ "${#history_selections[@]}" == "1" ] && bash_type="alias" || bash_type="function"

    # get/set command name
    name=""
    if [ ! -z "${1}" ]; then
      name="${1}"
    else
      while
        local _inputReqStr="Name your bash ${bash_type}"
        name=$(_get_user_input "${_inputReqStr}" | perl -lne "print $1 if /^(?!${_inputReqStr})(.+)/")
        [[ -z $name ]] && return 1
        _bash_has_cmd "${name}"
      do
        :
      done; unset _user_input
    fi

    # if only one line selected, consider it an alias
    if [[ "${#history_selections[@]}" == "1" ]]; then
      local count=$((current_history_id-history_selections[0]))
      local cmd=$(_clean_history_command ${count} | perl -pe 's/"/\\"/')
      _bash_tack "alias ${name}=\"${cmd}\""
    else
      # Update the .profile
      _bash_tack "${name} () {"
      for _selection in "${history_selections[@]}"; do
        local count=$((current_history_id-_selection))
        local cmd=$(_clean_history_command ${count})
        _bash_tack "  ${cmd}"
      done; unset _selection
      _bash_tack "}"
    fi
    bashsrc
    echo "Bash ${bash_type} ${name} added to your profile"
  fi
}


alias be="bashedit"
bashedit () {
# Purpose: Helper function to fuzzy search script files and open them at a specific line using Vim
  # select a file
  location=$(cd $__QIKBASH_SCRIPT_DIR/..; find . -type f ! -name '.env.ex' | fzf --preview="cat -n {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
  if [[ "${location}" != "" ]]; then
    # strip leading dot that find leaves behind and prepend file directory
    location="${__QIKBASH_SCRIPT_DIR}/../${location/./}"
    # select line a specific line
    local _line=$(cat -n "$location" | fzf)
    if [[ "${_line}" != "" ]]; then
      # get the line number and open the file there
      vim +"$(echo _line | perl -ne 'print "$1" if /^[^0-9]+([0-9]+).+$/')" "${location}"
    else
      # don't FORCE the user to select a line number
      vim "${location}"
    fi
  fi
}


#    ___ _  _ _____ ___ ___ _  _   _   _
#   |_ _| \| |_   _| __| _ \ \| | /_\ | |
#    | || .` | | | | _||   / .` |/ _ \| |__
#   |___|_|\_| |_| |___|_|_\_|\_/_/ \_\____|
##########################################

_bash_tack () {
# Purpose: Append a line to your bash profile but DO NOT rerun source command
  echo "${1}" >> ~/.profile
}


_clean_history_command () {
# Purpose: Get a single command from a position in the bash history and trim everything before the actual command
  # Example of line from history Output:
  # 1309  01/06/18 12:46:07 bash-src
	# strip line number
	echo $(history | tail -n$(($1+1)) | head -n1 | perl -pe 's|^\s*[0-9]+\s+[0-9]{2}/[0-9]{2}/[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}\s+(.+)|$1|')
}


_bash_has_cmd () {
# Purpose: Quick wrapper to see if the current bash session has a particular alias, function, or command available
  command -v "${1}"
} > /dev/null


