#!/bin/bash

function _vpn_connect {
# Purpose: Try to connect to a Viscosity-maintained VPN

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

