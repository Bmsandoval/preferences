#!/bin/bash
alias bashgen="vim ~/.scripts/general/.profile"
alias git_logs='git log --oneline --graph'
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

export XDEBUG_CONFIG="idekey=PHPSTORM remote_host=127.0.0.1 remote_port=9000"

# Cool alias, required for following bash function
alias git_all_branches="git for-each-ref --format='%(committerdate:iso8601) %(refname)' --sort -committerdate refs/heads/"

# Use if you want to have a seperate git
# repo within the same folder structure
# as another repo.
# Optionally provide git repo to change to
git_init (){
	git init --bare .git
	git config --unset core.bare
	if [ "$1" != "" ]; then
		git remote add origin $1
	fi
}


# search folders recursively looking for files that contain given word.
#  replaces all occurences in each file with replacement word
find_and_replace () {
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
_bash_append () {
	if [ "$1" == "" ]; then
		echo "Won't append empty line."
		echo ""
		return
	fi
    _bash_tack "$1"
    bash_src
}

# Append line but don't source it
_bash_tack () {
    echo "$1" >> ~/.profile
}

# Get a single command that was run
_clean_history_command () {
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
_bash_range_history_clean () {
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
bash_alias () {
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
    _bash_append "alias $name=\"$cmd\""
    echo "Bash alias $name added to your profile"
}

# Create a function from the last few commands run
bash_function () {
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

# Given a package name, returns 1 if package is installed
apt_installed () {
	if [ "${1}" == "" ]; then
		echo "no argument provided"
		return 1 # empty? just say installed
	elif dpkg --get-selections | grep -q "^${1}[[:space:]]*install$" >/dev/null; then
		echo "${1}: YES"
		return 1 # installed
	else
		echo "${1}: NO"
		return 0 # not installed
	fi
}

## Given a package list file package.list, try:
## sudo apt-get install $(awk '{print $1'} package.list)
apt_install () {
	install_file=~/.scripts/setup/packages.list
	installs=0
	if [ "${1}" == "" ]; then
		packages=($(awk '! /^ *(#|$)/' $install_file))
		for pkg in "${packages[@]}"; do
			#$(apt-installed "${pkg}")
			#echo "installing ${?}"
			#if [ "${?}" -eq "0" ]; then
				sudo apt install -y "${pkg}"
				installs=1
			#fi
		done
	else
    	additions=0
    	# install as many packages as given
		for pkg in "$@"; do
            val=$(grep -x "^${pkg}" $install_file)
			# if it's not in the file, add it
            if [ "${val}" == "" ]; then
                echo "${pkg}" >> "${install_file}"
                echo "Added ${pkg} to ${install_file}"
				#additions=1
            fi

            # optimized installation check
            $(apt-installed "${pkg}")
			# if not installed, install it.
            if [ "${?}" -eq "0" ]; then
                sudo apt install -y "${pkg}"
                installs=1
            fi
		done
		#if [ "$additions" -eq "1" ]; then
		#	echo "" >> $install_file
		#fi
	fi
    if [ "$installs" -eq "0" ]; then
        echo "nothing to install"
    fi
}

tmux_split_cmd () ( tmux split-window -dh -t $TMUX_PANE "bash --rcfile <(echo '. ~/.bashrc;$*')" )

net_hosts_list () {
	grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //'
}
_net_hosts_list () {
	HOSTS=$(grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //')
}

net_test_hosts () {
	_net-hosts-list
	fping ${HOSTS[@]}
}
net_test_external () {
	fping www.google.com www.github.com www.amazon.com www.slack.com
}

_net_test_speed () {
	screen -dmS speedtest bash -c 'speedtest-cli | tee ~/.scripts/results/speedtest' ignoreme_arg
}
_net_test_speed_results () {
	sh -c 'tail -n +0 -f ~/.scripts/results/speedtest | { sed "/Upload: / q" && kill $$ ;}'
}

# Warn if trying to run Remote commands from Local
#alias phpunit="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"
#alias composer="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"

uu_classic () {
	sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
}
uu () {
    STATUS_OK=0
    STATUS_WARNING=1
    STATUS_CRITICAL=2
    STATUS_UNKNOWN=3

    # FAILED TO CHECK FOR UPDATES
    updates=$(/usr/lib/update-notifier/apt-check 2>&1)
    if [ $? -ne 0 ]; then
        echo "Querying pending updates failed."
        return $STATUS_UNKNOWN
    fi

	# UPDATE IF THERE ARE ANY
    if [ "$updates" = "0;0" ]; then
		echo ">>>>> Nothing To Update <<<<<"
    else
		echo ">>>>> Installing Updates <<<<<"
    	sudo apt-get update -y
	fi

	# UPGRADE PACKAGES AS NEEDED
	echo ""
	echo ">>>>> Upgrading If Needed <<<<<"
	sudo apt-get upgrade -y

	# REMOVE OLD PACKAGES AS NEEDED
	echo ""
	echo ">>>>> Cleaning Up If Needed <<<<<"
	sudo apt autoremove -y
}
alias restart="sudo shutdown -r now"
alias shutdown="sudo shutdown now"

export HISTTIMEFORMAT="%d/%m/%y %T "
#if [ -f ~/.scripts ]; then
#    . ~/.scripts
#fi
alias sshedit="vim ~/.ssh/config"
alias tmuxedit="vim ~/.tmux.conf"
alias users_list="cut -d: -f1 /etc/passwd"
alias fix_wifi="echo 'options rtl8188ee swenc=Y ips=N' | sudo tee /etc/modprobe.d/rtl8188ee.conf"

alias list_specs="inxi -Fz"

## Programs to run on boot
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
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

alias be="bash_edit"
bash_edit () {
  # select a file
  location=$(cd $SCRIPTS_LOCATIONS; find . -type f | fzf --preview="cat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
  # strip leading dot that find leaves behind
  location=${location/./}
  # append path
  location="$SCRIPTS_LOCATIONS/$location"
  # select line
  lines=$(cat -n "$location" | fzf)
  # following 3 lines get the line number that cat -n gave us
  shopt -s extglob
  read -r lines _ <<< "${lines//[^[:digit:] ]/}"
  line=${lines##+(0)}
  # open file at line number
  vim +"${line}" "$location"
}
runcmd (){ perl -e 'ioctl STDOUT, 0x5412, $_ for split //, <>' ; }

#cat $(readlink -f $(type slack.sh | cut -f 3 -d " "))

alias hs="host_ssh"
alias nf="note_edit"
note_find () {
  $(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="cat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
}

alias ne="note_edit"
note_edit () {
  location=$(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="cat {}" --preview-window=right:60%:wrap --multi --reverse)
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
mkcd() {
  mkdir -p "$1"
  cd "$1"
}
#[ -f ~/.ssh/config-ext ] && source ~/.ssh/config-ext

# source ssh config extension if it doesn't exist
[ -f ~/.ssh/config-ext ] && source ~/.ssh/config-ext

alias plex="screen -dm chromium-browser --app=https://plex.tv"
alias outlook="screen -dm chromium-browser --app=https://outlook.office.com"
alias teams="screen -dm chromium-browser --app=https://teams.microsoft.com"
alias messages="screen -dm chromium-browser --app=https://messages.google.com/web"
fix_monitor_layout () {
	. ~/.screenlayout/prepareWork.sh && \
	sleep 2
	. ~/.screenlayout/setWork.sh && \
	sleep 2
	. ~/.screenlayout/readyForWork.sh
}

Sudo () {
	local firstArg=$1
	if [ $(type -t $firstArg) == function ]
	then
		shift && $(which sudo) bash -c "$(declare -f $firstArg);$firstArg $*"
	elif [ $(type -t $firstArg) == alias ]
	then
		alias sudo='\sudo '
		eval "sudo $@"
	else
		$(which sudo) "$@"
	fi
}

#alias docker-start-machine='eval $(docker-machine env default)'

#docker-hard-reset-containers () {
#	docker-compose down --remove-orphans
#	docker-compose build --no-cache
#	docker-compose up --force-recreate
#}
#. /usr/share/undistract-me/long-running.bash
#notify_when_long_running_commands_finish_install

net_up_loc () {
	if [[ -z "$1" ]]; then
		IP=($(/sbin/ip route | awk '/default/ { print $3 }'))
		echo "testing default host"
	else
		IP=$@
	fi
	for ip in $IP; do
		fping -c1 -t300 "$ip" 2>/dev/null 1>/dev/null
		if [ "$?" = 0 ]
		then
		  echo "${ip} is up"
		else
		  echo "${ip} is down"
		fi
	done
}

net_up_rem () {
	if [[ -z "$1" ]]; then
		sites=($(/sbin/ip route | awk '/default/ { print $3 }'))
		echo "testing default host"
	else
		sites=$@
	fi
	for site in $sites; do
		wget -q --spider http://google.com

		if [ $? -eq 0 ]; then
			echo "Online"
		else
			echo "Offline"
		fi
	done
}

logs_show_recent () {
	find . -type f -mmin -60 -exec stat -c $'%Y\t%n' {} + | sort -nr | cut -f2-
}

alias wanip='dig +short myip.opendns.com @resolver1.opendns.com'

chromium_marquis () {
	if [[ -z "$1" ]]; then
		echo "no url provided"
	else
		# --incognito if needed
		screen -dm chromium-browser --app="${1}"
	fi
}

# Good idea, but I had 3 monitors plugged in and it showed a count of 4 (unused laptop monitor)
#wallpaper-set-random () {
#	NUM_MONITORS=$(xrandr -d :0 -q | grep ' connected' | wc -l)
#	find dirname -type f | shuf -n "$NUM_MONITORS"
#}
