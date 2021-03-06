#!/bin/sh
# Tmux script to create 4 dcrd nodes connected in series. Useful for testing
# message relaying
# Network layout:
# master  <->    1   <-> 2   <-> 3
#  19555     19665   19575   19585


set -e

SESSION="dcrd-serial-nodes"
NODES_ROOT=~/dcrdsimnetnodes
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET_MINING_ADDR="SsWKp7wtdTZYabYFYSc9cnxhwFEjA5g4pFc" # NOTE: This must be changed if the seed is changed.
WALLET_XFER_ADDR="Sso52TPnorVkSaRYzHmi4FgU8F5BFEDZsiK" # same as above

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,1,2,3,wallet}

cat > "${NODES_ROOT}/dcrd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
logdir=./log
datadir=./data
; debuglevel=FEES=DEBUG,TXMP=TRACE
txindex=1
EOF

cat > "${NODES_ROOT}/dcrctl.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
EOF

cat > "${NODES_ROOT}/wallet.conf" <<EOF
username=${RPCUSER}
password=${RPCPASS}
simnet=1
logdir=./log
appdata=./data
pass=123
enablevoting=1
enableticketbuyer=1
ticketbuyer.nospreadticketpurchases=1
ticketbuyer.maxperblock=5
; ticketbuyer.minfee=0.002
EOF

cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

################################################################################
# Setup the master (mining) node
################################################################################

tmux rename-window -t $SESSION:0 'master'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19555 --miningaddr=${WALLET_MINING_ADDR}" C-m
tmux resize-pane -D 15
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

################################################################################
# Setup the wallet
################################################################################

tmux new-window -t $SESSION:1 -n 'wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 15
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
tmux send-keys "./tickets 300"

cat > "${NODES_ROOT}/wallet/xfer" <<EOF
#!/bin/sh
FEE=0.001
case \$1 in
    ''|*[!0-9\.]*) FEE=\`python -c "import random ; print((1e5 + random.expovariate(0.00002)) / 1e8)"\` ;;
    *) FEE=\$1 ;;
esac
./ctl settxfee \$FEE
./ctl sendtoaddress ${WALLET_XFER_ADDR} 0.1
./ctl settxfee 0.001
EOF
chmod +x "${NODES_ROOT}/wallet/xfer"


################################################################################
# Setup the serially connected nodes
################################################################################

cat > "${NODES_ROOT}/1/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf -s 127.0.0.1:19566 \$*
EOF
chmod +x "${NODES_ROOT}/1/ctl"

cat > "${NODES_ROOT}/2/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf -s 127.0.0.1:19576 \$*
EOF
chmod +x "${NODES_ROOT}/2/ctl"

cat > "${NODES_ROOT}/3/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf -s 127.0.0.1:19586 \$*
EOF
chmod +x "${NODES_ROOT}/3/ctl"



tmux new-window -t $SESSION:2 -n 'wallet'
tmux send-keys "cd 1" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19565 --rpclisten :19566 --connect 127.0.0.1:19555 " C-m
tmux split-window -v
tmux select-pane -t 1
tmux send-keys "cd 2" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19575 --rpclisten :19576 --connect 127.0.0.1:19565 " C-m
tmux split-window -v
tmux select-pane -t 2
tmux send-keys "cd 3" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19585 --rpclisten :19586 --connect 127.0.0.1:19575 " C-m
tmux select-layout even-vertical



tmux attach-session -t $SESSION
