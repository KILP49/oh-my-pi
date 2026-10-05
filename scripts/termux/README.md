# Termux / Android arm64 port (omp v18.6.1)

Official npm packages ship no android-arm64 native addon; this branch carries the
source port for omp v18.6.1 plus build/install tooling.

## Patch set (vs upstream v18.6.1)
- `packages/natives/native/loader-state.js` — registers `android-arm64`
- `packages/natives/native/desktop-adapter.js` — guard when `NativeDesktopSession` is absent (avoids WeakMap crash)
- `crates/pi-shell`, `crates/pi-builtins` — Android process/PTY/ps/kill adaptations
- `crates/pi-natives`, `crates/pi-walker` — android target support
- `packages/coding-agent` — bundle scripts, worker runtime, Termux clipboard

## Build (native Termux, first build 30–45 min)
    pkg install bun rust clang cmake make pkg-config llvm git nodejs
    bash scripts/termux/build-oh-my-pi.sh
    # artifact: packages/natives/native/android-build/pi_natives.android-arm64.node

## Install
    bash scripts/termux/stage-omp-18.6.1.sh
    bash scripts/termux/install-omp-18.6.1.sh   # inject addon + patch loader/adapter + atomic swap
    omp --version

The addon carries a version stamp (`PI_NATIVES_VERSION_STAMP:<version>`,
see `packages/natives/native/version-sentinel.js`) that must equal the installed
`@oh-my-pi/pi-natives` version — a new omp release needs a matching rebuild.
