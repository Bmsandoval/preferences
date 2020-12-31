#!/usr/bin/osascript

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