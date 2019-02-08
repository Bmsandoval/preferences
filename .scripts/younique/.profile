# easy access to these files
alias bash-yq="vim ~/.scripts/younique/.profile"
alias env-yq="vim ~/.scripts/younique/.env"


yq-transfer() {
	# Get base repo name
    repo=$(basename `git rev-parse --show-toplevel`)
	echo "Deploying for Repo: '${repo}'"

	# Do something if it's a GTI repo
	if [ "${repo}" == "gti" ]; then
    	yq-test-gti
	elif [ "${repo}" == "code" ]; then
	    echo "Not Yet Implemented"
	elif [ "${repo}" == "logistics" ]; then
	    echo "Not Yet Implemented"
	elif [ "${repo}" == "api2" ]; then
	    echo "Not Yet Implemented"
	else
		echo "Error, not in a project folder. Please go to a valid project folder first"
    fi
}

# Interactively select deployment options
# Req : fzf
# Use : $ git-deploy .... Follow CLI Prompts
yq-deploy-gti() {
	echo "Deploy From:"
    from_branch=$(_git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

	echo "Deploy To:"
	to_branch=$(_git-select-branch)
	if [ "${to_branch}" == "" ]; then return; fi
	echo "${to_branch}"; echo ""

	#### Begin Deployment Commands 
	echo "$ git checkout ${to_branch}"
	git checkout $to_branch
	echo "$ git reset --hard ${from_branch}"
	git reset --hard $from_branch
	# DEPRECATED -- can no longer push to exact branch, only to origin
	#echo "$ git push origin ${to_branch} --force"
	#git push origin $to_branch --force
	echo "$ git push origin --force"
	git push origin --force
	echo "$ git checkout ${from_branch}"
	git checkout $from_branch
}
yq-test-gti () {
	ssh dev "cd /var/www/gti/gtil; phpunit $@"
}
yq-test () {
	# Get base repo name
    repo=$(basename `git rev-parse --show-toplevel`)
	echo "Testing on Repo: '${repo}'"

	# Do something if it's a GTI repo
	if [ "${repo}" == "gti" ]; then
    	yq-test-gti
	elif [ "${repo}" == "code" ]; then
	    echo "Not Yet Implemented"
	elif [ "${repo}" == "logistics" ]; then
	    echo "Not Yet Implemented"
	elif [ "${repo}" == "api2" ]; then
	    echo "Not Yet Implemented"
	else
		echo "Error, not in a project folder. Please go to a valid project folder first"
    fi
}
yq-deploy-code () {
	echo "Deploy From:"
	from_branch=$(_git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

    #read -p "Deploy To (EX: team-dev-logistics-1) : " to_branch
#	to_branch=$(printf "%s\n" "${CODE_DEPLOY_LOCATIONS[@]}" | fzf)
#    if [ "${to_branch}" == "" ]; then return; fi
#	echo "codebuild -b $from_branch -s $to_branch"
#	ssh -t dev "codebuild -b $from_branch -s $to_branch"
	#codebuild -b $from_branch -s $to_branch

	echo -n "Name your stack. will affect the url: "
	read stack
	if [ "${stack}" == "" ]; then
		echo "no stack name provided"
		return
	fi
	# Create the stack
	aws cloudformation create-stack \
		--stack-name "${stack}" \
		--template-url  https://s3-us-west-2.amazonaws.com/cf-templates-ngpok2mx4h0d-us-west-2/2019014Ucb-ephemeral-instance.yaml \
		--capabilities CAPABILITY_IAM \
		--parameters ParameterKey=Code,ParameterValue="${from_branch}" \
		--profile dev
}

yq-deploy-api2 () {
	echo "Deploy From:"
	from_branch=$(_git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

    #read -p "Deploy To (EX: team-dev-logistics-1) : " to_branch
	to_branch=$(printf "%s\n" "${CODE_DEPLOY_LOCATIONS[@]}" | fzf)
    if [ "${to_branch}" == "" ]; then return; fi
    #repo=$(basename `git rev-parse --show-toplevel`)
	repo='API_2.0'
	echo "codebuild -r $repo -b $from_branch -s $to_branch"
	ssh -t dev "codebuild -r $repo -b $from_branch -s $to_branch"
}
yq-deploy () {
	# Get base repo name
    repo=$(basename `git rev-parse --show-toplevel`)
	echo "Deploying for Repo: '${repo}'"

	# Do something if it's a GTI repo
	if [ "${repo}" == "gti" ]; then
    	yq-deploy-gti
	elif [ "${repo}" == "code" ]; then
		yq-deploy-code
	elif [ "${repo}" == "logistics" ]; then
        echo "$ leo-cli publish . --awsprofile dev -e dev"
        echo "$ leo-cli deploy . GTIOrderImport --awsprofile dev -e dev"
	elif [ "${repo}" == "api2" ]; then
		yq-deploy-api2
	else
		echo "Error, not in a project folder. Please go to a valid project folder first"
    fi
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
  column -s$'\t' -t
}

test-stacks() {
	stacks | fzf
}

#alias aws-cf-del='aws cloudformation delete-stack --stack-name qa-log-bs --profile dev'
_aws-cf-del () {
	if [ "${1}" == "" ]; then
		echo "don't know what to delete"
		return
	fi
	aws cloudformation delete-stack --stack-name "${1}" --profile dev
}
#alias aws-cf-make=' aws cloudformation create-stack --stack-name qa-log-bs --template-url  https://s3-us-west-2.amazonaws.com/cf-templates-ngpok2mx4h0d-us-west-2/2019014Ucb-ephemeral-instance.yaml --capabilities CAPABILITY_IAM --parameters ParameterKey=Code,ParameterValue=develop --profile dev'
aws-cf-make-instance () {
	aws cloudformation create-stack \
		--stack-name qa-log-bs \
		--template-url  https://s3-us-west-2.amazonaws.com/cf-templates-ngpok2mx4h0d-us-west-2/2019014Ucb-ephemeral-instance.yaml \
		--capabilities CAPABILITY_IAM \
		--parameters ParameterKey=Code,ParameterValue=develop \
		--profile dev
}

_aws-ec2-dns () {
	if [ "${1}" == "" ]; then
		echo "no stack name provided"
		return
	fi
	# Get the physical id (required to get DNS)
	echo "Stack Name: '${1}'"
	PhysID=$(_aws-cf-physID "${stack}")
	echo "Physical ID: ${PhysID}"
	if [ "${PhysID}" != "[]" ]; then
		DnsID=$(_aws-ec2-getDns "${PhysID}")
		echo "DNS name: ${DnsID}"
	fi
}

#alias aws-cf-getPhysId='aws cloudformation describe-stack-resources --stack-name qa-log-bs --profile dev --logical-resource-id EphemeralInstance --query "StackResources[].PhysicalResourceId"'
_aws-cf-physID () {
	VAL=$(aws cloudformation describe-stack-resources --stack-name "${1}" --profile dev --logical-resource-id EphemeralInstance --query "StackResources[].PhysicalResourceId[]")
	VAL=${VAL#*\"}
	VAL=${VAL%\"*}
	echo "${VAL}"
}
#alias aws-ec2-getDns='aws ec2 describe-instances --instance-ids i-06064efdbc4098781 --query "Reservations[].Instances[].PublicDnsName" --profile dev'
_aws-ec2-getDns () {
	VAL=$(aws ec2 describe-instances --instance-ids "${1}" --query "Reservations[].Instances[].PublicDnsName" --profile dev)
	VAL=${VAL#*\"}
	VAL=${VAL%\"*}
	echo "${VAL}"
}
_aws-just-test () {
	testVal="testy-test"
	resVal=$(_aws-cf-physID "${testVal}")
	echo "${resVal}"
}

