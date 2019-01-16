#!/bin/bash
target=$(fzf < <(cat <(compgen -A function -abck | command grep -i '^ssh-') \
					<(compgen -A function -abck | command grep -i '^rdp-') \
					<(cat ~/.ssh/config /etc/ssh/ssh_config 2> /dev/null \
						| command grep -i '^host ' \
						| command grep -v '[*?]' \
						| awk '{for (i = 2; i <= NF; i++) print $1 " " $i}'\
					)
))
if [[ $target == ssh-* ]]; then
	eval $target
elif [[ $target == Host* ]]; then
	target=$(echo "$target" | sed -r 's/Host//I')
	eval ssh -t $target
fi
