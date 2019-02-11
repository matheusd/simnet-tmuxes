#!/bin/bash

SESSION="decrediton"

cd "$HOME/projetos/decred" && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'

# dcrd

tmux new-window -t $SESSION:1 -n 'dcrd'
tmux send-keys "cd $HOME/projetos/decred/dcrd" C-m
tmux send-keys "./gorun.sh" C-m

# decrediton

tmux new-window -t $SESSION:2 -n 'decrediton'
tmux send-keys "cd $HOME/projetos/decred/decrediton" C-m "nvm-enable" C-m

# decrediton config

tmux new-window -t $SESSION:3 -n 'config'
tmux send-keys "cd $HOME/.config/decrediton" C-m
tmux send-keys "ls" C-m

# attach
tmux -2 attach-session -t $SESSION
