#@IgnoreInspection BashAddShebang

alias serve='php artisan serve --port=8089'
function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
}

## trap ctrl-c to gracefully handle text ui
trap ctrl_c INT
function ctrl_c() {
	tput rc
	tput ed
	echo "Command cancelled..."
}


## create an env file if it doesn't exist
if [ ! -f ~/.scripts/.env ]; then
	if [ -f ~/.scripts/.env.ex ]; then
		cp ~/.scripts/.env.ex ~/.scripts/.env
	else
		touch ~/.scripts/.env
	fi
fi
# parse env file. will fail if doesn't exist
set -a
source ~/.scripts/.env
set +a

export XDEBUG_CONFIG="idekey=PHPSTORM remote_host=127.0.0.1 remote_port=9000"

# Cool alias, required for following bash function
alias git-all-branches="git for-each-ref --format='%(committerdate:iso8601) %(refname)' --sort -committerdate refs/heads/"

# Desc: returns a list of branches
# Use : $ git-branches
git-branches () {
    retArr=()
    #for ((i=2; i<${#retArr[@]}; i++)); do unset "retArr[$i]"; done
	local branches=()
	local edit_times=()
    readarray -t all_branches < <(git-all-branches)
    for i in ${!all_branches[*]}; do
        line="${all_branches[i]}"
        local toRemove='refs/heads/'
        local toReplace=","
        branch="${line/$toRemove/$toReplace}"
        IFS=',' read -r -a b_array <<< "$branch"
        if [[ ! " ${COMMON_BRANCHES[@]} " =~ "${b_array[1]}" ]]; then
            if [[ ! " ${DEPLOYABLE_BRANCHES[@]} " =~ "${b_array[1]}" ]]; then
                edit_time=$(echo ${b_array[0]} | sed -r 's/\s+[-+]?[0-9]+\s+?$//')
                edit_times+=("$edit_time")
                branches+=("${b_array[1]}")
            fi
        fi
    done
    for i in ${!branches[*]}; do
        retArr+=("${branches[i]}")
        if [[ "$1" != *"-n"* ]]; then
            echo -e "${edit_times[i]} - ${branches[i]}"
        fi
    done
}
# Use if you want to have a seperate git
# repo within the same folder structure
# as another repo.
# Optionally provide git repo to change to
git-init (){
	git init --bare .git
	git config --unset core.bare
	if [ "$1" != "" ]; then
		git remote add origin $1 
	fi
}

# Interactively select deployment options
# Use : $ git-deploy .... Follow CLI Prompts
git-deploy () {
	if [ "$1" == "-h" ]; then
		echo "Requests a 'TO' and 'FROM' branch, then migrates the code"
		echo ""
		return
	fi

    # get the from_branch if not provided
	if [ "$1" != "" ]; then
    	from_branch=$1
	else
        tput sc
        echo "------ My Branches ------"
        git-branches
		echo "-------------------------"
        echo "Enter the originating branch "
        read -p "Deploy FROM: " input
        from_branch=$input
        tput rc
        tput ed
	fi
	# Verify the from_branch
    git-branches -n
	if [[ ! " ${retArr[@]} " =~ "$from_branch" ]]; then
		echo "Not a valid branch or cannot deploy FROM here"
		return
	fi

	# get the to_branch if not provided
    if [ "$2" != "" ]; then
        to_branch=$2
    else
        tput sc
        echo "------ QA Branches ------"
        for branch in "${DEPLOYABLE_BRANCHES[@]}";
        do
            echo "$branch"
        done
        echo "-------------------------"
        read -p "Enter the destination branch: " input
		to_branch=$input
        tput rc
        tput ed
    fi
	# Verify the to_branch
	if [[ ! " ${DEPLOYABLE_BRANCHES[@]} " =~ "$to_branch" ]]; then
		echo "Not a valid branch or cannot deploy TO here"
		return
	fi

	#### Begin Deployment Commands 
	echo "$ git checkout $to_branch"
	git checkout $to_branch
	echo "$ git reset --hard $from_branch"
	git reset --hard $from_branch
	echo "$ git push origin $to_branch --force"
	git push origin $to_branch --force
	echo "$ git checkout -"
	git checkout -
}

# search folders recursively looking for files that contain given word.
#  replaces all occurences in each file with replacement word
find-and-replace () {
	if [ "$1" == "-h" ]; then
		echo "Provide a value to find and a value to replace it with"
		echo ""
		return
	fi
    # List of directories to ignore. Works recursively.
    ignores=(node_modules .git Vendor)
	# Fancy magic to make ignores work for command line
    ignores=( "${ignores[@]/%/\/*\" }" )
    ignores=( "${ignores[@]/#/-not -path \"*\/}" )
	# compile command
    printf -v cmd_str '%s ' "find . -type f ${ignores[@]} -exec sed -i \"s/$1/$2/g\" {} \;"
    # run command
    eval "$cmd_str"
}

# Append an entire line to the profile and source it
_bash-append () {
	if [ "$1" == "" ]; then
		echo "Won't append empty line."
		echo ""
		return
	fi
    _bash-tack "$1"
    bash-src
}

# Append line but don't source it
_bash-tack () {
    echo "$1" >> ~/.profile
}

# Get a single command that was run
_clean-history-command () {
	local hist
	retStr=''
    hist="$(history | tail -n$(($1+1)) | head -n1)"

    # Example of line from history Output:
    # 1309  01/06/18 12:46:07 bash-src
	# strip line number
	hist=$(echo ${hist} | sed -r 's/^[0-9]+\s+//')
	# strip date
	hist=$(echo ${hist} | sed -r 's/^[0-9]+\/[0-9]+\/[0-9]+\s+//')
	# strip time
	hist=$(echo ${hist} | sed -r 's/^[0-9]+:[0-9]+:[0-9]+\s+//')
	retStr=$hist
}

# Get a range of commands that were run
_bash-range-history-clean () {
	retArr=()
	# if no arguments given, will return your last command
	_tail=2; _head=1;

	if [ ! -z $1 ]; then
		_tail=$1
		# if only one arg given, will return last n-1 commands (not including the current one)
		if [ -z $2 ]; then _head="$(($_tail))"; fi
	fi
	# if second arg given, allows selection of a range of history lines
	if [ ! -z $2 ]; then _head=$2; fi

	for ((v=$(($_tail)); v>=$(($_head)); v-=1)); do
		# get last command run without all the crap on it
		_clean-history-command "${v}"
		retArr+=("${retStr}")
	done
}

# Create an alias from the last command run
bash-alias () {
	# get the command
	_clean-history-command 1
	cmd=$retStr

	# get/set command name
	name=""
	if [ ! -z $1 ]; then
		name=$1
	else ##### if no args given, request a name for the alias 
		read -p "Please name your bash alias: " input 
		name=$input
	fi
	# escape any double quotes so I can assume surrounding with double quotes
	cmd="${cmd//\"/\\\"}"
	# glue it to the alias, and append it to this file
	# assume double quotes
    _bash-append "alias $name=\"$cmd\""
    echo "Bash alias $name added to your profile"
}

# Create a function from the last few commands run
bash-function () {
	tput sc
	_bash-range-history-clean 9 1
	for i in ${!retArr[*]}; do
		echo "$i : ${retArr[i]}"
	done
	read -p "first: " first
	read -p "last: " last 
	read -p "name: " name 

	# Update the .profile
	_bash-tack "$name () {" 
	for ((v=$(($first)); v<=$(($last)); v+=1)); do
		_bash-tack "${retArr[v]}"
		retArr+=("${retStr}")
	done
	_bash-tack "}"

	# Reset carriage
	tput rc
	tput ed

	bash-src
    echo "Bash function $name() added to your profile"
}

apt-install () {
	install_file=~/.scripts/.install_programs
	if [ "$1" == "" ]; then
		# if no arg given, install all
		xargs -a <(awk '! /^ *(#|$)/' $install_file) -r -- sudo apt-get install -y
	else
		val=$(grep -x "^$1" $install_file)
		if [ "$1" == "" ]; then
			# if it's not in the file, add it
			echo "$1" >> $install_file
		fi
		
		sudo apt install $1
	fi
} 

tmux-split-cmd () ( tmux split-window -dh -t $TMUX_PANE "bash --rcfile <(echo '. ~/.bashrc;$*')" )

net-hosts-list () {
	grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //'
}
_net-hosts-list () {
	HOSTS=$(grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //')
}

net-test-hosts () {
	_net-hosts-list
	fping ${HOSTS[@]}
}
net-test-external () {
	fping www.google.com www.github.com www.amazon.com www.slack.com
}

_net-test-speed () {
	screen -dmS speedtest bash -c 'speedtest-cli | tee .scripts/results/speedtest' ignoreme_arg
}
_net-test-speed-results () {
	sh -c 'tail -n +0 -f .scripts/results/speedtest | { sed "/Upload: / q" && kill $$ ;}'
}

# Warn if trying to run Remote commands from Local
#alias phpunit="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"
#alias composer="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"

# Quickly ssh into servers. Depends on updates to .ssh/config
alias ssh-log1="ssh -t qa-log 'sudo lxc exec team-dev-logistics-1 -- bash; exec $SHELL'"
alias ssh-log2="ssh -t qa-log 'sudo lxc exec team-dev-logistics-2 -- bash; exec $SHELL'"
alias ssh-cron7="ssh -t log-cron-7 'echo \"Logged into logistics php7 cron server. Access cron with.. (sudo crontab -u logistics -e)\"; exec $SHELL'"
alias uu="sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y"
alias restart="sudo shutdown -r now"
alias shutdown="sudo shutdown now"

export HISTTIMEFORMAT="%d/%m/%y %T "
#if [ -f ~/.scripts ]; then
#    . ~/.scripts
#fi
export PATH="/home/sandman/.scripts:${PATH}"
alias bash-src="source ~/.profile"
alias bash-edit="vim ~/.scripts/.profile"
alias ssh-edit="vim ~/.ssh/config"
alias tmux-edit="vim ~/.tmux.conf"
alias users-list="cut -d: -f1 /etc/passwd"
alias fix-wifi="echo 'options rtl8188ee swenc=Y ips=N' | sudo tee /etc/modprobe.d/rtl8188ee.conf"

alias list-specs="inxi -Fz"

## Programs to run on boot
#[ -f ~/.fzf.bash ] && source ~/.fzf.bash
bind -x '"\C-p": vim $(fzf);'
bind -x '"\C-g": git log --pretty=oneline --abbrev-commit | fzf --preview "echo {} | cut -f 1 -d \" \" --reverse | xargs git show --color=always"'
bind -x '"\C-f": cdg'
## commonly used command, let's give it a few shortcuts
############ TODO : CAN i JUST SOURCE MY .PROFILE IN THE PREVIEW???
#bind -x '"\C-b": find-command'
alias fc="find-command"
alias find-command="compgen -A function -abck | fzf --preview 'man -k . | grep ^{}'"

alias nf="note-find"
note-find () {
  target=$(find ~/.notes | fzf --preview="if [[ -f {} ]]; then cat {}; elif [[ -n {} ]]; then tree -C {}; fi" --preview-window=right:60%:wrap --reverse)
  if [[ $target != '' ]]; then
    if [[ -f $target ]]; then
      vim "$target"
      nf
    elif [[ -n $target ]]; then
      cd "$target"
    fi
  fi
}

alias nn="note-new"
note-new () {
  locates=$(find ~/.notes -type d | fzf --preview="tree -C {}" --preview-window=right:60%:wrap --multi --reverse)
}


#bind -x '"\C-n": cdn'
alias f="fzf"
# file previews
export FZF_CTRL_T_OPTS="--preview 'cat {} | head -200'"
#export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
# select the command if it's the last one
export FZF_CTRL_T_OPTS="--select-1 --exit-0 --reverse"

# ctrl+r sort by default
# if [[ -f {} ]]; then cat {}; elif [[ -n {} ]]; then tree -C {}; fi" --preview-window=right:70%:wrap --reverse

#hist=$(echo ${hist} | sed -r 's/^[0-9]+\s+//')

export FZF_CTRL_R_OPTS='--preview="val=\$(cut -d\" \" -f3 <<< \"{}\"); cat ~/.bash_history | sed /^#/d | sed -n \$((\$val-10)),\$((\$val+10))p" --sort --reverse'

# Avoid duplicates
#export HISTCONTROL=ignoredups:erasedups  
# When the shell exits, append to the history file instead of overwriting it
#shopt -s histappend
# After each command, append to the history file and reread it
#export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"
#

# directory previews
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
# full screen searches
export FZF_DEFAULT_OPTS='--height=60% --reverse'

# initialize the iperf server so I can test network speeds against it
#screen -S iperf -d -m iperf -s









#### EXAMPLES
# vf - fuzzy open with vim from anywhere
# ex: vf word1 word2 ... (even part of a file name)
# zsh autoload function
vf() {
  local files

  files=(${(f)"$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 --reverse -0 -1 -m)"})

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
alias fix-monitors="cp .config/monitors.xml{.old,}"