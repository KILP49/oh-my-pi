# Termux / Android arm64 port (omp, branch `android-18.6.3`)

Upstream npm packages ship no `android-arm64` native addon, so `omp` aborts on Termux
with `Unsupported platform: android-arm64`. This branch carries the source port plus
the tooling that builds, ships and installs it.

## Patch set (vs upstream)

- `packages/natives/native/loader-state.js` — registers `android-arm64` in `SUPPORTED_PLATFORMS`
- `crates/pi-shell`, `crates/pi-builtins` — Android process/PTY/`ps`/`kill` adaptations
- `crates/pi-natives`, `crates/pi-walker` — android target support
- `packages/coding-agent` — bundle scripts, worker runtime, Termux clipboard

## Install / update (one line)

```sh
# raw.githubusercontent.com unreachable (e.g. mainland China without a proxy) -> use the api.github.com form
curl -fsSL -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/KILP49/oh-my-pi/contents/scripts/termux/update-omp.sh?ref=android-18.6.3" | bash

# canonical form
curl -fsSL https://raw.githubusercontent.com/KILP49/oh-my-pi/android-18.6.3/scripts/termux/update-omp.sh | bash

# pin a version (default: newest android-addon-* release)
#   ... | bash -s -- 18.6.3
```

Requires `bun`, `curl` and `python3` in Termux (`pkg install bun curl python`). No root,
no toolchain.

What `update-omp.sh` does:

1. resolve the version — argument, or the newest `android-addon-*` release
2. download `pi_natives.android-arm64.node` from that release
3. `BUN_INSTALL=$PREFIX bun add -g --backend=copyfile @oh-my-pi/pi-coding-agent@<version>`
4. inject the addon into `pi-natives/native/` and idempotently patch `loader-state.js`
5. verify (`omp --version`, native exports) and remove a legacy npm-style install if present

`--backend=copyfile` is required: with bun's default install the package files are
linked to bun's cache and the CLI ends up resolving an *unpatched*
`@oh-my-pi/pi-natives` copy from `~/.bun/install/cache/...`.

## CI

`.github/workflows/termux-android-addon.yml`

- triggers on pushes touching `crates/**`, `packages/natives/**` or the workflow itself; also `workflow_dispatch`
- toolchain: the pinned `nightly-2026-08-12` from `rust-toolchain.toml` plus the `aarch64-linux-android` target,
  NDK r27c, and `CMAKE_TOOLCHAIN_FILE` / `ANDROID_ABI=arm64-v8a` / `ANDROID_PLATFORM=android-24` for the cmake-based C dependency
- build: `npx --yes --package @napi-rs/cli@3.7.2 napi build --target aarch64-linux-android --platform --no-js --dts index.d.ts --profile local`,
  then `llvm-strip`, then `bun scripts/stamp-native-version.ts`
- publishes the `android-addon-<version>` release with `pi_natives.android-arm64.node` attached
- on failure it commits the tail of the build log as `ci-debug.log` on the branch (root-level file → does not retrigger the workflow),
  so a failed run is readable without API access

## Local build (fallback; first build 30–45 min)

    pkg install bun rust clang cmake make pkg-config llvm git nodejs python
    bash scripts/termux/build-oh-my-pi.sh
    # artifact: packages/natives/native/android-build/pi_natives.android-arm64.node

Then stage and install it:

    bash scripts/termux/stage-omp.sh
    bash scripts/termux/install-omp.sh   # inject addon + patch loader + atomic swap
    omp --version

## Invariants

- The addon carries a 64-byte version stamp (`PI_NATIVES_VERSION_STAMP:<version>`,
  see `packages/natives/native/version-sentinel.js`). The loader compares it exactly
  against `@oh-my-pi/pi-natives#version`, and the stamp must match the installed package —
  a new omp release needs a matching addon rebuild.
- Never run the upstream installer or `omp update` on Termux: both restore the stock
  `pi-natives` package and native loading breaks.

## Verified on device (Android 16 / arm64, bun 1.4.2)

- addon built by CI release `android-addon-18.6.1` loads with `native exports: 126`,
  `buildVersion: 18.6.1` (175,117,920 bytes after `llvm-strip`)
- one-line install end-to-end finishes in ~45 s → `omp/18.6.1`
