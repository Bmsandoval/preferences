# source any bash scripts here
#export PATH="/home/sandman/.scripts/setup:${PATH}"

package-installed () {
	result=$(compgen -A function -abck | grep ^$1$)
	if [ "${result}" == "$1" ]; then
		# package installed
		return 0
	else
		# package not installed
		return 1
	fi
}
