#!/bin/bash

SESSION="trezor"

cd "$HOME/testes/trezor" && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'


# dcrd

tmux new-window -t $SESSION:1 -n 'dcrd'
tmux send-keys "cd $HOME/projetos/decred/dcrd" C-m
tmux send-keys "./gorun-bin.sh" C-m

# wallet

tmux new-window -t $SESSION:2 -n 'wallet'
tmux send-keys "cd $HOME/projetos/decred/dcrwallet" C-m
tmux send-keys "./gorun.sh"

# trezor bridge

tmux new-window -t $SESSION:3 -n 'bridge'
tmux send-keys "cd trezord-go" C-m
tmux send-keys "sudo /home/user/go/bin/trezord-go -e 21324" C-m

# trezor emulator

tmux new-window -t $SESSION:4 -n 'emulator'
tmux send-keys "cd trezor-mcu" C-m
tmux send-keys "export EMULATOR=1 TREZOR_TRANSPORT_V1=1 DEBUG_LINK=1 TREZOR_OLED_SCALE=2" C-m

# demo-js

tmux new-window -t $SESSION:5 -n 'demojs'
tmux send-keys "cd demo-js" C-m "nvm-enable" C-m
tmux send-keys "yarn dev"

# decrediton

tmux new-window -t $SESSION:6 -n 'decrediton'
tmux send-keys "cd $HOME/projetos/decred/decrediton" C-m "nvm-enable" C-m
tmux send-keys "yarn dev"


# attach
tmux -2 attach-session -t $SESSION
