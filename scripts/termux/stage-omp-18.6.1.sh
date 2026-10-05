#!/data/data/com.termux/files/usr/bin/bash
# Stage @oh-my-pi/pi-coding-agent@18.6.1 into a side prefix (no touching live install).
set -euo pipefail
export NO_COLOR=1 CARGO_TERM_COLOR=never

STAGE=/data/data/com.termux/files/home/tmp/omp-stage

rm -rf "$STAGE"
mkdir -p "$STAGE"
echo "== npm install into stage (may take several minutes) =="
npm install -g --prefix "$STAGE" @oh-my-pi/pi-coding-agent@18.6.1 --no-fund --no-audit

pkg="$STAGE/lib/node_modules/@oh-my-pi/pi-coding-agent"
echo "== staged version =="
node -p "require('$pkg/package.json').version"
echo "STAGE_INSTALL_DONE"
