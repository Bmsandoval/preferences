#!/bin/bash
alias git-logs='git log --oneline --graph'
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
        edit_time=$(echo ${b_array[0]} | sed -r 's/\s+[-+]?[0-9]+\s+?$//')
        edit_times+=("$edit_time")
        branches+=("${b_array[1]}")
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

_git-select-branch () {
	branch=$(git-branches | fzf  --reverse )
	if [ "${branch}" == "" ]; then return; fi
	branch=$(echo ${branch} | sed -r 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} - //')
	echo "${branch}"
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

# Given a package name, returns 1 if package is installed
apt-installed () {
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
apt-install () {
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
	screen -dmS speedtest bash -c 'speedtest-cli | tee ~/.scripts/results/speedtest' ignoreme_arg
}
_net-test-speed-results () {
	sh -c 'tail -n +0 -f ~/.scripts/results/speedtest | { sed "/Upload: / q" && kill $$ ;}'
}

# Warn if trying to run Remote commands from Local
#alias phpunit="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"
#alias composer="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"

uu-classic () {
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
alias bash-src="source ~/.profile"
alias bash-base="vim ~/.bashrc"
alias bash-gen="vim ~/.scripts/general/.profile"
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
bind -x '"\C-\M-;": lock-screen'
## commonly used command, let's give it a few shortcuts
#bind -x '"\C-b": find-command'
alias fc="find-command"
#alias find-command="compgen -A function -abck | fzf --preview 'man -k . | grep ^{}'"
#alias find-command="compgen -A function -abck | fzf --preview \"bat $(readlink -f $(type {} | cut -f 3 -d \' \'))\""
find-command () {
	$(compgen -A function -abck | fzf --preview "bat \$(readlink -f \$(type {} | cut -f 3 -d ' '))")
}

alias be="bash-edit"
bash-edit () {
  # select a file
  location=$(cd $SCRIPTS_LOCATIONS; find . -type f | fzf --preview="bat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
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

#bat $(readlink -f $(type slack.sh | cut -f 3 -d " "))

alias hs="host-ssh"
alias nf="note-edit"
note-find () {
  $(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="bat {} | head -200" --preview-window=right:60%:wrap --multi --reverse)
}

alias ne="note-edit"
note-edit () {
  location=$(cd $NOTES_LOCATIONS; find . -type f | fzf --preview="bat {}" --preview-window=right:60%:wrap --multi --reverse)
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


alias nn="note-new"
note-new () {
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
alias gti="screen -dm chromium-browser --app=https://bsandovalgti.younique-dev.io"
fix-monitor-layout () {
	. ~/.screenlayout/prepareWork.sh && \
	sleep 2
	. ~/.screenlayout/setWork.sh && \
	sleep 2
	. ~/.screenlayout/readyForWork.sh
}

fix-mouse-controls () {
	sudo rmmod psmouse
	sudo modprobe psmouse
	xset m default
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
. /usr/share/undistract-me/long-running.bash
notify_when_long_running_commands_finish_install

net-up-loc () {
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

net-up-rem () {
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

logs-show-recent () {
	find . -type f -mmin -60 -exec stat -c $'%Y\t%n' {} + | sort -nr | cut -f2-
}

alias wanip='dig +short myip.opendns.com @resolver1.opendns.com'

chromium-marquis () {
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







stacks() {
  aws cloudformation list-stacks                      \
    --stack-status                                    \
      CREATE_COMPLETE                                 \
      CREATE_FAILED                                   \
      CREATE_IN_PROGRESS                              \
      DELETE_FAILED                                   \
      DELETE_IN_PROGRESS                              \
      ROLLBACK_COMPLETE                               \
      ROLLBACK_FAILED                                 \
      ROLLBACK_IN_PROGRESS                            \
      UPDATE_COMPLETE                                 \
      UPDATE_COMPLETE_CLEANUP_IN_PROGRESS             \
      UPDATE_IN_PROGRESS                              \
      UPDATE_ROLLBACK_COMPLETE                        \
      UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS    \
      UPDATE_ROLLBACK_FAILED                          \
      UPDATE_ROLLBACK_IN_PROGRESS                     \
    --query "StackSummaries[][
               StackName ,
               StackStatus,
               CreationTime,
               LastUpdatedTime
             ]"                                       \
    --profile dev \
    --output text       |
  sort -b -k 3          |
  column -s$'\t' -t
}


stack-arn() {
  local stacks=$(__bma_read_inputs $@)
  [[ -z ${stacks} ]] && __bma_usage "stack [stack]" && return 1
  local stack
  for stack in $stacks; do
    aws cloudformation describe-stacks \
      --stack-name "$stack"            \
      --query "Stacks[].StackId" \
      --output text
  done
}

stack-cancel-update() {
  local stack=$(_bma_stack_name_arg $(__bma_read_inputs $@))
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation cancel-update-stack --stack-name $stack
}

stack-create() {
  local stack template params # values set by _bma_stack_args()
  _bma_stack_args $@
  if [[ $? -ne 0 ]]; then
    __bma_usage "stack [template-file] [parameters-file] \
                   [--capabilities=OPTIONAL_VALUE] [--role-arn=OPTIONAL_VALUE]"
    return 1
  fi

  if [[ -n "$params" ]]; then local parameters="--parameters file://$params"; fi

  local arn=''
  local capabilities=''
  local inputs_array=($inputs)
  local IFS='=' # override default field separator in the scope of this function only
  local regex_role_arn="^\-\-role\-arn=.*"
  local regex_capabilities="^\-\-capabilities=.*"
  for index in "${inputs_array[@]}" ; do
    if [[ "$index" =~ $regex_role_arn ]] ; then
      read arn_opt arn_arg <<< "$index" # ignore anything after option + arg
      arn="--role-arn $arn_arg"
    elif [[ "$index" =~ $regex_capabilities ]] ; then
      read caps_opt caps_arg <<< "$index" # ignore anything after option + arg
      capabilities="--capabilities $caps_arg"
    fi
  done
  unset IFS # to prevent it from breaking things later

  if aws cloudformation create-stack \
    --stack-name $stack              \
    --template-body file://$template \
    $parameters                      \
    $capabilities                    \
    $arn                             \
    --disable-rollback               \
    --output text
  then
    stack-tail $stack
  fi
}

stack-update() {
  local stack template params # values set by _bma_stack_args()
  _bma_stack_args $@
  if [[ $? -ne 0 ]]; then
    __bma_usage "stack [template-file] [parameters-file] \
                   [--capabilities=OPTIONAL_VALUE] [--role-arn=OPTIONAL_VALUE]"
    return 1
  fi

  if [ -n "$params" ]; then local parameters="--parameters file://$params"; fi

  local capabilities=''
  local capabilities_value=$(_bma_stack_capabilities $stack)
  [[ -z "${capabilities_value}" ]] || capabilities="--capabilities ${capabilities_value}"

  if aws cloudformation update-stack \
    --stack-name $stack              \
    --template-body file://$template \
    $parameters                      \
    $capabilities                    \
    --output text
  then
    stack-tail $stack
  fi
}

stack-delete() {
  # delete an existing stack
  local stacks=$(__bma_read_inputs $@)
  local stack
  [[ -z ${stacks} ]] && __bma_usage "stack [stack]" && return 1
  if ! [ -t 0 ] ; then # if STDIN is not a terminal...
    exec </dev/tty # reattach terminal to STDIN
    local regex_yes="^[Yy]$"
    echo "You are about to delete the following stacks:"
    echo "$stacks" | tr ' ' "\n"
    read -p "Are you sure you want to continue? " -n 1 -r
    echo
    [[ $REPLY =~ $regex_yes ]] || return 0
  fi
  for stack in $stacks; do
    if aws cloudformation delete-stack \
         --stack-name $stack           \
         --output text
    then
      stack-tail "$stack"
    fi
  done
}

# Returns key,value pairs for exports from *all* stacks
# This breaks from convention for bash-my-aws functions
# TODO Find a way to make it more consistent
stack-exports() {
  aws cloudformation list-exports     \
    --query 'Exports[].[Name, Value]' \
    --output text                     |
  column -s$'\t' -t
}

stack-recreate() {
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z "${stack}" ]] && __bma_usage "stack" && return 1

  local capabilities=''
  local capabilities_value=$(_bma_stack_capabilities $stack)
  [[ -z "${capabilities_value}" ]] || capabilities="--capabilities=${capabilities_value}"

  local tmpdir=`mktemp -d /tmp/bash-my-aws.XXXX`
  cd $tmpdir
  stack-template $stack > "${stack}.template"
  stack-parameters $stack > "${stack}-params.json"
  stack-delete $stack
  stack-create $stack \
              "${stack}.template" \
              "${stack}-params.json" \
              $capabilities
  #rm -fr $tmpdir
}

stack-failure() {
  # type: detail
  # return the reason a stack failed to update/create/delete
  # FIXME: only grab the latest failure
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z "${stack}" ]] && __bma_usage "stack" && return 1

  aws cloudformation describe-stack-events \
    --stack-name ${stack}                  \
    --query "
      StackEvents[?contains(ResourceStatus,'FAILED')].[
        PhysicalResourceId,
        Timestamp,
        ResourceStatusReason
      ]" \
    --output text
}

stack-events() {
  # type: detail
  # return the events a stack has experienced
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  if output=$(aws cloudformation describe-stack-events \
    --stack-name ${stack}                  \
    --query "
      sort_by(StackEvents, &Timestamp)[].[
        Timestamp,
        LogicalResourceId,
        ResourceType,
        ResourceStatus
      ]"                                   \
    --output table); then
    echo "$output" | uniq -u
  else
    return $?
  fi
}

stack-resources() {
  # type: detail
  # return the resources managed by a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation describe-stack-resources                       \
    --stack-name ${stack}                                           \
    --query "StackResources[].[ PhysicalResourceId, ResourceType ]" \
    --output text                                                   |
  column -s$'\t' -t
}

stack-asgs() {
  # type: detail
  # return the autoscaling groups managed by a stack
  stack-resources $@                      |
  grep AWS::AutoScaling::AutoScalingGroup |
  column -t
}

stack-asg-instances() {
  # return instances for asg(s) in stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  local asgs=$(stack-asgs "$stack")
  if [[ -n $asgs ]]; then
    asg-instances $asgs
  fi
}

stack-elbs() {
  # type: detail
  # return the elastic load balancers managed by a stack
  stack-resources $@ | 
  grep AWS::ElasticLoadBalancing::LoadBalancer |
  column -t
}

stack-instances() {
  # type: detail
  # return the instances managed by a stack
  local instance_ids=$(stack-resources $@ | grep AWS::EC2::Instance | awk '{ print $1 }')
  [[ -n "$instance_ids" ]] && instances $instance_ids
}

stack-parameters() {
  # return the parameters applied to a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation describe-stacks                        \
    --stack-name ${stack}                                   \
    --query 'sort_by(Stacks[].Parameters[], &ParameterKey)' |
    jq --sort-keys .
}

stack-status() {
  # type: detail
  # return the current status of a stack
  local stacks=$(__bma_read_inputs $@)
  [[ -z ${stacks} ]] && __bma_usage "stack [stack]" && return 1

  local stack
  for stack in $stacks; do
    aws cloudformation describe-stacks                   \
      --stack-name "${stack}"                            \
      --query "Stacks[][ [ StackName, StackStatus ] ][]" \
      --output text
  done
}

stack-tag() {
  # return a selected stack tag
  local tag=$1
  shift 1
  [[ -z "${tag}" ]] && __bma_usage "tag-key stack [stack]" && return 1
  local stacks=$(__bma_read_inputs $@)
  [[ -z ${stacks} && -t 0 ]] && __bma_usage "tag-key stack [stack]" && return 1
  local stack
  for stack in $stacks; do
    aws cloudformation describe-stacks                                       \
      --stack-name "${stack}"                                                \
      --query "Stacks[].[
                 StackName,
                 join(' ', [Tags[?Key=='$tag'].[join('=',[Key,Value])][]][])
               ]"                                                            \
      --output text
  done
}

stack-tag-apply() {
  # apply a stack tag
  local tag_key=$1
  local tag_value=$2
  shift 2
  local usage_msg="tag-key tag-value stack [stack]"
  [[ -z "${tag_key}" ]]    && __bma_usage $usage_msg && return 1
  [[ -z "${tag_value}" ]] && __bma_usage $usage_msg && return 1

  local stacks=$(__bma_read_inputs $@)
  [[ -z "${stacks}" && -t 0 ]] && __bma_usage $usage_msg && return 1

  local stack
  for stack in $stacks; do

    # XXX deal with tagging service failing
    local tags=$(aws cloudformation describe-stacks \
           --stack-name "$stack"                    \
           --query "[
                  [{Key:'$tag_key', Value:'$tag_value'}],
                  Stacks[].Tags[?Key != '$tag_key'][]
                ][]")

    local parameters=$(aws cloudformation describe-stacks \
           --stack-name "$stack"                          \
           --query '
             Stacks[].Parameters[].{
               ParameterKey: ParameterKey,
               UsePreviousValue: `true`
           }')

    local capabilities=''
    local capabilities_value=$(_bma_stack_capabilities $stack)
    [[ -z "${capabilities_value}" ]] || capabilities="--capabilities ${capabilities_value}"

     $([[ -n $DRY_RUN ]] && echo echo) aws cloudformation update-stack \
      --stack-name "$stack"         \
      --use-previous-template       \
      --parameters "$parameters"    \
      --tags "$tags"                \
      $capabilities                 \
      --query StackId               \
      --output text
  done
}

stack-tag-delete() {
  # delete a stack tag
  local tag_key=$1
  shift 1
  [[ -z "${tag_key}" ]] && __bma_usage "tag-key stack [stack]" && return 1

  local stacks=$(__bma_read_inputs $@)
  [[ -z "${stacks}" ]] && __bma_usage "tag-key stack [stack]" && return 1

  local stack
  for stack in $stacks; do

    # XXX deal with tagging service failing
    local tags=$(aws cloudformation describe-stacks \
           --stack-name "$stack"                    \
           --query "[
                  Stacks[].Tags[?Key != '$tag_key'][]
                ][]")

    local parameters=$(aws cloudformation describe-stacks \
           --stack-name "$stack"                          \
           --query '
             Stacks[].Parameters[].{
               ParameterKey: ParameterKey,
               UsePreviousValue: `true`
           }')

    aws cloudformation update-stack \
      --stack-name "$stack"         \
      --use-previous-template       \
      --parameters "$parameters"    \
      --tags "$tags"

  done
}

# Show all events for CF stack until update completes or fails.
stack-tail() {
  # type: detail
  # follow the events occuring for a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  local current
  local final_line
  local output
  local previous
  until echo "$current" | tail -1 | egrep -q "${stack}.*_(COMPLETE|FAILED)"
  do
    if ! output=$(stack-events "$inputs"); then
      # Something went wrong with stack-events (like stack not known)
      return 1
    fi
    if [ -z "$output" ]; then sleep 1; continue; fi

    current=$(echo "$output" | sed '$d')
    final_line=$(echo "$output" | tail -1)
    if [ -z "$previous" ]; then
      echo "$current"
    elif [ "$current" != "$previous" ]; then
      comm -13 <(echo "$previous") <(echo "$current") 2> >(grep -v "not in sorted order")
    fi
    previous="$current"
    sleep 1
  done
  echo $final_line
}

stack-template() {
  # return the template applied to a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})

  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation get-template   \
    --stack-name "$stack"           \
    --query TemplateBody            |
  jq --raw-output --sort-keys .
}

stack-tags() {
  # return the stack-tags applied to a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})

  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation describe-stacks \
    --stack-name "$stack"            \
    --query 'Stacks[0].Tags'         |
  jq --sort-keys .

}

stack-tags-text() {
  # return all stack tags on a single line
  local stacks=$(__bma_read_inputs $@)

  [[ -z ${stacks} ]] && __bma_usage "stack [stack]" && return 1
  local stack
  for stack in $stacks; do
    aws cloudformation describe-stacks                                  \
      --stack-name "${stack}"                                           \
      --query "Stacks[].[
                 StackName,
                 join(' ', [Tags[].[join('=',[Key,Value])][]][])
               ]"                                                       \
      --output text
  done
}

stack-outputs() {
  # type: detail
  # return the outputs of a stack
  local inputs=$(__bma_read_inputs $@)
  local stack=$(_bma_stack_name_arg ${inputs})
  [[ -z ${stack} ]] && __bma_usage "stack" && return 1

  aws cloudformation describe-stacks \
    --stack-name ${stack}            \
    --query 'Stacks[].Outputs[]'     \
    --output text                    |
  column -s$'\t' -t
}

stack-validate() {
  # type: detail
  # validate a stack template
  local inputs=$(__bma_read_inputs $@ | cut -f1)
  [[ -z "$inputs" ]] && __bma_usage "template-file" && return 1
  size=$(wc -c <"$inputs")
  if [[ $size -gt 51200 ]]; then
    # TODO: upload s3 + --template-url
    __bma_error "template too large: $size bytes, 51200 max"
    return 1
  else
    aws cloudformation validate-template --template-body file://$inputs
  fi
}

stack-diff(){
  # type: detail
  # return differences between a template and Stack
  local inputs=$(__bma_read_inputs $@)
  [[ -z "$inputs" ]] && __bma_usage "stack [template-file]" && return 1
  _bma_stack_diff_template $inputs
  [[ $? -ne 0 ]] && __bma_usage "stack [template-file]" && return 1
  echo
  _bma_stack_diff_params $inputs
  [[ $? -ne 0 ]] && __bma_usage "stack [template-file]" && return 1
}

#
# Requires jq-1.4 or later # http://stedolan.github.io/jq/download/
#
_bma_stack_diff_template() {
  # report changes which would be made to stack if template were applied
  local stack template params # values set by _bma_stack_args()
  _bma_stack_args $@
  [[ $? -ne 0 ]] && return 1

  if ! aws cloudformation describe-stacks --stack-name $stack 1>/dev/null; then
    return 1;
  fi
  if [ "x$( type -P colordiff )" != "x" ]; then
    local DIFF_CMD=colordiff
  else
    local DIFF_CMD=diff
  fi

  $DIFF_CMD -u                     \
    --label stack                  \
      <( stack-template $stack)    \
     --label $template             \
       <(jq --sort-keys . $template 2>/dev/null || cat $template )

  if [ $? -eq 0 ]; then
    echo "template for stack ($stack) and contents of file ($template) are the same" >&2
  fi
}

#
# Requires jq-1.4 or later # http://stedolan.github.io/jq/download/
#
_bma_stack_diff_params() {
  # report on what changes would be made to stack by applying params
  local stack template params # values set by _bma_stack_args()
  _bma_stack_args $@
  [[ $? -ne 0 ]] && return 1

  if ! aws cloudformation describe-stacks --stack-name $stack 1>/dev/null; then
    return 1;
  fi
  if [ -z "$params" ]; then
    echo "No params file provided. Skipping" >&2
    return 0
  fi
  if [ ! -f "$params" ]; then
    return 1
  fi
  if [ "x$( type -P colordiff )" != "x" ]; then
    local DIFF_CMD=colordiff
  else
    local DIFF_CMD=diff
  fi

  $DIFF_CMD -u                                   \
    --label params                               \
      <(aws cloudformation describe-stacks       \
          --query "Stacks[].Parameters[]"        \
          --stack-name $stack                    |
        jq --sort-keys 'sort_by(.ParameterKey)') \
    --label $params                              \
      <(jq --sort-keys 'sort_by(.ParameterKey)' $params)

  if [ $? -eq 0 ]; then
    echo "params for stack ($stack) and contents of file ($params) are the same" >&2
  fi
}

# Derive and check arguments for:
#
# - stack-create
# - stack-delete
# - stack-diff
#
# In the interests of making the functions simple and a shallow read,
# it's unusual for us to abstract out shared code like this.
# This bit is doing some funky stuff though and I think it deserves
# to go in it's own function to DRY (Don't Repeat Yourself) it up a bit.
#
# This function takes the unusual approach of writing to variables of the
# calling function:
#
# - stack
# - template
# - params
#
# This is generally not good practice for readability and unexpected outcomes.
# To contain this, the calling functions all clearly declare these three
# variables as local and contain a comment that they will be set by this function.
#
_bma_stack_args(){
  # If we are working from a single argument
  if [[ $# -eq 1 ]]; then # XXX Don't send through --capabilities
    [[ -n "${BMA_DEBUG:-}" ]] && echo "Single arg magic!"

    # XXX Should this be a params file?
    # $ _bma_stack_args params/foo-bar.json
    # template!

    # If it's a params file
    if [[ $1 =~ -params[-.] ]]; then
      [[ -n "${BMA_DEBUG:-}" ]] && echo params!
      stack=$(_bma_derive_stack_from_params ${params:-$1})
      template=$(_bma_derive_template_from_params ${params:-$1})
      params="${1}"

    # If it's a stack
    elif [[ ! $1 =~ [.] ]]; then
      [[ -n "${BMA_DEBUG:-}" ]] && echo stack!
      stack="${1}"
      template=$(_bma_derive_template_from_stack $stack)
      params=$(_bma_derive_params_from_stack_and_template $stack $template)

    # If it's a template
    elif [[ ! $1 =~ -params[-.] && $1 =~ .json|.yaml|.yml  ]]; then
      [[ -n "${BMA_DEBUG:-}" ]] && echo template!
      stack=$(_bma_derive_stack_from_template ${template:-$1})
      template=${1}
      params=$(_bma_derive_params_from_template $template)
    fi

  else
    # There are some other shortcuts available if you use BMA's naming convention
    # See explanation at top of this file
    stack=$(_bma_stack_name_arg $@)
    template=$(_bma_stack_template_arg $@)
    params=$(_bma_stack_params_arg $@)
  fi

  [[ -n "${BMA_DEBUG:-}" ]] && echo "stack='$stack' template='$template' params='$params'"

  if [[ -z ${stack} ]]; then
    __bma_error "Stack name not provided."
  elif [[ ! -f "$template" ]]; then
    __bma_error "Could not find template (${template})."
  elif [[ -n $params && ! -f "$params" ]]; then
    __bma_error "Could not find params file (${params})."
  else
    # Display calling (or current if none) with expanded arguments
    echo "Resolved arguments: $stack $template $params"
  fi


}


##
## Single argument helpers
##

# Look for params file based on stack and template
_bma_derive_params_from_stack_and_template() {
  local stack=$1
  local template=$2
  [[ -z ${stack} || -z ${template} ]] && __bma_usage "stack template" && return 1
  # XXX Usage

  # Strip path and extension from template
  local template_slug=$(basename $template | sed 's/\.[^.]*//')
  # Deduce params filename from stack and template names
  local params_file="${template_slug}-params-${stack#${template_slug}-}.json"

  local target_dir

  for target_dir in . params; do
    candidate="${target_dir}/$params_file"
    if [[ -f "$candidate" ]]; then
      echo $candidate
      break 2
    fi
  done
}


_bma_derive_params_from_template(){
  local template=$1
  local target_dir

  # Strip path and extension from template
  local template_slug=$(basename $template | sed 's/\.[^.]*//')

  for target_dir in . params; do
    candidate="${target_dir}/${template_slug}-params.json"
    if [[ -f "$candidate" ]]; then
      echo $candidate
      break 2
    fi
  done
}


_bma_derive_stack_from_params(){
  local params=$1
  # XXX Usage
  basename $params .json | sed 's/-params//'
}


_bma_derive_stack_from_template(){
  local template=$1
  # XXX Usage
  basename "${template%.*}"
}


_bma_derive_template_from_params(){
  local params=$1
  # XXX Usage

  local template_slug="$(basename ${params%-params*} .json)"

  local target_dir
  if [[ $PWD =~ params$ ]]; then
    target_dir='..'
  else
    target_dir='.'
  fi

  local extension
  for extension in json yml yaml; do
    candidate="${target_dir}/${template_slug}.${extension}"
    if [[ -f "$candidate" ]]; then
      echo $candidate
      break
    fi
  done
}


# Look for template file by repeatedly dropping off last '-*' from stack-name
_bma_derive_template_from_stack() {
  local stack_name=$1

  local target_dir
  if [[ $PWD =~ params$ ]]; then
    target_dir='..'
  else
    target_dir='.'
  fi

  local extension
  while true; do
    for extension in json yml yaml; do
      candidate="${target_dir}/${stack_name}.${extension}"
      if [[ -f "$candidate" ]]; then
        echo $candidate
        break 2
      fi
    done
    [[ ${stack_name%-*} == $stack_name ]] && break 2
    stack_name=${stack_name%-*};
  done
}

#
# Multi-argument helpers
#

_bma_stack_name_arg() {
  # File extension gets stripped off if template name provided as stack name
  if [[ $1 =~ \-\-role\-arn=.*|^\-\-capabilities=.*  ]] ; then
    return 1
  fi
  basename "$1" | sed 's/[.].*$//' # remove file extension
}

_bma_stack_template_arg() {
  # Determine name of template to use
  local stack="$(_bma_stack_name_arg $@)"
  local template=$2
  if [[ -z "$template" || $template =~ ^\-\-role\-arn=.*|^\-\-capabilities=.* ]]; then
    for extension in json yaml yml; do
      if [ -f "${stack}.${extension}" ]; then
        template="${stack}.${extension}"
        break
      elif [ -f "${stack%-*}.${extension}" ]; then
        template="${stack%-*}.${extension}"
        break
      fi
    done
  fi

  [[ -z $template ]] && return 1

  echo $template
}

_bma_stack_params_arg() {
  # determine name of params file to use
  local stack="$(_bma_stack_name_arg $@)"
  local template="$(_bma_stack_template_arg $@)"
  local params=${3:-$(echo $stack | sed "s/\($(basename $template .json)\)\(.*\)/\1-params\2.json/")};
  if [ -f "${params}" ]; then
    echo $params
  fi
}

_bma_stack_capabilities() {
  # determine what (if any) capabilities a given stack was deployed with
  aws cloudformation describe-stacks --stack-name "$1" --query 'Stacks[].Capabilities' --output text
}
