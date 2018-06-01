# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm|xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    if [[ ${EUID} == 0 ]] ; then
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\h\[\033[01;34m\] \W \$\[\033[00m\] '
    else
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] '
    fi
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h \w \$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
#alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -x /usr/bin/mint-fortune ]; then
     /usr/bin/mint-fortune
fi

alias serve='php artisan serve --port=8089'

alias uu='sudo apt-get update && sudo apt-get upgrade'
alias bash-edit='vim ~/.profile'
alias bash-src='source ~/.profile'
function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
}
function bash-append {
	echo $1 >> ~/.bashrc
	bash-src
}
function clean-history-command {
	# Example of line from history Output:
	# 1309  01/06/18 12:46:07 bash-src

	# strip line number
	res=$(echo "$res" | sed -r 's/[0-9]+\s+//')
	# strip date
	res=$(echo "$res" | sed -r 's/[0-9]+\/[0-9]+\/[0-9]+\s+//')
	# strip time
	res=$(echo "$res" | sed -r 's/[0-9]+:[0-9]+:[0-9]+\s+//')
	echo "$res"
}
function bash-alias {
	# get second to last item from history (last one will be this func call)
	res=$(history | tail -n2 | head -n1)
	# remove prefixes so we are left with just the command
	res=$(clean-history-command $res)

	# glue it to the alias, and append it to this file
	echo "$res"
	#echo "alias $1=\"$res\"" >> ~/.bashrc
	bash-append "alias $1=\"$res\""

	bash-src
}
function bash-function {
	res=$(history | tail -n10 | head -n9)
	lines=()
	for i in ${!res[*]}; do
		#echo $(res | 
		lines+=("${res[i]}")
	done
	echo "$res"
}


export XDEBUG_CONFIG="idekey=PHPSTORM remote_host=127.0.0.1 remote_port=9000"
alias copy_code="~/scripts/copy.sh"

# Func: git-deploy()
# Desc: pushes a selected branch to another branch
# Use : $ deploy feature/somefeature someqa/environment
git-deploy () {
	#### Verify Inputs 
	# Break if less than 2 params
	if [ $# -ne 2 ]; then
		echo "expected 2 inputs, received $#"
		return
	fi
	# Break if param_1 is an invalid git branch 
	temp=$(git rev-parse --verify $1)
	if [[ -z "$temp" ]]; then
		echo "git branch $1 doesn't exist"
		return
	fi
	# Break if param_2 is an invalid git branch 
	temp=$(git rev-parse --verify $2)
	if [[ -z "$temp" ]]; then
		echo "git branch $2 doesn't exist"
		return
	fi

	#### Begin Deployment Commands 
	echo "Deploying from $1 to $2"
	#echo "checking out $2"
	git checkout $2
	echo "Hard resetting head of $2 to match $1"
	git reset --hard $1
	echo "Force updating $2 to head"
	git push origin $2 --force
	#echo "Switching branches back to $1"
	git checkout -
}

# Cool alias, required for following bash function
alias git-all-branches="git for-each-ref --format='%(committerdate:iso8601) %(refname)' --sort -committerdate refs/heads/"

# Variable includes all branches that you will never really push to
shared_branches=("origin" "master" "develop")

# Variable to change to include your qa branches
qa_branches=("deployment/qa" "deployment/qa-2" "team/logistics-1" "team/logistics-2" "team/erp-1" "team/erp-2")

# Func: git-my-branches()
# Desc: returns a list of branches
# Use : $ git-my-branches
my_branches=()
git-my-branches () {
    for ((i=2; i<${#my_branches[@]}; i++)); do unset "my_branches[$i]"; done
	local toRemove="refs\/heads\/"
	local toReplace=","
	local branches=()
	local edit_times=()
	git-all-branches | {
		while IFS= read -r line
		do
			branch="${line/$toRemove/$toReplace}"
			IFS=',' read -r -a b_array <<< "$branch"
			if [[ ! " ${shared_branches[@]} " =~ "${b_array[1]}" ]]; then
			    if [[ ! " ${qa_branches[@]} " =~ "${b_array[1]}" ]]; then
			        edit_times+=("${b_array[0]}")
			        branches+=("${b_array[1]}")
			    fi
			fi
		done
		for i in ${!branches[*]}; do
			my_branches+=("${branches[i]}")
			echo -e "${edit_times[i]},${branches[i]}"
		done
	}
    echo -e "${branches[0]}"
}

git-test () {
	git-my-branches
	echo "$my_branches"
}

git-show-branches () {
	toremove="refs\/heads\/"
	my_branches=()
	my_edit_times=()
	git-all-branches | {
		while IFS= read -r line
		do
			branch="${line/$toremove/','}"
			IFS=',' read -r -a b_array <<< "$branch"
			if [[ ! " ${shared_branches[@]} " =~ "${b_array[1]}" ]]; then
				my_edit_times+=("${b_array[0]}")
				my_branches+=("${b_array[1]}")
			fi
		done
		for i in ${!my_branches[*]}; do
			echo "${my_branches[i]}"
		done
	}
}
# Func: git-deploy-auto
# Desc: interactively select a branch and deploy it to another branch 
# Use : $ git-deploy-auto .... Follow CLI Prompts 
git-deploy-auto () {
	if [ "$1" == "-h" ]; then
		echo "Requests a 'TO' and 'FROM' branch, then migrates the code"
		echo ""
		return
	fi
	echo "------ My Branches ------"
	git-my-branches
	echo "^^^^^^^^^^^^^^^^^^^^^^^^"
	echo "Select a branch from the list above to deploy FROM"
	read -p "Deploy FROM: " input

	IFS=' ' read -r -a branches <<< $(git-show-branches)
	if [[ ! " ${branches[@]} " =~ "$input" ]]; then
		echo "Not a valid branch or cannot deploy FROM here"
		return
	fi
	from_branch=$input

	echo ""
	echo "------ QA Branches ------"
	for branch in "${qa_branches[@]}"
	do
		echo "$branch"
	done
	echo "^^^^^^^^^^^^^^^^^^^^^^^^"
	echo "Select a branch from the list above to deploy TO"
	read -p "Deploy TO: " input

	if [[ ! " ${qa_branches[@]} " =~ "$input" ]]; then
		echo "Not a valid branch or cannot deploy TO here"
		return
	fi
	to_branch=$input

	echo ""
	echo "Do you want to deploy FROM:$from_branch, TO:$to_branch?"
	read -p "(Y)es or (N)o: " input
	echo ""
	if [[ ! "${input[0],}" == "y" ]]; then
		echo "Cancelling"
		return
	fi

	git-deploy $from_branch $to_branch
}

find-and-replace () {
	if [ "$1" == "-h" ]; then
		echo "Provide a value to find and a value to replace it with"
		echo ""
		return
	fi
    # List of directories to ignore. Works recursively.
    ignores=(node_modules .git Vendor)
    ignores=( "${ignores[@]/%/\/*\" }" )
    ignores=( "${ignores[@]/#/-not -path \"*\/}" )
    printf -v cmd_str '%s ' "find . -type f ${ignores[@]} -exec sed -i \"s/$1/$2/g\" {} \;"
    eval "$cmd_str"
}

bash-append () {
	if [ "$1" == "" ]; then
		echo "Won't append empty line."
		echo ""
		return
	fi
    echo $1 >> ~/.bashrc
    bash-src
}

# Warn if trying to run Remote commands from Local
alias phpunit="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"
#alias composer="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"

# SSH CONFIG STUFF
alias ssh-log1="ssh -t qa-log 'sudo lxc exec team-dev-logistics-1 -- bash; exec $SHELL'"
alias ssh-log2="ssh -t qa-log 'sudo lxc exec team-dev-logistics-2 -- bash; exec $SHELL'"
alias ssh-cron7="ssh -t prod-cron 'echo \"Logged into logistics php7 cron server. Access cron with.. (sudo crontab -u logistics -e)\"; exec $SHELL'"

# set enable-bracketed-paste Off
alias disable-bracket-paste='printf "\e[?2004l"'
disable-bracket-paste

export HISTTIMEFORMAT="%d/%m/%y %T "

# source a scripts folder
export PATH="~/.scripts:${PATH}"
