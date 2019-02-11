#!/bin/sh

# Tmux setup for running an spv wallet. This creates two wallets (connected to
# the same master node): one using regular RPC mode with the ticketbuyer and
# voting enabled and a second one with SPV enabled. It receives some coins
# after block 32.
#
# The spv wallet is created in the "spv" dir.

set -e

SESSION="dcrd-spv"
NODES_ROOT=~/dcrdsimnetnodes
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET_MINING_ADDR="SsWKp7wtdTZYabYFYSc9cnxhwFEjA5g4pFc" # NOTE: This must be changed if the seed is changed.

SPV_WALLET_SEED="1111111111111111111111111111111111111111111111111111111111111111"


if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,wallet,spv}

#############################
# Config Files
#############################

cat > "${NODES_ROOT}/dcrd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
logdir=./log
datadir=./data
txindex=1
; debuglevel=TXMP=TRACE,MINR=TRACE,CHAN=TRACE
EOF

cat > "${NODES_ROOT}/dcrctl.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
EOF

cat > "${NODES_ROOT}/wallet/wallet.conf" <<EOF
username = ${RPCUSER}
password = ${RPCPASS}
simnet = 1
logdir = ./log
appdata = ./data
pass = 123
enablevoting = 1
enableticketbuyer = 1
ticketbuyer.nospreadticketpurchases = 1
ticketbuyer.maxperblock = 5
; ticketbuyer.minfee = 0.002
EOF

cat > "${NODES_ROOT}/spv/wallet.conf" <<EOF
username = ${RPCUSER}
password = ${RPCPASS}
simnet = 1
logdir = ./log
appdata = ./data
pass = 123
spv = 1
spvconnect = 127.0.0.1:19555
rpclisten = 127.0.0.1:19567
nogrpc = 1
EOF


#############################
# Scripts
#############################

#  Master Node

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


# RPC Wallet

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

cat > "${NODES_ROOT}/wallet/xfer" <<EOF
#!/bin/sh
./ctl sendtoaddress \`./ctl getnewaddress\` 0.1
EOF
chmod +x "${NODES_ROOT}/wallet/xfer"


# SPV Wallet

cat > "${NODES_ROOT}/spv/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf --wallet -c ./data/rpc.cert --walletrpcserver 127.0.0.1:19567 \$*
EOF
chmod +x "${NODES_ROOT}/spv/ctl"



#############################
# Windows
#############################

cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'

tmux new-window -t $SESSION:1 -n 'master'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19555 --miningaddr=${WALLET_MINING_ADDR}" C-m
tmux resize-pane -D 10
tmux select-pane -t 1
tmux send-keys "cd master" C-m

sleep 3
tmux send-keys "./ctl generate 32" C-m


tmux new-window -t $SESSION:2 -n 'rpc-wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 10
tmux send-keys "cd wallet" C-m
tmux send-keys "dcrwallet -C ./wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ./wallet.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd wallet" C-m "sleep 25" C-m
tmux send-keys "./ctl sendtoaddress Ssoaqgx4ecmHX54LqrUXgqi6miUFxP9iUvc 1000" C-m

tmux new-window -t $SESSION:3 -n 'spv-wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 10
tmux send-keys "cd spv" C-m
tmux send-keys "dcrwallet -C ./wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${SPV_WALLET_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ./wallet.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd spv" C-m


# Attach to session

tmux attach-session -t $SESSION
