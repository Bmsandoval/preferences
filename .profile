#@IgnoreInspection BashAddShebang
alias serve='php artisan serve --port=8089'

function pslisten {
	echo `lsof -n -i4TCP:$1 | grep LISTEN`
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
    echo $1 >> ~/.profile
    bash-src
}
function clean-history-command {
	# Example of line from history Output:
	# 1309  01/06/18 12:46:07 bash-src
	hist=""
	if [ -z $1 ]; then
		# if only one arg given, get last command and parse that instead 
		hist=$(history | tail -n2 | head -n1)
	else
		hist="${1}"
	fi

	# strip line number
	res=$(echo ${hist} | sed -r 's/[0-9]+\s+//')
	# strip date
	res=$(echo ${res} | sed -r 's/[0-9]+\/[0-9]+\/[0-9]+\s+//')
	# strip time
	res=$(echo ${res} | sed -r 's/[0-9]+:[0-9]+:[0-9]+\s+//')
	echo "${res}"
	echo "testing stuff"
}
function _bash-get-clean-history {
	# if no arguments given, will return your last command
	_tail=2; _head=1;

    if [ ! -z $1 ]; then
		_tail=$1
		# if only one arg given, will return last n-1 commands (not including the current one)
        if [ -z $2 ]; then _head="$(($_tail-1))"; fi
	fi
	# if second arg given, allows selection of a range of history lines
    if [ ! -z $2 ]; then _head=$2; fi

	res=$(history | tail -n${_tail} | head -n${_head})
	echo "${res}"
	# remove prefixes so we are left with just the command
	for i in ${!res[*]}; do
		echo "${res[$i]}"
		#echo $(clean-history-command ${res[$i]})
	done

	#for i in ${!res[*]}; do
		#echo "${res[i]}"
	#done

}
function bash-alias {
	# get the command
	cmd=$(clean-history-command)

	# get/set command name
	name=""
	if [ ! -z $1 ]; then
		name=$1
	else
		# if no args given, request a name for the alias 
		read -p "Please name your bash alias: " input 
		name=$input
	fi

	# glue it to the alias, and append it to this file
	bash-append "alias $name=\"$cmd\""
}
function bash-function {
	res=$(history | tail -n10 | head -n9)
	lines=()
	for i in ${!res[*]}; do
		lines+=("${res[i]}")
	done
	echo "$res"
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
