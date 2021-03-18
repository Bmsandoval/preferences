#!/bin/bash

_vpn_connect() {
  while connection="$1"; shift; do
    osascript <<EOF
tell application "Viscosity" to connect "${connection}"
EOF
  done
}

_connected_vpns() {
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

_vpn_disconnect_all() {
  osascript <<EOF
tell application "Viscosity" to disconnectall
EOF
}

