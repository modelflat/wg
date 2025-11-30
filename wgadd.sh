#!/usr/bin/env bash

# ./wgadd.sh <PEER_NAME> <PEER_IP> [PEER_PUBLIC_KEY] [PEER_PRIVATE_KEY] [PEER_ALLOWED_IPS]
# - adds a wireguard peer with a given name and IP
# - (optional) with given keys (generated if omitted)
# - (optional) with a list of allowed ips (defaults to just $PEER_IP/32)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "$0 should be running as root" 
   exit 1
fi

WGCONF="/etc/wireguard/wg0.conf"

PEER_NAME="$1"
PEER_IP="$2"
PEER_PUBLIC_KEY=${3:-''}
PEER_PRIVATE_KEY=${4:-''}
PEER_ALLOWED_IPS=${5:-''}

if [[ -z "$PEER_IP" ]]; then
    echo "usage: $0 <PEER_NAME> <PEER_IP> [PEER_PUBLIC_KEY] [PEER_PRIVATE_KEY] [PEER_ALLOWED_IPS]"
    exit 1
fi

if [[ -z "$PEER_ALLOWED_IPS" ]]; then
    PEER_ALLOWED_IPS="$PEER_IP/32"
fi

CLIENTCONF="${PEER_NAME}_${PEER_IP}.conf"

if [[ -z "$PEER_PRIVATE_KEY"]]; then
    PEER_PRIVATE_KEY=$(wg genkey)
    PEER_PUBLIC_KEY=$(printf "%s" "$PEER_PRIVATE_KEY" | wg pubkey)
fi

SERVER_PUBLIC_KEY=$(wg show wg0 public-key)
SERVER_ENDPOINT=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
SERVER_PORT=$(grep -E "^ListenPort" "$WGCONF" | awk '{print $3}')

sudo tee -a "$WGCONF" >/dev/null <<EOF
# $PEER_NAME
[Peer]
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = $PEER_ALLOWED_IPS
EOF

cat > "$CLIENTCONF" <<EOF
[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = $PEER_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENTCONF"

systemctl restart wg-quick@wg0

echo "added: $PEER_NAME"

if ! command -v qrencode >/dev/null 2>&1; then
    apt update
    apt install -y qrencode
fi

qrencode -t ansiutf8 < "$CLIENTCONF"
