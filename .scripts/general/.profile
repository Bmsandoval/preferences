#!/bin/bash
alias git_logs='git log --oneline --graph'
alias serve='php artisan serve --port=8089'
function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
}


# Purpose: Used to get user input. Input will be visible in scrollback but not in bash history
_get_user_input() {
  _user_input=""
  trap "echo '' && echo 'received interrupt' && (exit 1); return" SIGINT;
  while [ -z "${_user_input}" ]; do
    printf "${1}: "; read _user_input; printf "\n"
  done
  trap - SIGINT;
}


# Purpose: Used to get user input while hiding the input from both scrollback and bash history
_get_user_input_discreet() {
  stty -echo
  _user_input=""
  trap "stty echo && echo '' && echo 'received interrupt' && (exit 1); return" SIGINT;
  while [ -z "${_user_input}" ]; do
    printf "${1}: "; read _user_input; printf "\n"
  done
  trap - SIGINT;
  stty echo
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


## search folders recursively looking for files that contain given word.
##  replaces all occurences in each file with replacement word
#find_and_replace () {
#	if [ "$1" == "-h" ]; then
#		echo "Provide a value to find and a value to replace it with"
#		echo ""
#		return
#	fi
#    # List of directories to ignore. Works recursively.
#    ignores=(node_modules .git Vendor)
#    # Fancy magic to make ignores work for command line
#    ignores=( "${ignores[@]/%/\/*\" }" )
#    ignores=( "${ignores[@]/#/-not -path \"*\/}" )
#    # compile command
#    printf -v cmd_str '%s ' "find . -type f ${ignores[@]} -exec sed -i \"s/$1/$2/g\" {} \;"
#    # run command
#    eval "$cmd_str"
#}

rand_string () {
  openssl rand -base64 12
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

alias sshedit="vim ~/.ssh/config"
alias tmuxedit="vim ~/.tmux.conf"
alias users_list="cut -d: -f1 /etc/passwd"
alias fix_wifi="echo 'options rtl8188ee swenc=Y ips=N' | sudo tee /etc/modprobe.d/rtl8188ee.conf"

alias list_specs="inxi -Fz"

# initialize the iperf server so I can test network speeds against it
#screen -S iperf -d -m iperf -s

runcmd (){ perl -e 'ioctl STDOUT, 0x5412, $_ for split //, <>' ; }

alias hs="host_ssh"
alias nf="note_edit"

mkcd() {
  mkdir -p "$1"
  cd "$1"
}

# source ssh config extension if it exists
[ -f ~/.ssh/config-ext ] && source ~/.ssh/config-ext

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

#alias meditate="pmset noidle"
alias thermlog="pmset -g thermlog"


function thread_unlock {
# Purpose: Unlock something so someone else can lock it for their use
  rm -rf "${1}.lock"
}


function thread_lock {
# Purpose: Lock something for my own use
  if mkdir "${1}.lock"; then
    return 0 # return success, have lock
  else
    return 1 # return fail, couldn't get lock
  fi
}


function echo_thread_safe {
  local _hadLock=false
  while [ $_hadLock == false ]; do
    if thread_lock "${2}"; then
      echo "got a lock!"
      sh -c "${1}"
      _hadLock=true
      thread_unlock "${2}"
      echo "unlocked!"
      return 0
    fi
  done
}


function echo_thread_not_safe {
  sh -c "${1}"
}


function thread_safe_example {
  echo "starting process ${1}"
  local SLEEP=0
  local _sleep=$((1 + RANDOM % 3))
  SLEEP=$((SLEEP+_sleep))
  sleep $_sleep
  local OUTPUT='process '"${1}"' slept '"${SLEEP}"' seconds'
  echo_thread_safe 'echo '"${OUTPUT}"'; echo '"${OUTPUT}"'; echo '"${OUTPUT}"'' "${2}"
  SLEEP=$((SLEEP+1+_sleep))
  sleep $((1+_sleep))
  echo "process ${1} finished after ${SLEEP} seconds"
}


function thread_unsafe_example {
  echo "starting process ${1}"
  local SLEEP=0
  local _sleep=$((1 + RANDOM % 3))
  SLEEP=$((SLEEP+_sleep))
  sleep $_sleep
  local OUTPUT='process '"${1}"' slept '"${SLEEP}"' seconds'
  echo_thread_not_safe 'echo '"${OUTPUT}"'; echo '"${OUTPUT}"'; echo '"${OUTPUT}"'' "${2}"
  SLEEP=$((SLEEP+1+_sleep))
  sleep $((1+_sleep))
  echo "process ${1} finished after ${SLEEP} seconds"
}


function thread_safe_proofing {
  for i in {1..10}; do
    thread_unsafe_example "${i}" &
  done
  wait

  local _td=$(date +%s)
  for i in {11..20}; do
    thread_safe_example "${i}" "${_td}" &
  done
  wait
} 2>/dev/null
