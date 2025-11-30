#!/usr/bin/env bash

# ./wglink.sh <PEER_NAME> <PEER_IP> <PEER_PUBLIC_KEY>
# - adds a wireguard peer with a given name, IP and public key

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "$0 should be running as root" 
   exit 1
fi

WGCONF="/etc/wireguard/wg0.conf"

PEER_NAME="$1"
PEER_IP="$2"
PEER_PUBLIC_KEY="$3"

if [[ -z "$PEER_IP" ]]; then
    echo "usage: $0 <PEER_NAME> <PEER_IP> <PEER_PUBLIC_KEY>"
    exit 1
fi

SERVER_PUBLIC_KEY=$(wg show wg0 public-key)
SERVER_ENDPOINT=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
SERVER_PORT=$(grep -E "^ListenPort" "$WGCONF" | awk '{print $3}')

PEER_ALLOWED_IPS="$PEER_IP/32"

tee -a "$WGCONF" >/dev/null <<EOF
# $PEER_NAME
[Peer]
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = $PEER_ALLOWED_IPS
EOF

systemctl restart wg-quick@wg0

echo "added: $PEER_NAME"

