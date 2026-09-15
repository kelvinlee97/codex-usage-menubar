<div align="center">

<img src="Assets/AppIcon.png" width="120" alt="Codex Usage Menubar app icon" />

# Codex Usage Menubar

**Your Codex CLI usage, always one glance away.**

A tiny macOS menu-bar app that shows your remaining 5-hour and 7-day [Codex CLI](https://github.com/openai/codex) usage, reset times, and credit balance — no window, no Dock icon, no fuss.

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)](#requirements)
[![Universal](https://img.shields.io/badge/chip-Apple%20Silicon%20%2B%20Intel-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<sub>🍎 macOS only — this is a native menu-bar app and does not run on Windows or Linux.</sub>

<img src="docs/screenshots/popover.png" width="420" alt="Codex Usage Menubar popover showing 5-hour and 7-day usage limits and credit balance" />

</div>

## Why

Codex CLI's usage limits reset on rolling windows, and it's easy to burn through a session without realizing you're close to the wall. Codex Usage Menubar sits quietly in your menu bar and answers one question at a glance: *how much do I have left?*

- **5-hour window** — percentage remaining and exact reset time
- **7-day window** — percentage remaining and exact reset time
- **Credit balance** — pulled straight from your Codex account
- **Launch at Login** — one toggle, no extra setup

No Dock icon, no window to manage — it lives in the menu bar and polls the local Codex CLI every two minutes (and whenever you open it).

> Unofficial and not affiliated with OpenAI.

## Requirements

- **macOS 14 (Sonoma) or later** — Apple Silicon and Intel are both supported; the release build is a universal binary.
- [Codex CLI](https://github.com/openai/codex) installed and authenticated (`codex login`)
- [Swift](https://www.swift.org/install/) toolchain (Xcode or Command Line Tools) — only if you build from source

## Download

1. Grab `CodexUsageMenubar.zip` from the [latest release](https://github.com/kelvinlee97/codex-usage-menubar/releases/latest).
2. Unzip it and drag **Codex Usage Menubar.app** into `/Applications`.
3. Launch it. The app is signed with a Developer ID certificate and notarized by Apple, so it opens normally — no Gatekeeper warning and no right-click-to-open workaround.

You'll see the usage percentage appear in your menu bar. If it shows an error instead, confirm `codex login` works in your terminal first.

## Install from source

Clone and run the build script, which compiles the app, stages it into a `.app` bundle, installs it to `/Applications`, and launches it:

```bash
git clone https://github.com/kelvinlee97/codex-usage-menubar.git
cd codex-usage-menubar
./script/build_and_run.sh
```

This installs `/Applications/Codex Usage Menubar.app`.

The app appears in your menu bar showing your remaining usage percentage. Click it to open the popover with full details, a link to the Codex usage page, and a Launch at Login toggle.

## Build from source

```bash
swift build
```

This compiles the executable without bundling it into a `.app` — useful for quick iteration or CI. Release build:

```bash
CODEX_BALANCE_CONFIGURATION=release ./script/build_and_run.sh
```

Dev builds are single-architecture for speed. Set `CODEX_BALANCE_UNIVERSAL=1` to produce a universal (arm64 + x86_64) binary; `qa.sh` and `package_release.sh` do this for you. Version strings come from `CODEX_BALANCE_VERSION` / `CODEX_BALANCE_BUILD` (default `1.0.0` / `1`).

## Other build script modes

```bash
./script/build_and_run.sh --verify     # launch and confirm the process is running
./script/build_and_run.sh --logs       # launch and stream all app logs
./script/build_and_run.sh --telemetry  # launch and stream only this app's logs
./script/build_and_run.sh --debug      # launch under lldb
```

## Testing

There's no XCTest target; a self-check harness covers parsing, percentage math, executable resolution, and pipe handling:

```bash
CODEX_BALANCE_SELF_CHECK=1 swift run CodexBalance
```

Run the full local QA gate (release build, self-check, bundle/icon/signature checks, launch, and a live usage refresh) before shipping a change:

```bash
./script/qa.sh
```

## Packaging a release

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="codex-usage-notary" \
./script/package_release.sh
```

Public release packaging requires both variables and fails immediately if either is missing. It signs, notarizes, staples, rebuilds, and verifies `dist/CodexUsageMenubar.zip`.

## How it works

Codex Usage Menubar locates the Codex CLI on your machine, launches `codex app-server --stdio`, and talks to it over stdin/stdout to read your account's rate-limit and credit-balance data. This is not a public/stable API — it's the same interface the Codex CLI itself uses locally, so it may change between Codex CLI releases.

## Troubleshooting

The popover shows an error banner with a Retry button whenever a refresh fails; the message text tells you which of these it is.

**"Codex CLI was not found. Install Codex or set CODEX_CLI_PATH."**
The app couldn't find a `codex` executable. It checks, in order: the `CODEX_CLI_PATH` environment variable, the bundled ChatGPT.app resource path, every directory on your `PATH`, then common install locations (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.volta/bin`, `~/.asdf/shims`, `~/.npm-global/bin`). [Install the Codex CLI](https://github.com/openai/codex) if you haven't, or set `CODEX_CLI_PATH` to its full path if it lives somewhere else.

**"Codex usage service did not respond within 10 seconds." / "Codex usage service stopped unexpectedly."**
The `codex app-server` subprocess hung or exited. Confirm you're signed in to the Codex CLI (`codex login` or equivalent) and that `codex app-server --stdio` runs without hanging when you invoke it directly from a terminal.

**A server-reported error message, or "Codex returned an unreadable usage response."**
The app-server's JSON protocol is reverse-engineered against the currently installed Codex CLI, not a stable public API — see [How it works](#how-it-works). A Codex CLI update can change field names or response shape out from under this app. If this starts happening after updating the Codex CLI, please [open an issue](../../issues) with the error text.

**Nothing shows in the menu bar at all**
Check Console.app or run `./script/build_and_run.sh --telemetry` to stream this app's own logs (subsystem `com.kelvin.codexbalance`) and see what it's doing on launch.

## Known limitations

- macOS only — no Windows or Linux support.
- Not sandboxed; App Store distribution is unproven for this architecture.
- Builds from source are ad-hoc signed; only the published release is Developer ID signed and notarized.
- No automatic updater, DMG installer, or crash reporting.
- Usage data comes from the Codex CLI's local app-server protocol, which is not a stable public API and can change between Codex releases.

## License

[MIT](LICENSE)
