#!/data/data/com.termux/files/usr/bin/bash
# Install the freshly built android addon into the staged 18.6.1 package, test it,
# then atomically swap it over the live 18.3.2 install.
set -euo pipefail
export NO_COLOR=1

PREFIX=/data/data/com.termux/files/usr
STAGE=/data/data/com.termux/files/home/tmp/omp-stage
S=/data/data/com.termux/files/home/.cache/oh-my-pi-termux/source
OUT="$S/packages/natives/native/android-build"
addon="$OUT/pi_natives.android-arm64.node"

[ -f "$addon" ] || { echo "FATAL: addon missing: $addon"; exit 1; }

stage_pkg="$STAGE/lib/node_modules/@oh-my-pi/pi-coding-agent"
live="$PREFIX/lib/node_modules/@oh-my-pi/pi-coding-agent"
natives="$stage_pkg/node_modules/@oh-my-pi/pi-natives"

echo "== 1. install addon into staged package =="
install -m 755 "$addon" "$natives/native/pi_natives.android-arm64.node"

echo "== 2. patch loader (SUPPORTED_PLATFORMS += android-arm64) =="
node - "$natives/native/loader-state.js" <<'NODE'
const fs = require("node:fs");
const loader = process.argv[2];
let source = fs.readFileSync(loader, "utf8");
if (!source.includes('"android-arm64"')) {
	const marker = "const SUPPORTED_PLATFORMS = [";
	if (!source.includes(marker)) throw new Error(`Platform list not found in ${loader}`);
	source = source.replace(marker, `${marker}"android-arm64", `);
	fs.writeFileSync(loader, source);
	console.log("loader patched");
} else {
	console.log("loader already patched");
}
NODE

echo "== 3. patch desktop-adapter guard =="
node - "$natives/native/desktop-adapter.js" <<'NODE'
const fs = require("node:fs");
const adapter = process.argv[2];
let source = fs.readFileSync(adapter, "utf8");
const guard = '\tif (typeof NativeDesktopSession !== "function") return NativeDesktopSession;';
if (!source.includes(guard)) {
	const marker = "export function adaptDesktopSession(NativeDesktopSession) {";
	if (!source.includes(marker)) throw new Error(`adaptDesktopSession not found in ${adapter}`);
	fs.writeFileSync(adapter, source.replace(marker, `${marker}\n${guard}`));
	console.log("adapter patched");
} else {
	console.log("adapter already patched");
}
NODE

echo "== 4. loader-path test (staged, pre-swap) =="
cd "$stage_pkg"
bun -e '
const { loadNative } = await import("./node_modules/@oh-my-pi/pi-natives/native/loader-state.js");
const b = loadNative();
console.log("native loaded:", typeof b.countTokens === "function" ? "countTokens ok" : "MISSING countTokens");
console.log("buildVersion:", b.__piNativesBuildVersion ? b.__piNativesBuildVersion() : "(no export)");
console.log("token probe:", b.countTokens("hello world"));
'
echo "== 5. staged CLI --version (must print 18.6.1) =="
"$STAGE/bin/omp" --version

echo "== 6. atomic swap =="
ts=$(date +%Y%m%d-%H%M%S)
mv "$live" "$live.bak-$ts"
mv "$stage_pkg" "$live"
echo "backup: $live.bak-$ts"
ls -la "$PREFIX/bin/omp"

echo "== 7. live CLI verify =="
"$PREFIX/bin/omp" --version
echo "OMP_1861_INSTALLED"
