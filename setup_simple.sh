#!/usr/bin/env bash

set -euo pipefail

./wgboot.sh 10.0.0.1 "" eth0 wg0 eth0 443
