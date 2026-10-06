#!/data/data/com.termux/files/usr/bin/bash
# Build the android-arm64 pi_natives addon from the port checkout below.
set -euo pipefail
export NO_COLOR=1 CARGO_TERM_COLOR=never

S=/data/data/com.termux/files/home/.cache/oh-my-pi-termux/source
TOOLS=/data/data/com.termux/files/home/.cache/oh-my-pi-termux/tools
OUT="$S/packages/natives/native/android-build"

echo "== preflight =="
cd "$S"
echo "branch: $(git rev-parse --abbrev-ref HEAD)"
echo "natives version: $(node -p "require('$S/packages/natives/package.json').version")"
echo "agent version:   $(node -p "require('$S/packages/coding-agent/package.json').version")"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "== napi build (this takes a while) =="
cd "$S/crates/pi-natives"
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}" \
CMAKE_POLICY_VERSION_MINIMUM=3.5 \
PCRE2_SYS_STATIC=1 \
RUSTC_BOOTSTRAP=1 \
RUSTFLAGS='-C target-cpu=generic' \
"$TOOLS/node_modules/.bin/napi" build \
  --manifest-path Cargo.toml \
  --package-json-path "$S/packages/natives/package.json" \
  --platform --no-js --dts index.d.ts \
  -o "$OUT" --profile local

addon="$OUT/pi_natives.android-arm64.node"
[ -f "$addon" ] || { echo "ANDROID_ADDON_MISSING"; exit 1; }

echo "== strip =="
llvm-strip --strip-unneeded "$addon"

echo "== stamp =="
cd "$S"
bun scripts/stamp-native-version.ts "$addon"

echo "== verify =="
bun -e 'const a=require(process.argv[1]); console.log("exports:", Object.keys(a).length, "buildVersion:", a.__piNativesBuildVersion && a.__piNativesBuildVersion());' "$addon"
ls -la "$addon"
echo "ANDROID_ADDON_READY"
