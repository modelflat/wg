#!/usr/bin/env bash

set -euo pipefail

INNER_PRIVATE_KEY=$1
OUTER_PRIVATE_KEY=$2

if [[ -z "$INNER_PRIVATE_KEY" ]] || [[ -z "$OUTER_PRIVATE_KEY"]]; then
    echo "both private keys need to be supplied"
    exit 1
fi

./wgboot.sh 10.0.1.1 "$INNER_PRIVATE_KEY" "" "" "" 443

./wgadd.sh outer 10.100.0.1 "$OUTER_PRIVATE_KEY" "0.0.0.0/0"
