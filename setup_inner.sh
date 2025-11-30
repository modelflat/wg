#!/usr/bin/env bash

set -euo pipefail

PUBLIC_KEY=""
PRIVATE_KEY=""

OUTER_PUBLIC_KEY=""
OUTER_PRIVATE_KEY=""

./wgboot.sh 10.0.1.1 "$PUBLIC_KEY" "$PRIVATE_KEY" "" "" "" 443

./wgadd.sh outer 10.100.0.1 "$OUTER_PUBLIC_KEY" "$OUTER_PRIVATE_KEY" "0.0.0.0/0"
