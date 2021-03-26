#!/bin/bash

# internal scripts live in their own file within this directory
eval source "$(_get-path-to-current-script)/.internal.profile"

vpn_required() {
  local _environment="${1}"
  if [[ "${1}" != "dev" ]] && [[ "${1}" != "prod" ]]; then
    # Must specify a environment to connect to
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
  else
    local _conn="${STRIDE_VPN_USERNAME}@${1}-vpn.stridehealth.io"
    local _active_connections=$(_connected_vpns)
    # If required vpn not active, close all active vpns and connect the one we need
    if [[ ! " ${_active_connections[@]} " =~ " ${_conn} " ]]; then
      if [[ "${#_active_connections[@]}" != "0" ]] && [[ "${_active_connections[0]}" != "" ]]; then
        # Seems like you can only have one active connection at a time
        _vpn_disconnect_all
      fi
      echo "connecting"
      _vpn_connect "${_conn}"
    fi
  fi
}
