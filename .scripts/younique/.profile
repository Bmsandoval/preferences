#!/bin/bash
# easy access to these files
alias bash-yq="vim ~/.scripts/younique/.profile"
alias env-yq="vim ~/.scripts/younique/.env"

_yq-git-select-branch () {
	branch=$(_yq-git-branches | fzf  --reverse )
	if [ "${branch}" == "" ]; then return; fi
	branch=$(echo ${branch} | sed -r 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} - //')
	echo "${branch}"
}

# Interactively select deployment options
# Req : fzf
# Use : $ git-deploy .... Follow CLI Prompts
_yq-deploy-gti() {
	echo "Deploy From:"
    from_branch=$(_yq-git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

	echo "Deploy To:"
	to_branch=$(_yq-git-select-branch)
	if [ "${to_branch}" == "" ]; then return; fi
	echo "${to_branch}"; echo ""

	#### Begin Deployment Commands 
	echo "$ git checkout ${to_branch}"
	git checkout $to_branch
	echo "$ git reset --hard ${from_branch}"
	git reset --hard $from_branch
	echo "$ git push origin --force"
	git push origin --force
	echo "$ git checkout ${from_branch}"
	git checkout $from_branch
}

_yq-git-branches () {
    retArr=()
	local branches=()
	local edit_times=()
    readarray -t all_branches < <(git for-each-ref --format='%(committerdate:iso8601) %(refname)' --sort -committerdate refs/heads/)
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

_yq-deploy-general () {
	if [[ "${1}" == "" ]]; then
		echo "no repo specified"
		return
	fi

	branch=$(_yq-git-branches | fzf  --reverse )
	if [ "${branch}" == "" ]; then return; fi
	from_branch=$(echo ${branch} | sed -r 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} - //')

	if [ "${from_branch}" == "" ]; then return; fi
	echo "Deploying from: ${from_branch}"; echo ""

	# Strip special characters from branch name
	stack=`echo ${from_branch} | tr -cd "[:alnum:]\n"`

	# Create the stack
	aws cloudformation create-stack \
		--stack-name "${stack}" \
		--template-url  https://s3-us-west-2.amazonaws.com/cf-templates-ngpok2mx4h0d-us-west-2/2019014Ucb-ephemeral-instance.yaml \
		--capabilities CAPABILITY_IAM \
		--parameters ParameterKey="${1}",ParameterValue="${from_branch}" \
		--profile dev

	# Get the physical ID (required for getting dnsaddress)
	local physID
	for i in $(seq 1 5);
	do 
		physID=`aws cloudformation describe-stack-resources --stack-name "${stack}" --profile dev --logical-resource-id EphemeralInstance --query "StackResources[].PhysicalResourceId[]" --output text`
		if [ "${physID}" != "[]" ] && [ "${physID}" != "" ]; then
			break
		fi
		sleep 2; 
	done

	# Get the DNS address (required for accessing box remotely)
	local dnsAddress
	for i in $(seq 1 5);
	do 
		dnsAddress=`aws ec2 describe-instances --instance-ids "${physID}" --query "Reservations[].Instances[].PublicDnsName" --profile dev`
		if [ "${dnsAddress}" != "[]" ] && [ "${dnsAddress}" != "" ]; then
			break
		fi
		sleep 2; 
	done

	echo "Stack: ${stack}"
	echo "Dns: ${dnsAddress}"
	echo -e "Delete stack with:\n$ yq-aws-stack-delete ${stack}"
}

yq-deploy () {
	# Get base repo name
    repo=$(basename `git rev-parse --show-toplevel`)
	echo "Deploying for Repo: '${repo}'"

	# Do something if it's a GTI repo
	if [ "${repo}" == "gti" ]; then
    	_yq-deploy-gti
	elif [ "${repo}" == "code" ]; then
		_yq-deploy-general Code
	elif [ "${repo}" == "logistics" ]; then
        echo "$ leo-cli publish . --awsprofile dev -e dev"
        echo "$ leo-cli deploy . GTIOrderImport --awsprofile dev -e dev"
	elif [ "${repo}" == "api2" ]; then
		_yq-deploy-general Arwen
	else
		echo "Error, not in a project folder. Please go to a valid project folder first"
    fi
}

#alias aws-cf-del='aws cloudformation delete-stack --stack-name qa-log-bs --profile dev'
yq-aws-stack-delete () {
	if [ "${1}" == "" ]; then
		echo "don't know what to delete"
		return
	fi
	aws cloudformation delete-stack --stack-name "${1}" --profile dev
	echo "Delete request sent for stack ${1}. May still take a bit to fully delete on AWS' side."
}

yq-snap-info () {
	instance=""
	if [ "${1}" == "mex" ]; then
		instance="${SNAP_LIVE_MEX}"
	elif [ "${1}" == "lehi" ]; then
		instance="${SNAP_LIVE_LEHI}"
	elif [ "${1}" == "nld" ]; then
		instance="${SNAP_LIVE_NLD}"
	elif [ "${1}" == "njus" ]; then
		instance="${SNAP_LIVE_NJUS}"
	else
		echo "no instance provided, select 1 of {mex, lehi, nld, njus}"
		return
	fi
	if [ "${2}" == "" ]; then
		echo "no package number provided, please provide a package number"
		return
	fi
	echo "http get ${1}.snapfulfil.net/api/Shipments/${2}"
	http get "${instance}".snapfulfil.net/api/Shipments/"${2}" -a "${SNAP_LIVE_USER}":"${SNAP_LIVE_PASS}"
	#_yq-snap-get-info "${instance}" "${2}"
}

_yq-snap-get-info () {
	echo "http get ${1}.snapfulfil.net/api/Shipments/${2}"
	http get "${1}".snapfulfil.net/api/Shipments/"${2}" -a "${SNAP_LIVE_USER}":"${SNAP_LIVE_PASS}" | \
		python -c <<EOF
	import sys, json; print json.load(sys.stdin)["answer"][0]["rdata"]
EOF
}

alias aws-sqs-stats="screen -dm chromium-browser --app=https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=Logistics --incognito"

alias aws-cf-list='aws cloudformation list-stacks --query "StackSummaries[*].StackName" --profile dev --no-paginate'

aws-cf-activestacks() {

  #local filters=$(__bma_read_filters $@)

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
	--profile dev\
    --output text       |
  #grep -E -- "$filters" |
  sort -b -k 3          |
  column -s$'\t' -t | fzf
}

test-stacks() {
	stacks | fzf
}

leela-clone() {
	git clone git@repo.younique-dev.io:leela
	cd leela
	git remote set-url --push origin git@github.com:youniquellc/leela
	git submodule sync --recursive
	git submodule update --init --force --remote --recursive
	git submodule foreach 'git remote set-url --push origin git@github.com:youniquellc/$name'
	git submodule foreach 'git checkout develop'
	git submodule foreach 'git pull'
}

#######################################################################
#######################################################################
############                 FOR REFERENCE               #############
#######################################################################
#######################################################################
# https://github.com/bash-my-universe/bash-my-aws/blob/master/lib/stack-functions
#######################################################################
#######################################################################

