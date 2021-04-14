#!/bin/bash

# Load the env for this script
_bash-src-env "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash || echo "fzf not installed"

alias f="fzf"

bind -x '"\C-p": vim $(fzf);'
bind -x '"\C-g": git log --pretty=oneline --abbrev-commit | fzf --preview "echo {} | cut -f 1 -d \" \" --reverse | xargs git show --color=always"'
bind -x '"\C-f": cdg'
bind -x '"\C-\M-;": lock-screen'
## commonly used command, let's give it a few shortcuts
#bind -x '"\C-b": find-command'

alias ff="find_func"
#alias find-command="compgen -A function -abck | fzf --preview 'man -k . | grep ^{}'"
#alias find-command="compgen -A function -abck | fzf --preview \"cat $(readlink -f $(type {} | cut -f 3 -d \' \'))\""
find_func () {
	$(compgen -A function -abck | fzf --preview "cat \$(readlink -f \$(type {} | cut -f 3 -d ' '))")
}

# integrate fzf with autojump
j() {
    if [[ "$#" -ne 0 ]]; then
        cd $(autojump $@)
        return
    fi
    local dest_dir=$(autojump -s | sed '/_____/Q; s/^[0-9,.:]*\s*//' |  fzf --height 80% --nth 1.. --reverse --inline-info +s --tac --query "${*##-* }" )
    #local dest_dir=$(autojump -s |  fzf --height 80% --nth 1.. --reverse --inline-info +s --tac --query "${*##-* }" )
   if [[ $dest_dir != '' ]]; then
      cd "$dest_dir"
   fi
}

note_find () {
  $(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="cat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
}

alias ne="note_edit"
note_edit () {
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
}

alias nn="note_new"
note_new () {
  locates=$(cd $NOTES_LOCATIONS; find . -type d | fzf --preview="tree -C {}" --preview-window=right:60%:wrap --multi --reverse)
}


#bind -x '"\C-n": cdn'
# file previews
export FZF_CTRL_T_OPTS="--preview 'cat {} | head -200'"
#export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
# select the command if it's the last one
export FZF_CTRL_T_OPTS="--select-1 --exit-0 --reverse"

# ctrl+r sort by default
# if [[ -f {} ]]; then cat {}; elif [[ -n {} ]]; then tree -C {}; fi" --preview-window=right:70%:wrap --reverse

#hist=$(echo ${hist} | sed -r 's/^[0-9]+\s+//')

export FZF_CTRL_R_OPTS='--preview="val=\$(cut -d\" \" -f3 <<< \"{}\"); cat ~/.bash_history | sed /^#/d | sed -n \$((\$val-10)),\$((\$val+10))p" --sort --reverse'

# directory previews
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
# full screen searches
export FZF_DEFAULT_OPTS='--height=60% --reverse'

#### EXAMPLES
# vf - fuzzy open with vim from anywhere
# ex: vf word1 word2 ... (even part of a file name)
# zsh autoload function
vf () {
    local files

    files=("$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 --reverse -0 -1 -m)")

    if [[ -n $files ]]
    then
        vim -- $files
        print -l $files[1]
    fi
}
# cf - fuzzy cd from anywhere
# ex: cf word1 word2 ... (even part of a file name)
# zsh autoload function
cf() {
  local file

  file="$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf  --reverse --read0 -0 -1)"

  if [[ -n $file ]]
  then
     if [[ -d $file ]]
     then
        cd -- $file
     else
        cd -- ${file:h}
     fi
  fi
}
bm() {
	local bookmarks=~/.cdg_paths
	local book=$(grep -x "^$PWD" $bookmarks)
	if [ "$book" == "" ]; then
		# if it's not in the file, add it
		echo "$PWD" >> $bookmarks
	fi
}

gk() {
	guake -n " " -e "$1" --show
}

# cdf - cd into the directory of the selected file
cdf() {
   local file
   local dir
   file=$(fzf +m -q --reverse "$1") && dir=$(dirname "$file") && cd "$dir"
}

# fstash - easier way to deal with stashes
# type fstash to get a list of your stashes
# enter shows you the contents of the stash
# ctrl-d shows a diff of the stash against your current HEAD
# ctrl-b checks the stash out as a branch, for easier merging
fstash() {
  local out q k sha
  while out=$(
    git stash list --pretty="%C(yellow)%h %>(14)%Cgreen%cr %C(blue)%gs" |
    fzf --ansi --reverse --no-sort --query="$q" --print-query \
        --expect=ctrl-d,ctrl-b);
  do
    mapfile -t out <<< "$out"
    q="${out[0]}"
    k="${out[1]}"
    sha="${out[-1]}"
    sha="${sha%% *}"
    [[ -z "$sha" ]] && continue
    if [[ "$k" == 'ctrl-d' ]]; then
      git diff $sha
    elif [[ "$k" == 'ctrl-b' ]]; then
      git stash branch "stash-$sha" $sha
      break;
    else
      git stash show -p $sha
    fi
  done
}
