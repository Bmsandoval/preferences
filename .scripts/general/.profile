#!/bin/bash
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
