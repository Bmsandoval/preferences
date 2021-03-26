#!/bin/bash

# internal scripts live in their own file within this directory
eval source "$(_get-path-to-current-script)/.internal.profile"

net_up_local () {
  local _pkgs_req=( "ip" "fping" )
  local _pkgs_miss=()
  for _pkg in "${_pkgs_req[@]}"; do
    which "${_pkg}" > /dev/null || _pkgs_miss+=("${_pkg}")
  done; unset _pkg
  if [[ "${#_pkgs_miss[@]}" != "0" ]]; then
    echo "missing ${#_pkgs_miss[@]} external pkg(s): ${_pkgs_miss[@]}"
    echo "the 'ip' pkg to install on mac is 'iproute2mac'"
  else
    if [[ -z "$1" ]]; then
      IP=($(ip route | awk '/default/ { print $3 }'))
      echo "no hosts provided, testing default hosts"
    else
      IP=$@
    fi
    for ip in $IP; do
      fping -c1 -t300 "$ip" 2>/dev/null 1>/dev/null && echo "${ip} is up" || echo "${ip} is down" &
    done
    wait
  fi
} 2>/dev/null

net_up_remote () {
  local _sites=("www.google.com" "www.github.com" "www.amazon.com" "www.slack.com")
  [[ ! -z "$1" ]] && _sites=$@

  local _pkgs_req=( "wget" )
  local _pkgs_miss=()
  for _pkg in "${_pkgs_req[@]}"; do
    which "${_pkg}" > /dev/null || _pkgs_miss+=("${_pkg}")
  done; unset _pkg
  if [[ "${#_pkgs_miss[@]}" != "0" ]]; then
    echo "missing ${#_pkgs_miss[@]} external pkg(s): ${_pkgs_miss[@]}"
  else
    for _site in "${_sites[@]}"; do
      wget -q --spider "${_site}" && echo "${_site} Online" || echo "${_site} Offline" &
    done; unset _site
    wait
  fi
} 2>/dev/null

# list hosts from ssh config
net_hosts_list () {
	grep -w -i "HostName" ~/.ssh/config | sed 's/[\t ]*Hostname //'
}

net_test_hosts () {
	_net-hosts-list
	fping ${HOSTS[@]}
}

net_test_speed () {
	speedtest-cli | perl -ne 'print "$1$2\n" if /(Upload|Download)([^\n]+)/'
}
