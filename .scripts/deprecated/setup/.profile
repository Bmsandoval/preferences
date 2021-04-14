# source any bash scripts here
#export PATH="/home/sandman/.scripts/setup:${PATH}"
alias bashsetup="vim ~/.scripts/setup/.profile"

# Load the env for this script
_bash-src-env "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
