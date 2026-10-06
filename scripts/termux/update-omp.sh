#!/data/data/com.termux/files/usr/bin/bash
# One-line Termux updater for the android-arm64 omp port.
#
#   curl -fsSL https://raw.githubusercontent.com/KILP49/oh-my-pi/android-18.6.3/scripts/termux/update-omp.sh | bash
#   # or pin a version:
#   curl -fsSL .../update-omp.sh | bash -s -- 18.6.3
#
# Installs the CLI from npm (via bun, no root), swaps in the CI-built
# android-arm64 addon from the fork's per-version release, applies the
# loader/adapter patches, verifies the native module, and removes the previous
# install.
set -euo pipefail

V="${1:-}"
REPO="${OMP_FORK:-KILP49/oh-my-pi}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

command -v bun >/dev/null || { echo "!! 需要 bun：pkg install bun"; exit 1; }

if [ -z "$V" ]; then
  echo "== 0/5 解析最新 android-addon 版本 =="
  V="$(curl -fsSL --retry 3 --connect-timeout 15 "https://api.github.com/repos/$REPO/releases?per_page=100" | python3 -c '
import json, re, sys
pat = re.compile(r"^android-addon-(\d+(?:\.\d+)*)$")
rels = [m for m in (pat.match(str(r.get("tag_name", ""))) for r in json.load(sys.stdin)) if m]
print(max(rels, key=lambda m: [int(x) for x in m.group(1).split(".")]).group(1) if rels else "")')"
  [ -n "$V" ] || { echo "!! 未找到 android-addon-* release（CI 尚未产出？可显式传版本，如：bash -s -- 18.6.3）"; exit 2; }
  echo "latest: $V"
fi

GLOBAL="$PREFIX/install/global/node_modules"
NATIVES="$GLOBAL/@oh-my-pi/pi-natives/native"
ADDON_URL="https://github.com/$REPO/releases/download/android-addon-$V/pi_natives.android-arm64.node"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "== 1/5 下载预编译 addon ($V) =="
curl -fL --retry 3 --connect-timeout 15 -o "$TMP/addon.node" "$ADDON_URL"

echo "== 2/5 bun 安装 CLI@$V 到 \$PREFIX =="
rm -f "$PREFIX/bin/omp"
# --backend=copyfile: without it bun links package files to its cache and the
# CLI resolves @oh-my-pi/pi-natives from a *different* (unpatched) cache copy.
BUN_INSTALL="$PREFIX" bun add -g --backend=copyfile "@oh-my-pi/pi-coding-agent@$V"

echo "== 3/5 注入 addon + loader 补丁 =="
[ -d "$NATIVES" ] || { echo "!! 找不到 $NATIVES（bun 安装布局异常）"; exit 1; }
install -m 755 "$TMP/addon.node" "$NATIVES/pi_natives.android-arm64.node"
python3 - "$NATIVES/loader-state.js" <<'PY'
import sys

loader = sys.argv[1]

src = open(loader).read()
if '"android-arm64"' not in src:
    marker = "const SUPPORTED_PLATFORMS = ["
    assert marker in src, "SUPPORTED_PLATFORMS not found in loader-state.js"
    open(loader, "w").write(src.replace(marker, marker + '"android-arm64", ', 1))
    print("loader patched")
else:
    print("loader already patched")
PY

echo "== 4/5 验证 =="
"$PREFIX/bin/omp" --version
bun -e 'const a=require(process.argv[1]);console.log("native exports:",Object.keys(a).length)' \
  "$NATIVES/pi_natives.android-arm64.node"

echo "== 5/5 清理旧安装 =="
OLD="$PREFIX/lib/node_modules/@oh-my-pi/pi-coding-agent"
if [ -d "$OLD" ]; then rm -rf "$OLD" && echo "removed old npm-style install: $OLD"; fi

echo "✅ omp $V 已就绪：$PREFIX/bin/omp → $(readlink -f "$PREFIX/bin/omp")"
