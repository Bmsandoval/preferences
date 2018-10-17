# easy access to these files
alias bash-yq="vim ~/.scripts/younique/.profile"
alias env-yq="vim ~/.scripts/younique/.env"


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
	echo "$ git push origin ${to_branch} --force"
	git push origin $to_branch --force
	echo "$ git checkout -"
	git checkout -
}
yq-deploy-code () {
	echo "Deploy From:"
	from_branch=$(_git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

    #read -p "Deploy To (EX: team-dev-logistics-1) : " to_branch
	to_branch=$(printf "%s\n" "${CODE_DEPLOY_LOCATIONS[@]}" | fzf)
    if [ "${to_branch}" == "" ]; then return; fi
	codebuild -b $from_branch -s $to_branch

}

yq-deploy-api2 () {
	echo "Deploy From:"
	from_branch=$(_git-select-branch)
	if [ "${from_branch}" == "" ]; then return; fi
	echo "${from_branch}"; echo ""

    #read -p "Deploy To (EX: team-dev-logistics-1) : " to_branch
	to_branch=$(printf "%s\n" "${CODE_DEPLOY_LOCATIONS[@]}" | fzf)
    if [ "${to_branch}" == "" ]; then return; fi
    repo=$(basename `git rev-parse --show-toplevel`)
	codebuild -r $repo -b $from_branch -s $to_branch
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
	elif [ "${repo}bK" == "API_2.0" ]; then
		yq-deploy-api2
	else
		echo "Error, not in a project folder. Please go to a valid project folder first"
    fi
}
