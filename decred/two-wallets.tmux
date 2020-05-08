#!/bin/sh
#
# tmux script to generate two wallets: one ticket buying/voting wallet
# and a second one, empty and ready to be used from scratch. Useful for testing
# things in the wallet itself without having all the noise of the ticketbuyer.
#
# This is based on the parallel-nodes layout, with beta configured to *not* be
# mining.
#
#             alpha  <------>  beta
#    listen   19100           19200
# rpclisten   19101 <.     .> 19201
#           w-alpha  |     | w-beta
# rpclisten   19102           19202
#
# For simplicity, node "beta" is configured to connect to node "alpha" via
# --connect on the command line, so that you can easily disconnect the nodes
# by stopping beta, removing the --connect, then restarting it.

set -e

SESSION="dcrd-parallel-nodes"
NODES_ROOT=~/dcrdsimnetnodes
RPCUSER="USER"
RPCPASS="PASS"
WALLET01_SEED="1111111111111111111111111111111111111111111111111111111111111111"
WALLET02_SEED="2222222222222222222222222222222222222222222222222222222222222222"
WALLET01_MININGADDR="Ssoaqgx4ecmHX54LqrUXgqi6miUFxP9iUvc"

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{alpha,beta,w-alpha,w-beta}

# Config Files

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
username=${RPCUSER}
password=${RPCPASS}
simnet=1
logdir=./log
appdata=./data
pass=123
nogrpc = 1
EOF

cat > "${NODES_ROOT}/dcrdata.conf" <<EOF
dcrdserv = localhost:19101
dcrduser = ${RPCUSER}
dcrdpass = ${RPCPASS}
appdata = ${NODES_ROOT}/dcrdata
simnet = 1
EOF

cp ${NODES_ROOT}/dcrd.conf ${NODES_ROOT}/alpha
cat >> ${NODES_ROOT}/alpha/dcrd.conf <<EOF
listen = 127.0.0.1:19100
rpclisten = 127.0.0.1:19101
miningaddr = ${WALLET01_MININGADDR}
EOF
cp ${NODES_ROOT}/dcrctl.conf ${NODES_ROOT}/alpha
cat >> ${NODES_ROOT}/alpha/dcrctl.conf <<EOF
rpcserver = 127.0.0.1:19101
EOF
cp ${NODES_ROOT}/dcrctl.conf ${NODES_ROOT}/w-alpha
cat >> ${NODES_ROOT}/w-alpha/dcrctl.conf <<EOF
walletrpcserver = 127.0.0.1:19102
EOF


# Use miningaddr from wallet01 so we don't fund wallet02 prematurely
cp ${NODES_ROOT}/dcrd.conf ${NODES_ROOT}/beta
cat >> ${NODES_ROOT}/beta/dcrd.conf <<EOF
listen = 127.0.0.1:19200
rpclisten = 127.0.0.1:19201
miningaddr = ${WALLET01_MININGADDR}
EOF
cp ${NODES_ROOT}/dcrctl.conf ${NODES_ROOT}/beta
cat >> ${NODES_ROOT}/beta/dcrctl.conf <<EOF
rpcserver = 127.0.0.1:19201
EOF
cp ${NODES_ROOT}/dcrctl.conf ${NODES_ROOT}/w-beta
cat >> ${NODES_ROOT}/w-beta/dcrctl.conf <<EOF
walletrpcserver = 127.0.0.1:19202
EOF

# Node Scripts

cat > "${NODES_ROOT}/alpha/ctl" <<EOF
#!/bin/sh
dcrctl -C ./dcrctl.conf \$*
EOF
chmod +x "${NODES_ROOT}/alpha/ctl"

cat > "${NODES_ROOT}/alpha/mine" <<EOF
#!/bin/sh
NUM=1
case \$1 in
    ''|*[!0-9]*)  ;;
    *) NUM=\$1 ;;
esac

for i in \$(seq \$NUM) ; do
  dcrctl -C ./dcrctl.conf generate 1
  sleep 0.3
done
EOF
chmod +x "${NODES_ROOT}/alpha/mine"


cp ${NODES_ROOT}/alpha/ctl ${NODES_ROOT}/beta
cp ${NODES_ROOT}/alpha/mine ${NODES_ROOT}/beta


# Wallet Scripts

cat > "${NODES_ROOT}/w-alpha/ctl" <<EOF
#!/bin/sh
dcrctl -C ./dcrctl.conf --wallet -c ./data/rpc.cert \$*
EOF
chmod +x "${NODES_ROOT}/w-alpha/ctl"

cat > "${NODES_ROOT}/w-alpha/tickets" <<EOF
#!/bin/sh
NUM=1
case \$1 in
    ''|*[!0-9]*) ;;
    *) NUM=\$1 ;;
esac

./ctl purchaseticket default 999999 1 \`./ctl getnewaddress\` \$NUM
EOF
chmod +x "${NODES_ROOT}/w-alpha/tickets"

cat > "${NODES_ROOT}/w-alpha/xfer" <<EOF
#!/bin/sh
./ctl sendtoaddress \`./ctl getnewaddress\` 0.1
EOF
chmod +x "${NODES_ROOT}/w-alpha/xfer"

cp ${NODES_ROOT}/w-alpha/ctl ${NODES_ROOT}/w-beta
cp ${NODES_ROOT}/w-alpha/tickets ${NODES_ROOT}/w-beta
cp ${NODES_ROOT}/w-alpha/xfer ${NODES_ROOT}/w-beta


cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

tmux rename-window -t $SESSION:0 'prompt'


# Alpha Node & wallet

tmux new-window -t $SESSION:1 -n 'alpha'
tmux split-window -h
tmux split-window -v
tmux select-pane -t 0
tmux split-window -v
tmux select-pane -t 0

tmux send-keys "cd alpha" C-m
tmux send-keys "dcrd -C ./dcrd.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd alpha" C-m
sleep 3
tmux send-keys "./ctl generate 32" C-m

tmux select-pane -t 2
tmux send-keys "cd w-alpha" C-m
tmux send-keys "dcrwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET01_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ../wallet.conf --rpcconnect 127.0.0.1:19101 \
--rpclisten 127.0.0.1:19102" C-m
tmux select-pane -t 3
tmux send-keys "cd w-alpha" C-m

# Beta Node

tmux new-window -t $SESSION:2 -n 'beta'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd beta" C-m
tmux send-keys "dcrd -C ./dcrd.conf --connect 127.0.0.1:19100" C-m
tmux select-pane -t 1
tmux send-keys "cd beta" C-m


# Beta Wallet

tmux new-window -t $SESSION:3 -n 'wallets'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd w-beta" C-m
tmux send-keys "dcrwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET02_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ../wallet.conf --rpcconnect 127.0.0.1:19201 \
--rpclisten 127.0.0.1:19202" C-m
tmux select-pane -t 1
tmux send-keys "cd w-beta" C-m

# Voting Account & Ticket Buyer in Alpha Wallet
tmux select-window -t $SESSION:1
tmux send-keys "sleep 15" C-m
tmux send-keys "./ctl createnewaccount ticketbuyer" C-m
tmux send-keys "./ctl sendtoaddress \`./ctl getnewaddress ticketbuyer\` 0.1" C-m
sleep 20
tmux select-pane -t 2
tmux send-keys C-c
tmux send-keys "dcrwallet -C ../wallet.conf --rpcconnect 127.0.0.1:19101 \
--rpclisten 127.0.0.1:19102 --enableticketbuyer --enablevoting --ticketbuyer.limit 5" C-m


tmux attach-session -t $SESSION
