#!/data/data/com.termux/files/usr/bin/bash
# Tune the installed omp CLI for slow terminals (Termux).
#
#   bash patch-render.sh [paint_ms] [reveal_ms] [--no-italic]
#   bash patch-render.sh restore
#
# paint_ms   coalesce repaints (default 40 ms)
# reveal_ms  streaming reveal frame (default 60 ms; stock is 33.3)
# --no-italic  drop SGR italics (Termux synthesises them and they overlap)
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CLI="$PREFIX/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js"
NEEDLE="scheduleImmediate:(e)=>{setImmediate(e)}"
REVEAL_FROM="var scn=33.333333333333336"
ITALIC_FROM='italic:{open:`${tr}3m`,close:`${tr}23m`}'

[ -f "$CLI" ] || { echo "!! not found: $CLI"; exit 1; }

if [ "${1:-}" = "restore" ]; then
  BAK="$(ls -1t "$CLI".bak.* 2>/dev/null | head -1)"
  [ -n "$BAK" ] || { echo "!! no backup found"; exit 1; }
  cp -f "$BAK" "$CLI"
  echo "restored $CLI from $BAK"
  "$PREFIX/bin/omp" --version
  exit 0
fi

PAINT_MS=40
REVEAL_MS=60
NO_ITALIC=0
for arg in "$@"; do
  case "$arg" in
    --no-italic) NO_ITALIC=1 ;;
    *[!0-9]*) echo "!! bad argument: $arg"; exit 1 ;;
    *) if [ "$PAINT_MS" = "40" ]; then PAINT_MS="$arg"; else REVEAL_MS="$arg"; fi ;;
  esac
done

if grep -q "scheduleImmediate:(e)=>{setTimeout(e," "$CLI"; then
  echo "already patched (paint); run 'bash $0 restore' first"
  exit 0
fi

SITES="$(bun -e 'const fs=require("node:fs");const s=fs.readFileSync(process.argv[1],"utf8");const n="scheduleImmediate:(e)=>{setImmediate(e)}";console.log(s.split(n).length-1)' "$CLI")"
if [ "$SITES" != "2" ]; then
  echo "!! expected 2 scheduler sites, found $SITES; refusing to patch"
  exit 1
fi

BAK="$CLI.bak.$(date +%Y%m%d-%H%M%S)"
cp -f "$CLI" "$BAK"
echo "backup: $BAK"

bun -e '
const fs=require("node:fs");
const [p, paint, reveal, italic] = process.argv.slice(1);
let s=fs.readFileSync(p,"utf8");
const n="scheduleImmediate:(e)=>{setImmediate(e)}";
if(!s.includes(n)){console.error("scheduler sites changed");process.exit(2)}
s=s.split(n).join(`scheduleImmediate:(e)=>{setTimeout(e,${paint})}`);
if(s.includes("var scn=33.333333333333336")) s=s.split("var scn=33.333333333333336").join(`var scn=${reveal}`);
if(italic==="1"){
  const it="italic:{open:`${tr}3m`,close:`${tr}23m`}";
  if(!s.includes(it)){console.error("italic style map changed");process.exit(2)}
  s=s.split(it).join(`italic:{open:"",close:""}`);
}
fs.writeFileSync(p,s);
' "$CLI" "$PAINT_MS" "$REVEAL_MS" "$NO_ITALIC"

grep -q "scheduleImmediate:(e)=>{setTimeout(e,$PAINT_MS)}" "$CLI" || { echo "!! patch failed"; exit 1; }
echo "patched: paint=${PAINT_MS}ms reveal=${REVEAL_MS}ms italic_off=${NO_ITALIC}"
"$PREFIX/bin/omp" --version
echo "restart omp; 'bash $0 restore' undoes everything"
