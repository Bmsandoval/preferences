#!/bin/bash

net_up_all () {
# Purpose: Run tests against local ips, remote websites, and ssh hosts are all responsive, also runs speedtest
  local _start _netPid

  _start=$(date +%s)
  net_up_local defaults &
  net_up_remote defaults &
  net_up_hosts &
  wait
  echo -e "\nBeginning speedtest, please do not stop script"
  net_speed_test &
  _netPid=$!

  while ps -p $_netPid > /dev/null; do
    echo -ne "."
    sleep 1
  done

	echo -e "\nTesting complete - $(($(date +%s)-_start)) seconds elapsed"
} 2> /dev/null


net_up_local () {
# Purpose: Check that various local ips are responsive
  local _pkgs_req=( "ip" "fping" )
  local _pkgs_miss=()
  for _pkg in "${_pkgs_req[@]}"; do
    which "${_pkg}" > /dev/null || _pkgs_miss+=("${_pkg}")
  done; unset _pkg
  if [[ "${#_pkgs_miss[@]}" != "0" ]]; then
    echo "missing ${#_pkgs_miss[@]} external pkg(s): ${_pkgs_miss[@]}"
    echo "the 'ip' pkg to install on mac is 'iproute2mac'"
  else
    local IP
    if [[ -z "${1}" ]] || [[ "${1}" == "defaults" ]]; then
      read -ra IP <<<"$(ip route | awk '/default/ { print $3 }')"
    else
      read -ra IP <<<"${@}"
    fi
    for ip in ${IP[*]}; do
      fping -c1 -t300 "$ip" 2>/dev/null 1>/dev/null && echo "${ip} is up" || echo "${ip} is down" &
    done
    wait
  fi
} 2>/dev/null

net_up_remote () {
# Purpose: Check that various non-local sites are responsive
  local _sites
  if [[ -z "$1" ]] || [[ "${1}" == "defaults" ]]; then
    _sites=("www.google.com" "www.github.com" "www.amazon.com" "www.slack.com")
  else
    read -ra _sites <<<"${@}"
  fi

  local _pkgs_req=( "wget" )
  local _pkgs_miss=()
  for _pkg in "${_pkgs_req[@]}"; do
    which "${_pkg}" > /dev/null || _pkgs_miss+=("${_pkg}")
  done; unset _pkg
  if [[ "${#_pkgs_miss[@]}" != "0" ]]; then
    echo "missing ${#_pkgs_miss[@]} external pkg(s): ${_pkgs_miss[*]}"
  else
    for _site in "${_sites[@]}"; do
      wget -q --spider "${_site}" && echo "${_site} Online" || echo "${_site} Offline" &
    done; unset _site
    wait
  fi
} 2>/dev/null


net_up_hosts () {
# Purpose: Check that all hosts listed in ~/.ssh/config are responsive
  for _host in $(perl -wlne 'print $1 if /^[\t ]*hostname[^\w]+(.*)$/i' ~/.ssh/config); do
    fping -t 100 -R "${_host}" &
	done; unset _host
	wait
} 2> /dev/null

net_speed_test () {
# Purpose: Run speedtest.net and get upload and download speed, ignore everything else
	speedtest-cli | perl -ne 'print "$1$2\n" if /^(\.+)|(Upload|Download)([^\n]+)/'
}