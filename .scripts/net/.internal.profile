#!/bin/bash

_net_hosts_list () {
	HOSTS=$(grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //')
}

_net_test_speed_bg () {
	screen -dmS speedtest bash -c 'speedtest-cli | tee ~/.scripts/results/speedtest' ignoreme_arg
}

_net_test_speed_results () {
	sh -c "tail -n +0 -f ~/.scripts/results/speedtest | perl -ne 'print \"$1: $2\n\" if /(Upload|Download): ([^\n]+)/'"
}

