## create an env file if it doesn't exist
if [ ! -f ~/.scripts/younique/.yq-env ]; then
	if [ -f ~/.scripts/younique/.yq-env.ex ]; then
		cp ~/.scripts/younique/.yq-env.ex ~/.scripts/younique/.yq-env
	else
		touch ~/.scripts/younique/.yq-env
	fi
fi
# parse env file. will fail if doesn't exist
set -a
source ~/.scripts/younique/.yq-env
set +a

export PATH="/home/sandman/.scripts/younique:${PATH}"

alias deploy-branch="ssh dev 'codebuild -b develop -s team-dev-logistics-1'"
alias bots-publish="leo-cli publish . --awsprofile dev -e dev"
alias bots-deploy="sudo leo-cli deploy . GTIOrderImport --awsprofile dev -e dev"

