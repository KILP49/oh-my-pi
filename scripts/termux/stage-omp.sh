#!/data/data/com.termux/files/usr/bin/bash
# Stage @oh-my-pi/pi-coding-agent into a side prefix (no touching live install).
# Version: $1, or the port branch's own version.
set -euo pipefail
export NO_COLOR=1 CARGO_TERM_COLOR=never

S=/data/data/com.termux/files/home/.cache/oh-my-pi-termux/repo
V="${1:-$(node -p "require('$S/packages/coding-agent/package.json').version")}"

STAGE=/data/data/com.termux/files/home/tmp/omp-stage

rm -rf "$STAGE"
mkdir -p "$STAGE"
echo "== npm install @$V into stage (may take several minutes) =="
npm install -g --prefix "$STAGE" "@oh-my-pi/pi-coding-agent@$V" --no-fund --no-audit

pkg="$STAGE/lib/node_modules/@oh-my-pi/pi-coding-agent"
echo "== staged version =="
node -p "require('$pkg/package.json').version"
echo "STAGE_INSTALL_DONE"
