#!/bin/bash

# Append line but don't source it
_bash_tack () {
  echo "$1" >> ~/.profile
}

# Get a single command that was run
_clean_history_command () {
  # Example of line from history Output:
  # 1309  01/06/18 12:46:07 bash-src
	# strip line number
	echo $(history | tail -n$(($1+1)) | head -n1 | perl -pe 's|^\s*[0-9]+\s+[0-9]{2}/[0-9]{2}/[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}\s+(.+)|$1|')
}

alias bf="bashify"
bashify() {
  local history_selections=($(history | fzf -m --tac | sort | perl -ne 's/\s+([0-9]+).*/$1/ && print'))
  # stop if nothing selected
  if [[ "${#history_selections[@]}" != "0" ]]; then
    local current_history_id=$(history | tail -n1 | perl -ne 's/\s+([0-9]+).*/$1/ && print')

    local bash_type=""
    [ "${#history_selections[@]}" == "1" ] && bash_type="alias" || bash_type="function"

    # get/set command name
    local name=""
    if [ ! -z $1 ]; then
      name=$1
    else ##### if no args given, request a name for the alias
      read -p "Please name your bash ${bash_type}: " input
      name=$input
    fi

    # if only one line selected, consider it an alias
    if [[ "${#history_selections[@]}" == "1" ]]; then
      local count=$((current_history_id-history_selections[0]))
      local cmd=$(_clean_history_command ${count} | perl -pe 's/"/\\"/')
      _bash_tack "alias $name=\"$cmd\""
      bashsrc
      echo "Bash alias $name added to your profile"
    else
      # Update the .profile
      _bash_tack "$name () {"
      for _selection in "${history_selections[@]}"; do
        local count=$((current_history_id-_selection))
        local cmd=$(_clean_history_command ${count})
        _bash_tack "  ${cmd}"
      done; unset _selection
      _bash_tack "}"
      bashsrc
    fi
  fi
}
