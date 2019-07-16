#!/bin/bash

set -e
set -x

SESSION="dcrlnd-simnet-setup"
NODES_ROOT=~/dcrlnd-simnet
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET_MINING_ADDR="SsWKp7wtdTZYabYFYSc9cnxhwFEjA5g4pFc"

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,alpha,beta,gamma,miner}


# Main Config File

cat > "${NODES_ROOT}/dcrd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
datadir=./data
txindex=1
miningaddr=${WALLET_MINING_ADDR}
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
appdata=./data
enableticketbuyer = 1
enablevoting = 1
pass = 123
ticketbuyer.limit = 5
EOF

cat > "${NODES_ROOT}/dcrlnd.conf" <<EOF
[Application Options]
datadir = ./
logdir = ./log
debuglevel = info
debughtlc = false

[Decred]
decred.simnet = 1
decred.node = dcrd 

[dcrd]
dcrd.rpcuser = ${RPCUSER}
dcrd.rpcpass = ${RPCPASS}
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

./master/mine 20

./miner/ctl walletpassphrase 123 0
alpha newaddress p2pkh | jq -r .address | ./miner/ctl sendtoaddress - 10
beta newaddress p2pkh | jq -r .address | ./miner/ctl sendtoaddress - 10
gamma newaddress p2pkh | jq -r .address | ./miner/ctl sendtoaddress - 10

./master/ctl generate 10

alpha connect \`beta getinfo | jq -r .identity_pubkey\`@localhost:11002
beta connect \`gamma getinfo | jq -r .identity_pubkey\`@localhost:11003

alpha openchannel --node_key=\`beta getinfo | jq -r .identity_pubkey\` --local_amt=10000000
gamma openchannel --node_key=\`beta getinfo | jq -r .identity_pubkey\` --local_amt=15000000 --push_amt 1000000

./master/mine 20
EOF
chmod +x "${NODES_ROOT}/setuplnnet"

# Node Utils

cat > "${NODES_ROOT}/master/ctl" <<EOF
#!/bin/sh
dcrctl -C ${NODES_ROOT}/dcrctl.conf \$*
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
  dcrctl -C ${NODES_ROOT}/dcrctl.conf generate 1
  sleep 0.1
done
EOF
chmod +x "${NODES_ROOT}/master/mine"

# Main Miner Wallet Utils

cat > "${NODES_ROOT}/miner/ctl" <<EOF
#!/bin/sh
dcrctl -C ${NODES_ROOT}/dcrctl.conf --wallet -c ${NODES_ROOT}/miner/data/rpc.cert \$*
EOF
chmod +x "${NODES_ROOT}/miner/ctl"

# Lnd node utils

cat > "${NODES_ROOT}/alpha/cli" <<EOF
#!/bin/sh
dcrlncli --rpcserver 127.0.0.1:10001 --macaroonpath ${NODES_ROOT}/alpha/chain/decred/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/alpha/cli"

cat > "${NODES_ROOT}/alpha/daemon" <<EOF
#!/bin/sh
dcrlnd --configfile=${NODES_ROOT}/dcrlnd.conf --rpclisten=127.0.0.1:10001 --listen=127.0.0.1:11001 --restlisten=127.0.0.1:12001 \$*
EOF
chmod +x "${NODES_ROOT}/alpha/daemon"


cat > "${NODES_ROOT}/beta/cli" <<EOF
#!/bin/sh
dcrlncli --rpcserver 127.0.0.1:10002 --macaroonpath ${NODES_ROOT}/beta/chain/decred/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/beta/cli"

cat > "${NODES_ROOT}/beta/daemon" <<EOF
#!/bin/sh
dcrlnd --configfile=${NODES_ROOT}/dcrlnd.conf --rpclisten=127.0.0.1:10002 --listen=127.0.0.1:11002 --restlisten=127.0.0.1:12002 \$*
EOF
chmod +x "${NODES_ROOT}/beta/daemon"



cat > "${NODES_ROOT}/gamma/cli" <<EOF
#!/bin/sh
dcrlncli --rpcserver 127.0.0.1:10003 --macaroonpath ${NODES_ROOT}/gamma/chain/decred/simnet/admin.macaroon \$*
EOF
chmod +x "${NODES_ROOT}/gamma/cli"

cat > "${NODES_ROOT}/gamma/daemon" <<EOF
#!/bin/sh
dcrlnd --configfile=${NODES_ROOT}/dcrlnd.conf --rpclisten=127.0.0.1:10003 --listen=127.0.0.1:11003 --restlisten=127.0.0.1:12003 \$*
EOF
chmod +x "${NODES_ROOT}/gamma/daemon"



# ********************************************************

# scripts created. Start building session.
cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION

# window 0 is a dummy prompt
tmux rename-window -t $SESSION:0 'prompt'

# window 1 is the node
tmux new-window -t $SESSION:1 -n 'dcrd'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "dcrd -C ../dcrd.conf " C-m
tmux resize-pane -D 10
tmux select-pane -t 1
tmux send-keys "cd master" C-m
sleep 1
tmux send-keys "./ctl generate 16" C-m

# window 2 is the miner wallet
tmux new-window -t $SESSION:2 -n 'wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 10
tmux send-keys "cd miner" C-m
tmux send-keys "dcrwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET_SEED}" C-m C-m
tmux send-keys "dcrwallet -C ../wallet.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd miner" C-m

# window 3 are the three lnd daemons
tmux new-window -t $SESSION:3 -n 'dcrlnd'
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

tmux send-keys "sleep 30" C-m ". setupenv" C-m "./setuplnnet" C-m


# all done. Enter session.
tmux attach-session -t $SESSION
