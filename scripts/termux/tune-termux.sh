#!/data/data/com.termux/files/usr/bin/bash
# Apply Termux-friendly rendering settings to omp.
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
OMP="${OMP_BIN:-$PREFIX/bin/omp}"

[ -x "$OMP" ] || { echo "!! omp not found at $OMP"; exit 1; }

"$OMP" config set display.smoothStreaming false
"$OMP" config set display.shimmer disabled
"$OMP" config set tui.reactions false
"$OMP" config set symbolPreset ascii
"$OMP" config set statusLine.preset ascii
"$OMP" config set statusLine.separator pipe
"$OMP" config set title.icons boring
"$OMP" config set browser.enabled false

echo "applied Termux rendering settings:"
echo "  display.smoothStreaming=false  (chunked text, fewer repaints)"
echo "  display.shimmer=disabled       (no 70ms thinking-block repaints)"
echo "  tui.reactions=false"
echo "  symbolPreset/statusLine=ascii  (no emoji/powerline width drift)"
echo "  title.icons=boring"
echo "  browser.enabled=false          (no Chromium on Termux)"
echo "restart omp to apply."
