# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

Codex Usage is a macOS 14+ menu-bar-only utility (`LSUIElement = true`, no Dock icon) that shows the remaining percentage of the user's five-hour Codex usage window. The popover also shows the seven-day window, reset times, credit balance, refresh/error state, Launch at Login, and a link to the usage page.

It is a Swift Package Manager executable staged into `/Applications/Codex Balance.app` by shell scripts (there is no Xcode project). Its stable bundle id is `com.kelvin.codexbalance`; its user-facing display name remains Codex Usage.

## Commands

Build, install to `/Applications`, and launch:
```bash
./script/build_and_run.sh
```
Modes: `--verify` (launch and confirm the process exists), `--logs` (stream all app logs), `--telemetry` (stream only `subsystem == "com.kelvin.codexbalance"` logs), `--debug` (launch under `lldb`). Debug build by default; set `CODEX_BALANCE_CONFIGURATION=release` to build release.

Run the full local QA gate (release build, in-process self-check, bundle/icon/signature checks, launch, and a live Codex usage refresh observed via Unified Logging):
```bash
./script/qa.sh
```

Run just the in-process self-check (parser, percentage math, executable resolution, pipe timeout/short-read handling) without building a bundle:
```bash
CODEX_BALANCE_SELF_CHECK=1 swift run CodexBalance
```
This is the project's only test harness — there is no XCTest target (`Tests/CodexBalanceTests` is empty). New self-check assertions go in `Sources/CodexBalance/Support/SelfCheck.swift`; it runs when that env var is set, asserts with `precondition`, and calls `exit()`.

Package a signed and notarized public release zip:
```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="codex-usage-notary" \
./script/package_release.sh
```
Both variables are mandatory. The script signs, notarizes, staples before rebuilding the final `dist/CodexUsage.zip`, then validates the extracted app with `stapler` and `spctl`.

Plain compile/typecheck without the bundling steps: `swift build`.

## Architecture

Data flow: `UsageStore` (`@MainActor ObservableObject`) polls `CodexUsageClient` every 30s and exposes `snapshot`/`errorMessage`/`isRefreshing` to SwiftUI. `CodexBalanceApp` is a `MenuBarExtra` scene whose label reads `store.menuBarText` and whose window content is `UsagePopoverView`.

`CodexUsageClient` (an `actor`) is the core integration point: it locates a Codex CLI via `CodexExecutableResolver`, launches `codex app-server --stdio` as a subprocess, and speaks a line-delimited JSON-RPC-like protocol over stdin/stdout (`initialize`, then `account/rateLimits/read`). Reads use `poll()`/`read()` on the raw file descriptor with a hard 10s timeout (`waitUntilReadable`/`readAvailable`); any error tears down and restarts the subprocess on the next call. Response parsing (`decodeSnapshot`) reads `rateLimitsByLimitId.codex`, falling back to top-level `rateLimits`, into `UsageSnapshot`/`UsageWindow` (`Models/UsageSnapshot.swift`).

**This app-server JSON protocol is not a stable/public Codex API** — it was reverse-engineered against the locally installed Codex CLI. Protocol or field-name changes in future Codex releases are the primary maintenance risk; when touching `CodexUsageClient`, keep parse failures surfaced to the user (via `errorMessage`) rather than silently swallowed, and re-run `./script/qa.sh` against a current Codex install before shipping.

`CodexExecutableResolver` searches, in order: `CODEX_CLI_PATH` env var, the bundled ChatGPT.app resource path, every directory in `PATH`, then Homebrew/npm/version-manager fallback paths (`/opt/homebrew/bin`, `~/.volta/bin`, `~/.asdf/shims`, etc.).

The menu-bar glyph uses the built-in monochrome SF Symbol `gauge.with.dots.needle.67percent`.

`LoginItemManager` wraps `SMAppService.mainApp` for the user-controlled Launch-at-Login toggle.

## Repository layout

```
Package.swift
Assets/                          AppIcon source art + packaged .icns
Sources/CodexBalance/
  App/CodexBalanceApp.swift      MenuBarExtra scene and menu-bar icon
  Models/UsageSnapshot.swift     UsageSnapshot / UsageWindow value types
  Services/CodexExecutableResolver.swift
  Services/CodexUsageClient.swift  app-server subprocess + JSON-RPC client
  Stores/UsageStore.swift        polling + published state for the UI
  Support/LoginItemManager.swift
  Support/SelfCheck.swift        CODEX_BALANCE_SELF_CHECK harness
  Views/UsagePopoverView.swift
script/
  build_and_run.sh               build, bundle, install, launch/debug/logs
  qa.sh                          full local release QA gate
  package_release.sh             Mandatory Developer ID signing + notarization
handoff.md                       engineering handoff: status, risks, next steps
design-qa.md                     visual QA record (Finder/Quick Look icon checks)
```

## Known constraints (see `handoff.md` for full detail)

- `arm64`-only build today; public release packaging requires Developer ID signing and notarization credentials.
- Sandboxing (Mac App Store) is unproven for this subprocess-launching architecture — do not add sandbox entitlements without first validating that a sandboxed build can discover/launch/talk to the user's Codex CLI.
- The product includes an explicit unofficial/non-affiliation disclosure.
