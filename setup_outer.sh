#!/usr/bin/env bash

set -euo pipefail

./wgboot.sh 10.0.0.1 "" "" eth0 wg0 eth0 443

./wgadd.sh inner 10.100.0.2 "" "" "10.100.0.2/32, 10.0.1.0/24"
