#!/usr/bin/env bash

# ./wgboot.sh <HOST_SUBNET> [HOST_PRIVATE_KEY] [ENABLE_NAT_ON_DEVICE] [ROUTE_A] [ROUTE_B]
# - sets up wireguard instance with given HOST_SUBNET
# - (optional) with a given private key (generated if omitted)
# - (optional) also enables NAT masquerading on the given network device
# - (optional) also sets up LAN routing between device ROUTE_A and device ROUTE_B

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "$0 should be running as root" 
   exit 1
fi

HOST_ADDRESS="$1"
HOST_PRIVATE_KEY=${2:-""}
ENABLE_NAT_ON_DEVICE=${3:-""}
ROUTE_A=${4:-""}
ROUTE_B=${5:-""}
WGPORT=${6:-51820}

apt update

apt install -y \
    git \
    build-essential \
    libelf-dev \
    pkg-config \
    linux-headers-$(uname -r)

# kernel module (not needed for modern ubuntu)
if ! lsmod | grep -q wireguard; then
    echo "<- enabling kernel module"
    mkdir -p /tmp

    if ! modinfo wireguard >/dev/null 2>&1; then
        echo "! kernel lacks native WireGuard, building wireguard-linux-compat..."
        git clone https://git.zx2c4.com/wireguard-linux-compat /tmp/wireguard-linux-compat || true
        make -C /tmp/wireguard-linux-compat/src
        make -C /tmp/wireguard-linux-compat/src install
    fi

    modprobe wireguard
    echo "wireguard" >>/etc/modules-load.d/wireguard.conf
fi

# tools
mkdir -p /tmp

echo "<- building tools"
git clone https://git.zx2c4.com/wireguard-tools /tmp/wireguard-tools || true
make -C /tmp/wireguard-tools/src
make -C /tmp/wireguard-tools/src install

tee /etc/nftables.conf >/dev/null <<EOF
#!/usr/sbin/nft -f

flush ruleset

EOF

# packet forwarding
echo "<- setting up packet forwarding"
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# nat masquerading
if [[ -n "$ENABLE_NAT_ON_DEVICE" ]]; then 
    echo "<- setting up NAT on $ENABLE_NAT_ON_DEVICE"
    # TODO add rules through nft then dump into config to avoid duplicates
    tee -a /etc/nftables.conf >/dev/null <<EOF
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
    echo "<- setting up routing: $ROUTE_A <-> $ROUTE_B"
    tee -a /etc/nftables.conf >/dev/null <<EOF
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

echo "<- configuring wireguard"
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

WGCONF=/etc/wireguard/wg0.conf

if [[ -z "$HOST_PRIVATE_KEY" ]]; then 
    HOST_PRIVATE_KEY=$(wg genkey)
fi
HOST_PUBLIC_KEY=$(printf "%s" "$HOST_PRIVATE_KEY" | wg pubkey)

tee $WGCONF >/dev/null <<EOF
[Interface]
PrivateKey = $HOST_PRIVATE_KEY
Address = $HOST_ADDRESS/32
ListenPort = $WGPORT
EOF

chmod 600 $WGCONF

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0


echo "--- bootstrapping complete ---"

echo "-> forwarding settings:"
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding

echo "-> service status"
systemctl status wg-quick@wg0 --no-pager || true

echo "-> public key  -> $HOST_PUBLIC_KEY"
echo "-> private key -> $HOST_PRIVATE_KEY"
