#!/data/data/com.termux/files/usr/bin/bash
# Coalesce TUI repaints to smooth streaming on slow terminals (Termux).
# Patches the installed CLI bundle in place; a timestamped backup is kept.
#
#   bash patch-render.sh [ms]     # default 40
#   bash patch-render.sh restore  # restore the newest backup
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CLI="$PREFIX/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js"
NEEDLE="scheduleImmediate:(e)=>{setImmediate(e)}"

[ -f "$CLI" ] || { echo "!! not found: $CLI"; exit 1; }

if [ "${1:-}" = "restore" ]; then
  BAK="$(ls -1t "$CLI".bak.* 2>/dev/null | head -1)"
  [ -n "$BAK" ] || { echo "!! no backup found"; exit 1; }
  cp -f "$BAK" "$CLI"
  echo "restored $CLI from $BAK"
  "$PREFIX/bin/omp" --version
  exit 0
fi

MS="${1:-40}"

if grep -q "scheduleImmediate:(e)=>{setTimeout(e,$MS)}" "$CLI"; then
  echo "already patched ($MS ms)"
  exit 0
fi
if grep -q "scheduleImmediate:(e)=>{setTimeout(e," "$CLI"; then
  echo "!! already patched with another interval; run 'bash $0 restore' first"
  exit 1
fi

count="$(bun -e 'const fs=require("node:fs");const s=fs.readFileSync(process.argv[1],"utf8");const n="scheduleImmediate:(e)=>{setImmediate(e)}";console.log(s.split(n).length-1)' "$CLI")"
if [ "$count" != "2" ]; then
  echo "!! expected 2 scheduler sites, found $count; refusing to patch"
  exit 1
fi

BAK="$CLI.bak.$(date +%Y%m%d-%H%M%S)"
cp -f "$CLI" "$BAK"
echo "backup: $BAK"

bun -e 'const fs=require("node:fs");const p=process.argv[1],ms=process.argv[2];const n="scheduleImmediate:(e)=>{setImmediate(e)}";let s=fs.readFileSync(p,"utf8");fs.writeFileSync(p,s.split(n).join(`scheduleImmediate:(e)=>{setTimeout(e,${ms})}`))' "$CLI" "$MS"

grep -q "scheduleImmediate:(e)=>{setTimeout(e,$MS)}" "$CLI" || { echo "!! patch failed"; exit 1; }
echo "patched both scheduler sites to ${MS} ms"
"$PREFIX/bin/omp" --version
echo "restart omp; use 'bash $0 restore' to undo"
