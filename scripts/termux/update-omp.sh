#!/data/data/com.termux/files/usr/bin/bash
# One-line Termux installer/updater for the android-arm64 omp port.
#
#   curl -fsSL https://raw.githubusercontent.com/KILP49/oh-my-pi/android-18.12.6/scripts/termux/update-omp.sh | bash
#   # or pin a version:
#   curl -fsSL .../update-omp.sh | bash -s -- 18.12.6
#
# Fast path: if omp is already installed, at the requested version, and the
# android addon actually loads, the script exits without touching apt/npm.
# Set OMP_FORCE=1 to reinstall anyway.
#
# Requires only bun (pkg install bun). python is not needed.
set -euo pipefail

V="${1:-}"
REPO="${OMP_FORK:-KILP49/oh-my-pi}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GLOBAL="$PREFIX/install/global/node_modules"
NATIVES="$GLOBAL/@oh-my-pi/pi-natives/native"

command -v bun >/dev/null || { echo "!! bun is required: pkg install bun"; exit 1; }

check_ready() {
  [ -x "$PREFIX/bin/omp" ] || return 1
  [ -f "$NATIVES/pi_natives.android-arm64.node" ] || return 1
  grep -q '"android-arm64"' "$NATIVES/loader-state.js" 2>/dev/null || return 1
  local cur
  cur="$(timeout 20 "$PREFIX/bin/omp" --version 2>/dev/null | sed -n 's#^omp/##p' | head -1)"
  [ -n "$cur" ] || return 1
  if [ -n "${1:-}" ] && [ "$cur" != "$1" ]; then return 1; fi
  bun -e 'const a=require(process.argv[1]); if(typeof a.countTokens!=="function") process.exit(1)' \
    "$NATIVES/pi_natives.android-arm64.node" >/dev/null 2>&1 || return 1
  printf '%s' "$cur"
}

if [ -z "$V" ]; then
  echo "== 0/5 resolve newest android-addon version =="
  V="$(curl -fsSL --retry 3 --connect-timeout 15 "https://api.github.com/repos/$REPO/releases?per_page=100" \
    | bun -e 'const rs=JSON.parse(await Bun.stdin.text()); const re=/^android-addon-(\d+(?:\.\d+)*)$/; const vs=rs.map(r=>re.exec(r.tag_name||"")).filter(Boolean).map(m=>m[1]); vs.sort((a,b)=>a.localeCompare(b,undefined,{numeric:true})); console.log(vs.at(-1) ?? "")')"
  [ -n "$V" ] || { echo "!! no android-addon-* release found (pass a version explicitly, e.g. bash -s -- 18.12.6)"; exit 2; }
  echo "latest: $V"
fi

if [ "${OMP_FORCE:-0}" != "1" ] && cur="$(check_ready "$V")"; then
  echo "omp $cur is already installed and runnable; nothing to do."
  echo "set OMP_FORCE=1 to reinstall, or pass a different version."
  exit 0
fi

ADDON_URL="https://github.com/$REPO/releases/download/android-addon-$V/pi_natives.android-arm64.node"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "== 1/5 download prebuilt addon ($V) =="
curl -fL --retry 3 --connect-timeout 15 -o "$TMP/addon.node" "$ADDON_URL"

echo "== 2/5 bun install CLI@$V into \$PREFIX =="
rm -f "$PREFIX/bin/omp"
# --backend=copyfile: without it bun links package files to its cache and the
# CLI resolves @oh-my-pi/pi-natives from a *different* (unpatched) cache copy.
BUN_INSTALL="$PREFIX" bun add -g --backend=copyfile "@oh-my-pi/pi-coding-agent@$V"

echo "== 3/5 inject addon + loader patch =="
[ -d "$NATIVES" ] || { echo "!! missing $NATIVES (unexpected bun install layout)"; exit 1; }
install -m 755 "$TMP/addon.node" "$NATIVES/pi_natives.android-arm64.node"
if grep -q '"android-arm64"' "$NATIVES/loader-state.js"; then
  echo "loader already patched"
else
  sed -i 's/const SUPPORTED_PLATFORMS = \[/const SUPPORTED_PLATFORMS = ["android-arm64", /' "$NATIVES/loader-state.js"
  grep -q '"android-arm64"' "$NATIVES/loader-state.js" || { echo "!! loader patch failed"; exit 1; }
  echo "loader patched"
fi

echo "== 4/5 verify =="
"$PREFIX/bin/omp" --version
bun -e 'const a=require(process.argv[1]);console.log("native exports:",Object.keys(a).length)' \
  "$NATIVES/pi_natives.android-arm64.node"

echo "== 5/5 remove legacy npm-style install =="
OLD="$PREFIX/lib/node_modules/@oh-my-pi/pi-coding-agent"
if [ -d "$OLD" ]; then rm -rf "$OLD" && echo "removed old npm-style install: $OLD"; fi

echo "✅ omp $V ready: $PREFIX/bin/omp -> $(readlink -f "$PREFIX/bin/omp")"
echo "   If the TUI flickers in Termux, run with PI_NO_SYNC_OUTPUT=1 (DEC 2026 workaround)."
