#!/bin/sh
# Minimal lnd setup for a three-node simnet network.
#
# Sets up a bitcoin miner then prepares 3 lnd nodes.

set -e
# set -x

NODES_ROOT=~/lndsimnetnodes
LND_BIN="lnd"
SESSION="lnd-3node"
RPCUSER="USER"
RPCPASS="PASS"
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET_MINING_ADDR="SdBsWGHtRP1kREnby5hhfGcwSYSwcoKxTF" # NOTE: This must be changed if the seed is changed.
NODE0_SEED="abandon replace vendor festival curious load vague empty noise level sock brain noodle nominee concert resemble rice pilot gentle beyond carry material birth town"
NODE1_SEED="able field segment load sister riot carbon acoustic undo history zebra multiply blouse raise radar radio gloom slight vote warrior water stable hub village"
NODE2_SEED="able found student horse wife gas catch jelly blast grab wage strategy toward can empty junior pond medal cave wise argue typical gossip decline"
NODE0_PUBID="0242932af0f8e8d637e84a93f11f8a22f41326c4407e4953715b80b6f827b17ab0"
NODE1_PUBID="0382942b3f112942370ee7db19733872df4b88f815cae1d10cfabaa7028e31085b"
NODE2_PUBID="039196355117fef28c34451a7e9d7bc93b7cb722292d06d66bc376fb5413072502"

if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{master,wallet,lnd0,lnd1,lnd2}

cat > "${NODES_ROOT}/btcd.conf" <<EOF
rpcuser = ${RPCUSER}
rpcpass = ${RPCPASS}
simnet = 1
logdir = ./log
datadir = ./data
txindex = 1
listen = :29555
rpclisten = :29556
miningaddr = ${WALLET_MINING_ADDR}
; debuglevel=TXMP=TRACE,MINR=TRACE,CHAN=TRACE
EOF

cat > "${NODES_ROOT}/btcctl.conf" <<EOF
rpcuser = ${RPCUSER}
rpcpass = ${RPCPASS}
simnet = 1
EOF

cat > "${NODES_ROOT}/wallet.conf" <<EOF
username = ${RPCUSER}
password = ${RPCPASS}
simnet = 1
logdir = ${NODES_ROOT}/wallet/log
appdata = ${NODES_ROOT}/wallet/data
rpcconnect = 127.0.0.1:29556
EOF

cat > "${NODES_ROOT}/lnd0.conf" <<EOF
[Application Options]

datadir = ${NODES_ROOT}/lnd0
tlscertpath = ${NODES_ROOT}/lnd0/tls.cert
tlskeypath = ${NODES_ROOT}/lnd0/tls.key
rpclisten = 127.0.0.1:30000
restlisten = 127.0.0.1:30001
listen = 127.0.0.1:30002

debuglevel = debug

[Bitcoin]
bitcoin.active = 1
bitcoin.node = "btcd"
bitcoin.simnet = 1

[btcd]
btcd.rpchost = localhost:29556
btcd.rpcuser = ${RPCUSER}
btcd.rpcpass = ${RPCPASS}
EOF

cat > "${NODES_ROOT}/lnd1.conf" <<EOF
[Application Options]

datadir = ${NODES_ROOT}/lnd1
tlscertpath = ${NODES_ROOT}/lnd1/tls.cert
tlskeypath = ${NODES_ROOT}/lnd1/tls.key
rpclisten = 127.0.0.1:30100
restlisten = 127.0.0.1:30101
listen = 127.0.0.1:30102

debuglevel = debug

[Bitcoin]
bitcoin.active = 1
bitcoin.node = "btcd"
bitcoin.simnet = 1

[btcd]
btcd.rpchost = localhost:29556
btcd.rpcuser = ${RPCUSER}
btcd.rpcpass = ${RPCPASS}
EOF

cat > "${NODES_ROOT}/lnd2.conf" <<EOF
[Application Options]

datadir = ${NODES_ROOT}/lnd2
tlscertpath = ${NODES_ROOT}/lnd2/tls.cert
tlskeypath = ${NODES_ROOT}/lnd2/tls.key
rpclisten = 127.0.0.1:30200
restlisten = 127.0.0.1:30201
listen = 127.0.0.1:30202

debuglevel = debug

[Bitcoin]
bitcoin.active = 1
bitcoin.node = "btcd"
bitcoin.simnet = 1

[btcd]
btcd.rpchost = localhost:29556
btcd.rpcuser = ${RPCUSER}
btcd.rpcpass = ${RPCPASS}
EOF


# Scripts

cat > "${NODES_ROOT}/master/ctl" <<EOF
#!/bin/sh
btcctl -s 127.0.0.1:29556 -C ../btcctl.conf \$*
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
  btcctl -s 127.0.0.1:29556 -C ../btcctl.conf generate 1
  sleep 0.3
done
EOF
chmod +x "${NODES_ROOT}/master/mine"

cat > "${NODES_ROOT}/wallet/ctl" <<EOF
#!/bin/sh
btcctl  -C ../btcctl.conf --wallet -c ./data/rpc.cert \$*
EOF
chmod +x "${NODES_ROOT}/wallet/ctl"

cat > "${NODES_ROOT}/lnd0/ctl" <<EOF
#!/bin/sh
lncli \\
  -n simnet \\
  --chain bitcoin \\
  --rpcserver localhost:30000 \\
  --lnddir ${NODES_ROOT}/lnd0 \\
  --tlscertpath ${NODES_ROOT}/lnd0/tls.cert \\
  --macaroonpath ${NODES_ROOT}/lnd0/chain/bitcoin/simnet/admin.macaroon \\
  \$*
EOF
chmod +x "${NODES_ROOT}/lnd0/ctl"


cat > "${NODES_ROOT}/lnd1/ctl" <<EOF
#!/bin/sh
lncli \\
  -n simnet \\
  --chain bitcoin \\
  --rpcserver localhost:30100 \\
  --lnddir ${NODES_ROOT}/lnd1 \\
  --tlscertpath ${NODES_ROOT}/lnd1/tls.cert \\
  --macaroonpath ${NODES_ROOT}/lnd1/chain/bitcoin/simnet/admin.macaroon \\
  \$*
EOF
chmod +x "${NODES_ROOT}/lnd1/ctl"

cat > "${NODES_ROOT}/lnd2/ctl" <<EOF
#!/bin/sh
lncli \\
  -n simnet \\
  --chain bitcoin \\
  --rpcserver localhost:30200 \\
  --lnddir ${NODES_ROOT}/lnd2 \\
  --tlscertpath ${NODES_ROOT}/lnd2/tls.cert \\
  --macaroonpath ${NODES_ROOT}/lnd2/chain/bitcoin/simnet/admin.macaroon \\
  \$*
EOF
chmod +x "${NODES_ROOT}/lnd2/ctl"

function countdown {
  secs=$1
  while [ $secs -gt 0 ]; do
    echo -ne "$secs \033[0K\r"
    sleep 1
    : $((secs--))
  done
}


# Start Session

cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION
tmux send-keys "cd ${PROJ_DIR}" C-m

# Mining Node & Voting Wallet

tmux new-window -t $SESSION:1 -n 'network'
tmux split-window -h
tmux split-window -v
tmux select-pane -t 0
tmux split-window -v
tmux select-pane -t 0

tmux send-keys "cd master" C-m
tmux send-keys "btcd -C ../btcd.conf" C-m
tmux select-pane -t 1
tmux send-keys "cd master" C-m 
sleep 3
tmux send-keys "./ctl generate 300" C-m

tmux select-pane -t 2
tmux send-keys "cd wallet" C-m
tmux send-keys "btcwallet -C ../wallet.conf --create" C-m
sleep 2
tmux send-keys "123" C-m
tmux send-keys "123" C-m 
tmux send-keys "n" C-m "y" C-m
sleep 1
tmux send-keys "${WALLET_SEED}" C-m C-m
tmux send-keys "btcwallet -C ../wallet.conf" C-m
tmux select-pane -t 3
tmux send-keys "cd wallet" C-m
tmux send-keys "sleep 5" C-m "./ctl walletpassphrase 123 0" C-m

# Bring up ln nodes

tmux new-window -t $SESSION:2 -n 'lnd0'
tmux send-keys "${LND_BIN} --configfile ${NODES_ROOT}/lnd0.conf" C-m
tmux split-window -v
tmux send-keys "cd ${NODES_ROOT}/lnd0" C-m

tmux new-window -t $SESSION:3 -n 'lnd1'
tmux send-keys "${LND_BIN} --configfile ${NODES_ROOT}/lnd1.conf" C-m
tmux split-window -v
tmux send-keys "cd ${NODES_ROOT}/lnd1" C-m

tmux new-window -t $SESSION:4 -n 'lnd2'
tmux send-keys "${LND_BIN} --configfile ${NODES_ROOT}/lnd2.conf" C-m
tmux split-window -v
tmux send-keys "cd ${NODES_ROOT}/lnd2" C-m

# Wait for nodes to query for pwd
echo "Waiting for lnd nodes to initialize"
countdown 10

# Create lnd wallets

tmux select-window -t 2
tmux send-keys "./ctl create" C-m
sleep 3
tmux send-keys "12345678" C-m "12345678" C-m

tmux select-window -t 3
tmux send-keys "./ctl create" C-m
sleep 3
tmux send-keys "12345678" C-m "12345678" C-m

tmux select-window -t 4
tmux send-keys "./ctl create" C-m
sleep 3
tmux send-keys "12345678" C-m "12345678" C-m

# Wait for seed input
echo "Waiting to input seed"
countdown 3

# Seed input lnd wallets
tmux select-window -t 2
tmux send-keys "y" C-m
sleep 2
tmux send-keys "${NODE0_SEED}" C-m C-m C-m
tmux select-window -t 3
tmux send-keys "y" C-m 
sleep 2
tmux send-keys "${NODE1_SEED}" C-m C-m C-m
tmux select-window -t 4
tmux send-keys "y" C-m 
sleep 2
tmux send-keys "${NODE2_SEED}" C-m C-m C-m

echo "Waiting for nodes to sync up"
countdown 15

# send coins to both nodes and mine it
addr0=`${NODES_ROOT}/lnd0/ctl newaddress p2wkh | jq .address`
addr1=`${NODES_ROOT}/lnd1/ctl newaddress p2wkh | jq .address`
addr2=`${NODES_ROOT}/lnd2/ctl newaddress p2wkh | jq .address`
tmux select-window -t 1
tmux send-keys "./ctl sendtoaddress $addr0 10" C-m
tmux send-keys "./ctl sendtoaddress $addr1 10" C-m
tmux send-keys "./ctl sendtoaddress $addr2 10" C-m
tmux select-pane -t 1
tmux send-keys "./mine 3" C-m

echo "Waiting for lnd wallets to catch up"
countdown 3

# connect nodes and open a channel node0 => node1
tmux select-window -t 2
tmux send-keys "./ctl connect ${NODE1_PUBID}@127.0.0.1:30102" C-m
tmux send-keys "./ctl openchannel ${NODE1_PUBID} 200000 100000" C-m

# connect nodes and open a channel node2 => node1
tmux select-window -t 4
tmux send-keys "./ctl connect ${NODE1_PUBID}@127.0.0.1:30102" C-m
tmux send-keys "./ctl openchannel ${NODE1_PUBID} 80000 20000" C-m

echo "Waiting for channels to open"
countdown 3

tmux select-window -t 1
tmux send-keys "./mine 6" C-m


# tmux attach-session -t $SESSION
echo "attach to session '$SESSION'"
