#!/bin/bash

SESSION="split-tickets"

cd "$HOME/projetos/decred" && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'


# dcrd

tmux new-window -t $SESSION:1 -n 'dcrd'
tmux send-keys "cd dcrd" C-m
tmux send-keys "./gorun-bin.sh" C-m

# wallets

tmux new-window -t $SESSION:2 -n 'wallets'
tmux split-window -v
tmux split-window -v
tmux select-layout even-vertical
tmux send-keys -t 0 "cd dcrwallet" C-m "./split-ticket-wallet.sh" C-m
tmux send-keys -t 1 "cd dcrwallet" C-m "./gorun.sh" C-m
tmux send-keys -t 2 "cd dcrwallet" C-m "./wallet2.sh" C-m

# service and first buyer

tmux new-window -t $SESSION:3 -n 'service'
tmux split-window -v
tmux send-keys -t 0 "cd dcr-split-ticket-matcher" C-m "go run ./cmd/dcrstmd" C-m
tmux send-keys -t 1 "cd dcr-split-ticket-matcher" C-m "go run ./cmd/splitticketbuyer"

# second buyer
tmux new-window -t $SESSION:4 -n 'buyer2'
tmux send-keys -t 0 "cd dcr-split-ticket-matcher" C-m "go run ./cmd/dcrstmd -C ~/.splitticketbuyer/wallet2.conf"


# attach
tmux -2 attach-session -t $SESSION
