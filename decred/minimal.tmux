#!/bin/sh
# Minimal tmux script to create a master dcrd simnet node + ticket
# bying wallet. Heavily based on davecgh script at:
# https://gist.github.com/davecgh/7bb5c995665787811dc6a6ddbb49688d

set -e
set -x

SESSION="dcrd-minimal"
NODES_ROOT=~/dcrdsimnetnodes
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET_MINING_ADDR="SsWKp7wtdTZYabYFYSc9cnxhwFEjA5g4pFc" # NOTE: This must be changed if the seed is changed.
WALLET_XFER_ADDR="Sso52TPnorVkSaRYzHmi4FgU8F5BFEDZsiK" # same as above

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,wallet}

cat > "${NODES_ROOT}/dcrd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
logdir=./log
datadir=./data
txindex=1
debuglevel=TXMP=TRACE,MINR=TRACE,CHAN=TRACE
EOF

cat > "${NODES_ROOT}/dcrctl.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
EOF

cat > "${NODES_ROOT}/wallet.conf" <<EOF
username = ${RPCUSER}
password = ${RPCPASS}
simnet = 1
logdir = ./log
appdata = ./data
pass = 123
enablevoting = 1
; enableticketbuyer = 1
; purchaseaccount = ticketbuyer
EOF

cat > "${NODES_ROOT}/dcrdata.conf" <<EOF
dcrdserv = localhost:19556
dcrduser = ${RPCUSER}
dcrdpass = ${RPCPASS}
appdata = ${NODES_ROOT}/dcrdata
simnet = 1
EOF

cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'master'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19555 --miningaddr=${WALLET_MINING_ADDR}" C-m
tmux resize-pane -D 5
tmux select-pane -t 1
tmux send-keys "cd master" C-m

cat > "${NODES_ROOT}/master/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf \$*
EOF
chmod +x "${NODES_ROOT}/master/ctl"

cat > "${NODES_ROOT}/master/mine" <<EOF
#!/bin/sh
NUM=1
case \$1 in
    ''|*[!0-9]*)  ;;
    *) NUM=\$1 ;;
esac

for i in \$(seq \$NUM) ; do
  dcrctl -C ../dcrctl.conf generate 1
  sleep 0.3
done
EOF
chmod +x "${NODES_ROOT}/master/mine"
sleep 3
tmux send-keys "./ctl generate 32" C-m


tmux new-window -t $SESSION:1 -n 'wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 5
tmux send-keys "cd wallet" C-m
tmux send-keys "dcrwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ../wallet.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd wallet" C-m

cat > "${NODES_ROOT}/wallet/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf --wallet -c ./data/rpc.cert \$*
EOF
chmod +x "${NODES_ROOT}/wallet/ctl"

cat > "${NODES_ROOT}/wallet/tickets" <<EOF
#!/bin/sh
NUM=1
case \$1 in
    ''|*[!0-9]*) ;;
    *) NUM=\$1 ;;
esac

./ctl purchaseticket default 999999 1 \`./ctl getnewaddress\` \$NUM
EOF
chmod +x "${NODES_ROOT}/wallet/tickets"
tmux send-keys "sleep 15" C-m
tmux send-keys "./ctl createnewaccount ticketbuyer" C-m
tmux send-keys "./ctl sendtoaddress \`./ctl getnewaddress ticketbuyer\` 1" C-m
sleep 20
tmux select-pane -t 0
tmux send-keys C-c
tmux send-keys "dcrwallet -C ../wallet.conf --purchaseaccount ticketbuyer --enableticketbuyer" C-m


cat > "${NODES_ROOT}/wallet/xfer" <<EOF
#!/bin/sh
./ctl sendtoaddress ${WALLET_XFER_ADDR} 0.1
EOF
chmod +x "${NODES_ROOT}/wallet/xfer"


#tmux attach-session -t $SESSION
