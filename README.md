# Codex Balance

A macOS menu-bar utility that shows your remaining [Codex CLI](https://github.com/openai/codex) usage at a glance: the current 5-hour window, the 7-day window, reset times, and your credit balance.

No Dock icon, no window to manage — it lives in the menu bar and polls the local Codex CLI every 30 seconds.

## Requirements

- macOS 14 (Sonoma) or later, Apple Silicon (arm64)
- [Swift](https://www.swift.org/install/) toolchain (Xcode or Command Line Tools)
- [Codex CLI](https://github.com/openai/codex) installed and authenticated (`codex login`)

## Install

Clone and run the build script, which compiles the app, stages it into a `.app` bundle, installs it to `/Applications`, and launches it:

```bash
git clone https://github.com/kelvinlee97/codex-usage-menubar.git
cd codex-usage-menubar
./script/build_and_run.sh
```

The app appears in your menu bar showing your remaining usage percentage. Click it to open the popover with full details, a link to the Codex usage page, and a Launch at Login toggle.

## Build from source

```bash
swift build
```

This compiles the executable without bundling it into a `.app` — useful for quick iteration or CI. Release build:

```bash
CODEX_BALANCE_CONFIGURATION=release ./script/build_and_run.sh
```

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
NOTARY_PROFILE="codex-balance-notary" \
./script/package_release.sh
```

Omit `NOTARY_PROFILE` to sign without notarizing; the output is `dist/CodexBalance.zip`.

## How it works

Codex Balance locates the Codex CLI on your machine, launches `codex app-server --stdio`, and talks to it over stdin/stdout to read your account's rate-limit and credit-balance data. This is not a public/stable API — it's the same interface the Codex CLI itself uses locally, so it may change between Codex CLI releases.

## Known limitations

See [handoff.md](handoff.md) for the full list, including:

- Apple Silicon (`arm64`) only for now.
- The menu-bar glyph currently borrows ChatGPT.app's bundled icon when installed, falling back to a system symbol otherwise — an original icon is planned before any wider release.
- Not sandboxed; App Store distribution is unproven for this architecture.

## License

No license file yet — all rights reserved by the author until one is added.
