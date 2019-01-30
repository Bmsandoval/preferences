#!/bin/sh

### setup monitor layout
xrandr \
	--output DisplayPort-0     --mode 1920x1080 --pos    0x0 --rotate normal \
	--output HDMI-0  --primary --mode 1920x1080 --pos 1920x0 --rotate normal \
	--output DisplayPort-1     --mode 1920x1080 --pos 3840x0 --rotate normal \
	--output DVI-1 --off \
	--output DVI-0 --off

### assign workspaces to monitors
# left
#i3-msg '[workspace=1] move workspace to output DisplayPort-0'
#i3-msg '[workspace=4] move workspace to output DisplayPort-0'
#i3-msg '[workspace=7] move workspace to output DisplayPort-0'
# center
#i3-msg '[workspace=2] move workspace to output HDMI-0'
#i3-msg '[workspace=5] move workspace to output HDMI-0'
#i3-msg '[workspace=8] move workspace to output HDMI-0'
# right
#i3-msg '[workspace=3] move workspace to output DisplayPort-1'
#i3-msg '[workspace=6] move workspace to output DisplayPort-1'
#i3-msg '[workspace=9] move workspace to output DisplayPort-1'

### assign applications to workspaces
#i3-msg '[workspace=4] assign [class="Chromium"] workspace'
#i3-msg 'workspace "1"; exec --no-startup-id vivaldi'
#i3-msg 'workspace "2"; exec --no-startup-id pycharm'
#i3-msg 'workspace "3"; exec --no-startup-id spotify'
#i3-msg 'workspace "3"; exec --no-startup-id slack'
