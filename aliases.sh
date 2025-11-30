#!/usr/bin/env bash

set -euo pipefail

FILE=${1:-'.bashrc'}

WGSCRIPTS_DIR=$(readlink -f ".")

cat >>$FILE <<EOF

export WGSCRIPTS_DIR=$WGSCRIPTS_DIR

function wgadd() {
    ( cd \$WGSCRIPTS_DIR && ./wgadd.sh "\$@" )
}

function wglink() {
    ( cd \$WGSCRIPTS_DIR && ./wglink.sh "\$@" )
}

EOF
