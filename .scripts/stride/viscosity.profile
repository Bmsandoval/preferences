#!/bin/bash


function vpn_required {
# Purpose: Add new user's ssh public key to the bastion server's s3 bucket
#   This command requires you be logged into AWS SSO. Elegant error handling if not logged in
#   Discreetly requests ssh pub key so key is only in memory and purged once out of context of this function
#   Uses regex to validate that we've received a valid ssh public key. If invalid, shows beginning and end of key
#   Validates provided username doesn't already exist on the box. Prevents deletion of similarly named employee's keys
  local _environment="${1}"
  if [[ "${1}" != "dev" ]] && [[ "${1}" != "prod" ]]; then
    # Must specify a environment to connect to
    echo "Unknown Environment. First argument to this command must be 'dev' or 'prod'"
  else
    local _conn="${STRIDE_VPN_USERNAME}@${_environment}-vpn.stridehealth.io"
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


#    ___ _  _ _____ ___ ___ _  _   _   _
#   |_ _| \| |_   _| __| _ \ \| | /_\ | |
#    | || .` | | | | _||   / .` |/ _ \| |__
#   |___|_|\_| |_| |___|_|_\_|\_/_/ \_\____|
##########################################

function _vpn_connect {
# Purpose: Attempt to connect to a Viscosity-maintained VPN
  osascript <<EOF
tell application "Viscosity" to connect "${1}"
EOF
}


function _connected_vpns {
# Purpose: View all currently connected VPNs as maintained by Viscosity
  osascript <<EOF
tell application "Viscosity"
  set output to ""
  set i to 0
  repeat with _conn in connections
    set i to i + 1
    set _vpn to name of _conn
    set _state to state of _conn
    if _state = "Connected" then
      set output to output & _vpn
      if i < count of connections
        set output to output & "\n"
      end if
    end if
  end repeat
  output
end tell
EOF
}


function _vpn_disconnect_all {
# Purpose: Disconnect from all VPNs maintained by Viscosity
  osascript <<EOF
tell application "Viscosity" to disconnectall
EOF
}
