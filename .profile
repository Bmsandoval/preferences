#@IgnoreInspection BashAddShebang
alias serve='php artisan serve --port=8089'

function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
}

export XDEBUG_CONFIG="idekey=PHPSTORM remote_host=127.0.0.1 remote_port=9000"
alias copy_code="~/scripts/copy.sh"

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
	tput sc
	#### Verify Inputs 
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
	if [[ ! "${input[0]}" == "y" ]]; then
		echo "Cancelling"
		return
	fi

	git-deploy $from_branch $to_branch

	# Clear the screen
	tput rc
	tput ed

	#### Begin Deployment Commands 
	echo "git checkout $to_branch"
	git checkout $to_branch
	echo "git reset --hard $from_branch"
	git reset --hard $from_branch
	echo "git push origin $to_branch --force"
	git push origin $to_branch --force
	echo "git checkout -"
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
    ignores=( "${ignores[@]/%/\/*\" }" )
    ignores=( "${ignores[@]/#/-not -path \"*\/}" )
    printf -v cmd_str '%s ' "find . -type f ${ignores[@]} -exec sed -i \"s/$1/$2/g\" {} \;"
    eval "$cmd_str"
}

# Append an entire line to the profile and source it
bash-append () {
	if [ "$1" == "" ]; then
		echo "Won't append empty line."
		echo ""
		return
	fi
    echo $1 >> ~/.profile
    bash-src
}

# Append line but don't source it
_bash-tack () {
    echo $1 >> ~/.profile
}

# Get a single command that was run
function clean-history-command {
	local hist
	retStr=''
	# Example of line from history Output:
	# 1309  01/06/18 12:46:07 bash-src
	if [[ "$1" == "" ]]; then
		# if only one arg given, get last command and parse that instead 
		hist="$(history | tail -n2 | head -n1)"
	else
		hist="$(history | tail -n$(($1)) | head -n1)"
	fi

	# strip line number
	hist=$(echo ${hist} | sed -r 's/^[0-9]+\s+//')
	# strip date
	hist=$(echo ${hist} | sed -r 's/^[0-9]+\/[0-9]+\/[0-9]+\s+//')
	# strip time
	hist=$(echo ${hist} | sed -r 's/^[0-9]+:[0-9]+:[0-9]+\s+//')
	retStr=$hist
}

# Get a range of commands that were run
function bash-range-history-clean {
	retArr=()
	# if no arguments given, will return your last command
	_tail=2; _head=1;

	if [ ! -z $1 ]; then
		_tail=$1
		# if only one arg given, will return last n-1 commands (not including the current one)
		if [ -z $2 ]; then _head="$(($_tail-1))"; fi
	fi
	# if second arg given, allows selection of a range of history lines
	if [ ! -z $2 ]; then _head=$2; fi

	for ((v=$(($_tail)); v>$(($_head)); v-=1)); do
		# get last command run without all the crap on it
		clean-history-command "${v}"
		retArr+=("${retStr}")
	done
}

# Create an alias from the last command run
function bash-alias {
	# get the command
	clean-history-command
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
	echo "alias $name=\"$cmd\""
	bash-append "alias $name=\"$cmd\""
}

# Create a function from the last few commands run
function bash-function {
	tput sc
	bash-range-history-clean 9 1
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

	echo "Bash function $name() added to your profile"
	bash-src
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
