#!/bin/bash

_norts_base_options=\
"\thelp\t:\tshow this menu
\tfind\t:\tfuzzy find a note
\tedit\t:\tfuzzy find and edit a note
\tnew\t:\tcreate a new note"

alias nr="norts"
norts () {
# Purpose: Access notes from commandline
#   I just wanted a simple way to get to notes
#   and cli happens to be where I live.

  case "${1}" in
  'help'|'')
      echo -e "Usage: $ ${FUNCNAME[0]} [option]
Options:
${_norts_base_options}"
  ;;
  'find')
    $(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="cat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
  ;;
  'edit')
    location=$(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="cat {}" --preview-window=right:60%:wrap --multi --reverse)
    echo "${location}"
    # strip leading dot that find leaves behind
    location=${location/./}
    # append path
    location="$NOTES_LOCATIONS/$location"
    # select line
    lines=$(cat -n "$location" | fzf)
    # following 3 lines get the line number that cat -n gave us
    shopt -s extglob
    read -r lines _ <<< "${lines//[^[:digit:] ]/}"
    line=${lines##+(0)}
    # open file at line number
    vim +"${line}" "$location"
  ;;
  'new')
    $(cd $NOTES_LOCATIONS; find . -type d | fzf --preview="tree -C {}" --preview-window=right:60%:wrap --multi --reverse)
  ;;
  esac
}


_fzf_complete_norts () {
  case "${COMP_CWORD}" in
  "1")
#    mapfile -t COMPREPLY <<< "$(compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}")"
#    local reply
#    reply=($(compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}"))
#    read -ra reply <<< $(compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}")
    compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}"
#    echo "${reply}"
#    echo "${reply[*]}"
#    read -a COMPREPLY <<< "$(compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}")"
    COMPREPLY=($(compgen -W "$(echo -e "${_norts_base_options}" | perl -ne 'print "$1 " if /\t([^\t]+)\t/')" "${COMP_WORDS[COMP_CWORD]}"))
  ;;
  esac
}
_fzf_complete_norts_post () {
  perl -ne 'print "$1 " if /\t([^\t]+)\t:/'
}
complete -F _fzf_complete_norts -o default -o bashdefault norts
complete -F _fzf_complete_norts -o default -o bashdefault nr