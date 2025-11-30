#!/usr/bin/env bash

# ./wgboot.sh <HOST_SUBNET> [HOST_PUBLIC_KEY] [HOST_PRIVATE_KEY] [ENABLE_NAT_ON_DEVICE] [ROUTE_A] [ROUTE_B]
# - sets up wireguard instance with given HOST_SUBNET
# - (optional) with a given key pair
# - (optional) also enables NAT masquerading on the given network device
# - (optional) also sets up LAN routing between device ROUTE_A and device ROUTE_B

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "$0 should be running as root" 
   exit 1
fi

HOST_ADDRESS="$1"
PUBLIC_KEY=${2:-""}
PRIVATE_KEY=${3:-""}
ENABLE_NAT_ON_DEVICE=${4:-""}
ROUTE_A=${5:-""}
ROUTE_B=${6:-""}
WGPORT=${7:-51820}

apt update

apt install -y \
    git \
    build-essential \
    libelf-dev \
    pkg-config \
    linux-headers-$(uname -r)

# kernel module (not needed for modern ubuntu)
if ! lsmod | grep -q wireguard; then
    mkdir -p /tmp/src && cd /tmp/src

    if ! modinfo wireguard >/dev/null 2>&1; then
        echo "! kernel lacks native WireGuard, building wireguard-linux-compat..."
        git clone https://git.zx2c4.com/wireguard-linux-compat || true
        cd wireguard-linux-compat
        make
        make install
        cd ..
    fi

    modprobe wireguard
fi

# tools
mkdir -p /tmp/src && cd /tmp/src

echo "building tools..."
git clone https://git.zx2c4.com/wireguard-tools || true
cd wireguard-tools/src
make
make install

tee /etc/nftables.conf >/dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

EOF

# packet forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# nat masquerading
if [[ -n "$ENABLE_NAT_ON_DEVICE" ]]; then 
    tee /etc/nftables.conf >/dev/null <<EOF
table ip nat {
    chain POSTROUTING {
        type nat hook postrouting priority 100;
        oif "$ENABLE_NAT_ON_DEVICE" masquerade
    }
}
EOF
    systemctl enable nftables && systemctl start nftables
fi

# routing for lans
if [[ -n "$ROUTE_A" ]]; then 
    tee /etc/nftables.conf >/dev/null <<EOF
table ip filter {
    chain forward {
        type filter hook forward priority 0;
        policy drop;

        # allow forwarding between A and B
        iif "$ROUTE_A" oif "$ROUTE_B" accept
        iif "$ROUTE_B" oif "$ROUTE_A" accept
    }
}
EOF
    systemctl enable nftables && systemctl start nftables
fi

# conf
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

WGCONF=/etc/wireguard/wg0.conf

# server keys
if [[ -z "$PRIVATE_KEY" ]]; then 
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(printf "%s" "$PRIVATE_KEY" | wg pubkey)
fi

tee $WGCONF >/dev/null <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $HOST_ADDRESS/32
ListenPort = $WGPORT
EOF

chmod 600 $WGCONF

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# validate
echo "service status..."
systemctl status wg-quick@wg0 --no-pager || true

echo "forwarding settings..."
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding

echo "--- bootstrapping complete ---"
echo "this wg instance's keys:"
echo "public  -> $PUBLIC_KEY"
echo "private -> $PRIVATE_KEY"
