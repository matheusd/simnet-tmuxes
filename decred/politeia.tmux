#!/bin/bash

SESSION="politeia"

cd "$HOME/projetos/decred" && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'

# dcrd

tmux new-window -t $SESSION:1 -n 'dcrd'
tmux send-keys "cd $HOME/projetos/decred/dcrd" C-m
tmux send-keys "./gorun.sh" C-m


# politeia/politeiawww/politeiagui

tmux new-window -t $SESSION:2 -n 'politeia'
tmux split-window -v
tmux split-window -v
tmux select-layout even-vertical
tmux select-pane -t 0
tmux send-keys "cd $HOME/projetos/decred/politeia" C-m
tmux send-keys "politeiad" C-m
tmux select-pane -t 1
tmux send-keys "cd $HOME/projetos/decred/politeia" C-m
tmux send-keys "politeiawww" C-m
tmux select-pane -t 2
tmux send-keys "cd $HOME/projetos/decred/politeiagui" C-m
tmux send-keys "nvm-enable" C-m
tmux send-keys "nvm use v10.2" C-m
tmux send-keys "PORT=3006 yarn start" C-m


# decrediton

tmux new-window -t $SESSION:3 -n 'decrediton'
tmux send-keys "cd $HOME/projetos/decred/decrediton" C-m "nvm-enable" C-m

# decrediton config

tmux new-window -t $SESSION:4 -n 'config'
tmux send-keys "cd $HOME/.config/decrediton" C-m
tmux send-keys "ls" C-m

# attach
tmux -2 attach-session -t $SESSION
