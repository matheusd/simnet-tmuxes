#!/bin/bash

set -e
set -x

SESSION="lnd-simnet-setup"
NODES_ROOT=~/lnd-simnet
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="25d73fff535aef60eec9c0267bdf29d5880904d539a587593eff5e7d295f5d8a"
WALLET_MINING_ADDR="STJGzDTpdbkmx9jw5PBKCohEAwaTsEHR37"

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,alpha,beta,gamma,miner}


# Main Config File

cat > "${NODES_ROOT}/btcd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
datadir=./data
txindex=1
miningaddr=${WALLET_MINING_ADDR}
rpclisten=127.0.0.1:28556
listen=127.0.0.1:28555
EOF

cat > "${NODES_ROOT}/btcctl.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
EOF

cat > "${NODES_ROOT}/wallet.conf" <<EOF
username=${RPCUSER}
password=${RPCPASS}
simnet=1
appdata=./data
rpcconnect=127.0.0.1:28556
EOF

cat > "${NODES_ROOT}/lnd.conf" <<EOF
[Application Options]
datadir = ./
logdir = ./log
debuglevel = info
debughtlc = false

[Bitcoin]
bitcoin.simnet = 1
bitcoin.active = 1
bitcoin.node = btcd

[btcd]
btcd.rpcuser = ${RPCUSER}
btcd.rpcpass = ${RPCPASS}
btcd.rpchost = 127.0.0.1:28556
EOF

cat > "${NODES_ROOT}/setupenv" <<EOF
#!/bin/sh
alias alpha=${NODES_ROOT}/alpha/cli
alias beta=${NODES_ROOT}/beta/cli
alias gamma=${NODES_ROOT}/gamma/cli
EOF

cat > "${NODES_ROOT}/setuplnnet" <<EOF
#!/bin/sh
source ./setupenv

./miner/ctl walletpassphrase 123 0
alpha newaddress np2wkh | jq -r .address | ./miner/ctl sendtoaddress - 10
beta newaddress np2wkh | jq -r .address | ./miner/ctl sendtoaddress - 10
gamma newaddress np2wkh | jq -r .address | ./miner/ctl sendtoaddress - 10

./master/ctl generate 10

alpha connect \`beta getinfo | jq -r .identity_pubkey\`@localhost:21002
beta connect \`gamma getinfo | jq -r .identity_pubkey\`@localhost:21003

alpha openchannel --node_key=\`beta getinfo | jq -r .identity_pubkey\` --local_amt=10000000
gamma openchannel --node_key=\`beta getinfo | jq -r .identity_pubkey\` --local_amt=15000000 --push_amt 1000000

./master/ctl generate 10
EOF
chmod +x "${NODES_ROOT}/setuplnnet"

# Node Utils

cat > "${NODES_ROOT}/master/ctl" <<EOF
#!/bin/sh
btcctl -C ${NODES_ROOT}/btcctl.conf -s 127.0.0.1:28556 \$*
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
  btcctl -C ${NODES_ROOT}/btcctl.conf -s 127.0.0.1:28556 generate 1
  sleep 0.01
done
EOF
chmod +x "${NODES_ROOT}/master/mine"

# Main Miner Wallet Utils

cat > "${NODES_ROOT}/miner/ctl" <<EOF
#!/bin/sh
btcctl -C ${NODES_ROOT}/btcctl.conf --wallet -c ${NODES_ROOT}/miner/data/rpc.cert \$*
EOF
chmod +x "${NODES_ROOT}/miner/ctl"

# Lnd node utils

cat > "${NODES_ROOT}/alpha/cli" <<EOF
#!/bin/sh
lncli --rpcserver 127.0.0.1:20001 --macaroonpath ${NODES_ROOT}/alpha/chain/bitcoin/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/alpha/cli"

cat > "${NODES_ROOT}/alpha/daemon" <<EOF
#!/bin/sh
lnd --configfile=${NODES_ROOT}/lnd.conf --rpclisten=127.0.0.1:20001 --listen=127.0.0.1:21001 --restlisten=127.0.0.1:22001 \$*
EOF
chmod +x "${NODES_ROOT}/alpha/daemon"


cat > "${NODES_ROOT}/beta/cli" <<EOF
#!/bin/sh
lncli --rpcserver 127.0.0.1:20002 --macaroonpath ${NODES_ROOT}/beta/chain/bitcoin/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/beta/cli"

cat > "${NODES_ROOT}/beta/daemon" <<EOF
#!/bin/sh
lnd --configfile=${NODES_ROOT}/lnd.conf --rpclisten=127.0.0.1:20002 --listen=127.0.0.1:21002 --restlisten=127.0.0.1:22002 \$*
EOF
chmod +x "${NODES_ROOT}/beta/daemon"



cat > "${NODES_ROOT}/gamma/cli" <<EOF
#!/bin/sh
lncli --rpcserver 127.0.0.1:20003 --macaroonpath ${NODES_ROOT}/gamma/chain/bitcoin/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/gamma/cli"

cat > "${NODES_ROOT}/gamma/daemon" <<EOF
#!/bin/sh
lnd --configfile=${NODES_ROOT}/lnd.conf --rpclisten=127.0.0.1:20003 --listen=127.0.0.1:21003 --restlisten=127.0.0.1:22003 \$*
EOF
chmod +x "${NODES_ROOT}/gamma/daemon"



# ********************************************************

# scripts created. Start building session.
cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

# window 0 is a dummy prompt
tmux rename-window -t $SESSION:0 'prompt'

# window 1 is the node
tmux new-window -t $SESSION:1 -n 'btcd'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "btcd -C ../btcd.conf " C-m
tmux resize-pane -D 10
tmux select-pane -t 1
tmux send-keys "cd master" C-m
sleep 1
tmux send-keys "./ctl generate 400" C-m

# window 2 is the miner wallet
tmux new-window -t $SESSION:2 -n 'wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 10
tmux send-keys "cd miner" C-m
tmux send-keys "btcwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET_SEED}" C-m C-m
tmux send-keys "btcwallet -C ../wallet.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd miner" C-m

# window 3 are the three lnd daemons
tmux new-window -t $SESSION:3 -n 'lnd'
tmux split-window -v
tmux split-window -v
tmux select-layout even-vertical
tmux send-keys -t 0 "cd alpha" C-m "./daemon" C-m
tmux send-keys -t 1 "cd beta" C-m "./daemon" C-m
tmux send-keys -t 2 "cd gamma" C-m "./daemon" C-m
sleep 5 

tmux new-window -t $SESSION:4 -n 'ctl'
tmux send-keys ". setupenv" C-m
tmux send-keys "alpha create" C-m "12345678" C-m 
sleep 1
tmux send-keys "12345678" C-m "y" C-m
sleep 1
tmux send-keys "abstract boss tell field coffee scheme \
aspect radar hungry base normal keen mad net stomach \
enable accident elegant culture mobile nation fun cart buyer" C-m
tmux send-keys C-m C-m
sleep 1

tmux send-keys "beta create" C-m "12345678" 
sleep 1
tmux send-keys C-m "12345678" C-m "y" C-m
sleep 1
tmux send-keys "abstract sample arrow green super hill \
inspire auction spike pen jeans regular awesome bus wolf \
brief author dawn sick boring ten moment bike decrease" C-m
tmux send-keys C-m C-m
sleep 1

tmux send-keys "gamma create" C-m "12345678" 
sleep 1
tmux send-keys C-m "12345678" C-m "y" C-m
sleep 1
tmux send-keys "absent thing enact video mechanic gossip \
pill reduce recipe hair chaos random level bleak able body \
bar alien local coral machine chaos tonight transfer" C-m
tmux send-keys C-m C-m

tmux send-keys "sleep 20" C-m ". setupenv" C-m "./setuplnnet" C-m


# all done. Enter session.
tmux attach-session -t $SESSION
