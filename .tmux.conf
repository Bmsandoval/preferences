# -v = split horizontal
# -h = split vertical

# remap prefix from 'C-b' to `
unbind C-b
set -g prefix `
bind-key ` send-prefix

# split panes using | and -
bind \ split-window -h
bind - split-window -v
unbind '"'
unbind %

# switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# keybindings to make resizing easier
bind -r C-j resize-pane -L
bind -r C-k resize-pane -D
bind -r C-i resize-pane -U
bind -r C-l resize-pane -R
