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
	to_branch=$(printf "%s\n" "${CODE_DEPLOY_LOCATIONS[@]}" | fzf)
    if [ "${to_branch}" == "" ]; then return; fi
	echo "codebuild -b $from_branch -s $to_branch"
	ssh -t dev "codebuild -b $from_branch -s $to_branch"
	#codebuild -b $from_branch -s $to_branch

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
