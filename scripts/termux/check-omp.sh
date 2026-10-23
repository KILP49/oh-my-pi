#!/data/data/com.termux/files/usr/bin/bash
# Exit 0 if omp is installed and actually runnable on this device.
# Optional arg: expected version (must match exactly).
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
want="${1:-}"
nat="$PREFIX/install/global/node_modules/@oh-my-pi/pi-natives/native"

command -v bun >/dev/null 2>&1 || { echo "no-bun"; exit 2; }
[ -x "$PREFIX/bin/omp" ] || { echo "no-omp"; exit 2; }

v="$(timeout 20 "$PREFIX/bin/omp" --version 2>/dev/null | sed -n 's#^omp/##p' | head -1)"
[ -n "$v" ] || { echo "no-version"; exit 2; }

[ -f "$nat/pi_natives.android-arm64.node" ] || { echo "no-addon"; exit 2; }
grep -q '"android-arm64"' "$nat/loader-state.js" 2>/dev/null || { echo "loader-unpatched"; exit 2; }

bun -e 'const a=require(process.argv[1]); if(typeof a.countTokens!=="function") process.exit(1)' \
  "$nat/pi_natives.android-arm64.node" >/dev/null 2>&1 || { echo "addon-load-fail"; exit 2; }

if [ -n "$want" ] && [ "$v" != "$want" ]; then
  echo "version-mismatch $v != $want"
  exit 3
fi

echo "$v"
exit 0
