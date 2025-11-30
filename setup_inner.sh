#!/usr/bin/env bash

set -euo pipefail

INNER_PRIVATE_KEY=""
OUTER_PRIVATE_KEY=""

./wgboot.sh 10.0.1.1 "$INNER_PRIVATE_KEY" "" "" "" 443

./wgadd.sh outer 10.100.0.1 "$OUTER_PRIVATE_KEY" "0.0.0.0/0"
