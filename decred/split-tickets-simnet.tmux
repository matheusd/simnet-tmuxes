#!/bin/sh
# Split tickets test setup for simnet

set -e

PROJDIR="$HOME/projetos/decred/dcr-split-ticket-matcher"
SESSION="split-tickets-simnet"
NODES_ROOT=~/dcrdsimnetnodes
RPCUSER="USER"
RPCPASS="PASS"

# don't change the seeds, unless you know what you're doing
WALLET_SEED="b280922d2cffda44648346412c5ec97f429938105003730414f10b01e1402eac"
WALLET01_SEED="1111111111111111111111111111111111111111111111111111111111111111"
WALLET02_SEED="2222222222222222222222222222222222222222222222222222222222222222"


if [ -d "${NODES_ROOT}" ] ; then
  rm -R "${NODES_ROOT}"
fi

mkdir -p "${NODES_ROOT}/"{dcrstmd,master,wallet,w01,w02}

cat > "${NODES_ROOT}/dcrd.conf" <<EOF
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
simnet=1
logdir=./log
datadir=./data
txindex=1
EOF

cat > "${NODES_ROOT}/dcrctl.conf" <<EOF
simnet=1
rpcuser=${RPCUSER}
rpcpass=${RPCPASS}
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
ticketbuyer.maxperblock=10
; ticketbuyer.minfee=0.002
EOF

cat > "${NODES_ROOT}/simplewallet.conf" <<EOF
username=${RPCUSER}
password=${RPCPASS}
simnet=1
logdir=./log
appdata=./data
enableticketbuyer=0
EOF

cat > "${NODES_ROOT}/dcrstmd.conf" <<EOF
SimNet = 1
MinAmount = 0.2
StakeDiffChangeStopWindow = 1
DcrdHost = localhost:19556
DcrdUser = ${RPCUSER}
DcrdPass = ${RPCPASS}
DcrwHost = localhost:19557
DcrwCert = ${NODES_ROOT}/wallet/data/rpc.cert
DcrwUser = ${RPCUSER}
DcrwPass = ${RPCPASS}
# privkey for address Ssp7J7TUmi5iPhoQnWYNGQbeGhu6V3otJcS
SplitPoolSignKey = PsURNVHcRZjUBpZdRwwESqvUrj4kMneH4mBwM4oWC4Lcxa4B45K5n
AllowPublicSession = 1
CertFile = ${NODES_ROOT}/dcrstmd/rpc.cert
KeyFile = ${NODES_ROOT}/dcrstmd/rpc.key
PoolFee = 7.5
WaitingListWSBindAddr = 127.0.0.1:8486
LogDir = ${NODES_ROOT}/dcrstmd/logs
DataDir = ${NODES_ROOT}/dcrstmd
EOF

cat > "${NODES_ROOT}/w01/splitticketbuyer.conf" <<EOF
VoteAddress = Ssik5H1FoQwV7yJje33oUadoV9z1QndUaiE
PoolAddress = SsnbEmxCVXskgTHXvf3rEa17NA39qQuGHwQ

SimNet = 1
MaxAmount = 2
WalletHost = 127.0.0.1:0
Pass = 123
MatcherHost = localhost:8475
MatcherCertFile = ${NODES_ROOT}/dcrstmd/rpc.cert
DcrdHost = localhost:19556
DcrdUser = ${RPCUSER}
DcrdPass = ${RPCPASS}
DcrdCert = ~/.dcrd/rpc.cert
DataDir = ${NODES_ROOT}/w01/data-split
WalletCertFile = ${NODES_ROOT}/w01/data/rpc.cert
EOF


cat > "${NODES_ROOT}/w02/splitticketbuyer.conf" <<EOF
VoteAddress = SsXBReLhVK8NrzZcBsu1Dyo5KhD19rgEcEv
PoolAddress = SssMkPce9H8kCwsBBQ5CuU7GpPxVgFseKrg

SimNet = 1
MaxAmount = 2
WalletHost = 127.0.0.1:0
Pass = 123
MatcherHost = localhost:8475
MatcherCertFile = ${NODES_ROOT}/dcrstmd/rpc.cert
DcrdHost = localhost:19556
DcrdUser = ${RPCUSER}
DcrdPass = ${RPCPASS}
DcrdCert = ~/.dcrd/rpc.cert
WalletCertFile = ${NODES_ROOT}/w02/data/rpc.cert
DataDir = ${NODES_ROOT}/w02/data-split
EOF

cd ${NODES_ROOT} && tmux -2 new-session -d -s $SESSION


# Dcrd

tmux rename-window -t $SESSION:0 'prompt'

tmux new-window -t $SESSION:1 -n 'dcrd'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd master" C-m
tmux send-keys "dcrd -C ../dcrd.conf --listen 127.0.0.1:19555 --miningaddr=SsWKp7wtdTZYabYFYSc9cnxhwFEjA5g4pFc" C-m
tmux resize-pane -D 10
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
  sleep 0.1
done
EOF
chmod +x "${NODES_ROOT}/master/mine"
sleep 3
tmux send-keys "./ctl generate 32" C-m

# Mining Wallet

tmux new-window -t $SESSION:2 -n 'master wallet'
tmux split-window -v
tmux select-pane -t 0
tmux resize-pane -D 5
tmux send-keys "cd wallet" C-m
tmux send-keys "dcrwallet -C ../wallet.conf --create" C-m
sleep 0.5
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 0.5
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


# Split Ticket Wallets

tmux new-window -t $SESSION:3 -n 'wallets'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd w01" C-m
tmux send-keys "dcrwallet -C ../simplewallet.conf --create" C-m
sleep 0.5
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 0.5
tmux send-keys "${WALLET01_SEED}" C-m C-m
tmux send-keys "dcrwallet --pass 123 -C ../simplewallet.conf --rpclisten ':20001' --grpclisten ':20101'" C-m

tmux select-pane -t 1
tmux send-keys "cd w02" C-m
tmux send-keys "dcrwallet -C ../simplewallet.conf --create" C-m
sleep 0.5
tmux send-keys "123" C-m "123" C-m "n" C-m "y" C-m
sleep 0.5
tmux send-keys "${WALLET02_SEED}" C-m C-m
tmux send-keys "dcrwallet --pass 123 -C ../simplewallet.conf --rpclisten ':20002' --grpclisten ':20102'" C-m

cat > "${NODES_ROOT}/w01/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf --wallet -c ./data/rpc.cert -w 127.0.0.1:20001 \$*
EOF
chmod +x "${NODES_ROOT}/w01/ctl"

cat > "${NODES_ROOT}/w02/ctl" <<EOF
#!/bin/sh
dcrctl -C ../dcrctl.conf --wallet -c ./data/rpc.cert -w 127.0.0.1:20002 \$*
EOF
chmod +x "${NODES_ROOT}/w02/ctl"




# split service and buyer

tmux new-window -t $SESSION:4 -n 'split'
tmux split-window -v
tmux select-pane -t 0
tmux send-keys "cd $PROJDIR" C-m
tmux send-keys "go run ./cmd/dcrstmd -C ${NODES_ROOT}/dcrstmd.conf"
tmux select-pane -t 1
tmux send-keys "cd $PROJDIR" C-m
tmux send-keys "go run ./cmd/splitticketbuyer -C ${NODES_ROOT}/w01/splitticketbuyer.conf"

tmux new-window -t $SESSION:5 -n 'split 2'
tmux send-keys "cd $PROJDIR" C-m
tmux send-keys "go run ./cmd/splitticketbuyer -C ${NODES_ROOT}/w02/splitticketbuyer.conf"

echo "All setup. Waiting a bit for wallets to startup..."

sleep 25

tmux select-window -t 1
tmux send-keys "./mine 4" C-m
tmux send-keys "(cd ../wallet && ./ctl sendtoaddress Ssoaqgx4ecmHX54LqrUXgqi6miUFxP9iUvc 100)" C-m
tmux send-keys "(cd ../wallet && ./ctl sendtoaddress SsgkhRgr9JdonELE7MjK8qUkwSPsrTnWcE6 100)" C-m
tmux send-keys "./mine 150" C-m
# tmux select-window -t 2
# tmux send-keys C-m



tmux attach-session -t "${SESSION}"
