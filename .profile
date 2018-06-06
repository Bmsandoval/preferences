#@IgnoreInspection BashAddShebang
alias serve='php artisan serve --port=8089'
function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
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
        if [[ ! " ${COMMON_BRANCHES[@]} " =~ "${b_array[1]}" ]]; then
            if [[ ! " ${QA_BRANCHES[@]} " =~ "${b_array[1]}" ]]; then
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
        for branch in "${QA_BRANCHES[@]}";
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
	if [[ ! " ${QA_BRANCHES[@]} " =~ "$to_branch" ]]; then
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

# Warn if trying to run Remote commands from Local
alias phpunit="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"
alias composer="echo '$(tput setaf 1)Please run this command from your remote! $(tput sgr 0)'"

# Quickly ssh into servers. Depends on updates to .ssh/config
alias ssh-log1="ssh -t qa-log 'sudo lxc exec team-dev-logistics-1 -- bash; exec $SHELL'"
alias ssh-log2="ssh -t qa-log 'sudo lxc exec team-dev-logistics-2 -- bash; exec $SHELL'"
alias ssh-cron7="ssh -t log-cron-7 'echo \"Logged into logistics php7 cron server. Access cron with.. (sudo crontab -u logistics -e)\"; exec $SHELL'"
alias uu="sudo apt-get update && sudo apt-get upgrade"
alias restart="sudo shutdown -r now"

export HISTTIMEFORMAT="%d/%m/%y %T "
#if [ -f ~/.scripts ]; then
#    . ~/.scripts
#fi
export PATH="~/.scripts:${PATH}"
alias bash-src="source ~/.bashrc"
alias bash-edit="vim ~/.profile"
