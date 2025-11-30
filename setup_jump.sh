#!/usr/bin/env bash

set -euo pipefail

JUMP_PRIVATE_KEY=$1
PRIMARY_PRIVATE_KEY=$2

if [[ -z "$JUMP_PRIVATE_KEY" ]] || [[ -z "$PRIMARY_PRIVATE_KEY" ]]; then
    echo "both private keys need to be supplied"
    exit 1
fi

./wgboot.sh 10.0.1.1 "$JUMP_PRIVATE_KEY" "" "" "" 443

./wgadd.sh primary 10.100.0.1 "$PRIMARY_PRIVATE_KEY" "0.0.0.0/0"
