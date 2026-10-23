<p align="center">
  <img src="https://github.com/can1357/oh-my-pi/blob/main/assets/hero.png?raw=true" alt="omp">
</p>

<p align="center">
  <strong>omp on Termux / Android arm64</strong>
  <strong><a href="https://omp.sh">omp.sh</a></strong>
</p>

<p align="center">
  <a href="https://github.com/KILP49/oh-my-pi/releases"><img src="https://img.shields.io/github/v/release/KILP49/oh-my-pi?include_prereleases&label=android-addon&colorA=222222&colorB=3FB950" alt="android-addon release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>

<p align="center">
  Fork of <a href="https://github.com/can1357/oh-my-pi">can1357/oh-my-pi</a> ·
  built by <a href="https://stencil.so">Stencil Labs</a>
</p>

This fork adds an `android-arm64` native addon and a one-line installer, so
[omp](https://omp.sh) — the coding agent with the IDE wired in — runs on
Android/Termux without root and without a Rust toolchain.

- **Port branch:** `android-18.12.6` (base: upstream `v18.12.6`)
- **Addon release for this branch:** `android-addon-18.12.6`
- **Older ports:** `android-18.8.9`, `android-18.8.3`, `android-18.6.3`, `android-18.6.1`
- **Patch set and build details:** [`scripts/termux/README.md`](scripts/termux/README.md)

## Why a fork?

Upstream npm packages ship no `android-arm64` build (`SUPPORTED_PLATFORMS` has no
Android entry), so `omp` aborts on Termux with:

```
Unsupported platform: android-arm64
```

This branch carries the source port and a GitHub Actions job that cross-compiles
`pi_natives.android-arm64.node` with the Android NDK and publishes it as a
per-version release. The phone downloads a prebuilt addon; it never compiles Rust.

## Requirements

- Android device with `arm64-v8a` (`uname -m` prints `aarch64`), Android 7.0+ (API 24)
- [Termux](https://github.com/termux/termux-app#installation) from F-Droid or GitHub — the Play Store build is outdated
- `bun` and `curl`:

```sh
pkg install bun curl
```

No root required. Everything lands under `$PREFIX`
(`/data/data/com.termux/files/usr`).

## Install or update

```sh
# install or update to the newest android-addon-* release
curl -fsSL -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/KILP49/oh-my-pi/contents/scripts/termux/update-omp.sh?ref=android-18.12.6" | bash
```

```sh
# pin a version
curl -fsSL -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/KILP49/oh-my-pi/contents/scripts/termux/update-omp.sh?ref=android-18.12.6" | bash -s -- 18.12.6
```

Where `raw.githubusercontent.com` is reachable, the canonical form also works:

```sh
curl -fsSL https://raw.githubusercontent.com/KILP49/oh-my-pi/android-18.12.6/scripts/termux/update-omp.sh | bash
```

Without an argument the updater picks the newest `android-addon-*` release
(currently `18.12.6`), installs the matching CLI, and verifies `omp --version`.
The updater is idempotent: if that version is already installed and the addon
actually loads, it exits without downloading or installing anything
(`OMP_FORCE=1` forces a reinstall).

`scripts/termux/check-omp.sh [version]` performs the same check standalone:
exit `0` means omp runs (CLI + patched loader + addon), `2` means something is
missing or broken, `3` means a different version is installed.

### What the installer does

1. resolves the version — the `bash -s -- <version>` argument, or the newest `android-addon-*` release
2. downloads `pi_natives.android-arm64.node` from that release
3. `BUN_INSTALL=$PREFIX bun add -g --backend=copyfile @oh-my-pi/pi-coding-agent@<version>`
4. injects the addon into `@oh-my-pi/pi-natives/native/` and idempotently adds `android-arm64` to `loader-state.js`
5. verifies the native exports, then removes a legacy npm-style install if present

`--backend=copyfile` is required: with bun's default install the package files are
linked to bun's cache and the CLI resolves an **unpatched**
`@oh-my-pi/pi-natives` copy from `~/.bun/install/cache/...`.

## How the port works

| Piece | What it does |
|---|---|
| `packages/natives/native/loader-state.js` | registers `android-arm64` in `SUPPORTED_PLATFORMS` |
| `crates/pi-shell`, `crates/pi-builtins` | Android process, PTY, `ps` and `kill` adaptations |
| `crates/pi-natives`, `crates/pi-walker` | `aarch64-linux-android` target support |
| `packages/coding-agent` | bundle scripts, worker runtime, Termux clipboard |

CI (`.github/workflows/termux-android-addon.yml`) runs on changes to `crates/**`,
`packages/natives/**` or the workflow itself, plus manual dispatch. It uses the
pinned `nightly-2026-10-06` toolchain, the `aarch64-linux-android` target, NDK r27c
(`ANDROID_ABI=arm64-v8a`, `ANDROID_PLATFORM=android-24`), `@napi-rs/cli@3.7.2`,
`llvm-strip` and the version stamp. Each successful build publishes
`android-addon-<version>` with the addon attached. A failed run commits
`ci-debug.log` to the branch so the log is readable without API access.

## Version stamp (read this)

The addon carries a 64-byte stamp, `PI_NATIVES_VERSION_STAMP:<version>`, and the
loader compares it against `@oh-my-pi/pi-natives#version`. The CLI and the addon
must come from the same version; that is why the updater installs both from
`<version>`.

**Never run the upstream installer or `omp update` on Termux.** Both restore the
stock `pi-natives` package and native loading breaks again.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Unsupported platform: android-arm64` | stock npm package, or a reinstall wiped the patch | rerun the updater |
| `omp --version` works but tools crash on native calls | addon/CLI version mismatch | reinstall with the matching `<version>` |
| `bun: command not found` | bun missing | `pkg install bun` |
| `.node` download fails | GitHub releases blocked | use a proxy; the updater already retries |
| `raw.githubusercontent.com` unreachable | network or proxy | use the `api.github.com` form above |
| stale files after a failed update | interrupted install | rerun the updater; it removes the old install |
| TUI flickers or tears | DEC 2026 synchronized output is mishandled by Termux 0.118.x | launch with `PI_NO_SYNC_OUTPUT=1 omp` |

## Build it yourself (fallback, 30–45 min)

```sh
pkg install bun rust clang cmake make pkg-config llvm git nodejs python
bash scripts/termux/build-oh-my-pi.sh
# artifact: packages/natives/native/android-build/pi_natives.android-arm64.node

bash scripts/termux/stage-omp.sh
bash scripts/termux/install-omp.sh
omp --version
```

## Branches and releases

| Branch | Addon release |
|---|---|
| `android-18.6.1` | `android-addon-18.6.1` |
| `android-18.6.3` | `android-addon-18.6.3` |
| `android-18.8.3` | `android-addon-18.8.3` |
| `android-18.8.9` | `android-addon-18.8.9` |
| `android-18.12.6` (default) | `android-addon-18.12.6` |

CI build for 18.12.6 (2026-10-23): `PI_NATIVES_VERSION_STAMP:18.12.6`,
98,806,304 bytes after `llvm-strip`. Device verification for 18.12.6 is pending;
18.8.9 was previously verified on Android 16 / arm64 (bun 1.4.2, 131 native exports).

## Upstream

The agent itself — providers, tools, LSP/DAP, TUI, RPC — is upstream's work:

- Repository: [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi)
- Docs: [upstream README](https://github.com/can1357/oh-my-pi#readme) · [omp.sh](https://omp.sh)
- License: [MIT](LICENSE)
