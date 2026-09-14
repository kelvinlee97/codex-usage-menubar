# Codex Balance — Engineering Handoff

Last updated: 2026-09-14  
Workspace: `/Users/kelvin/Documents/Github/Codex-dashboard`

## Product summary

Codex Balance is a macOS 14+ menu-bar utility that displays the remaining percentage for the user's five-hour Codex usage window. Opening the menu shows the five-hour and seven-day limits, reset times, credit balance, refresh/error state, Launch at Login, a link to the official usage page, and Quit.

The app is intentionally menu-bar-only (`LSUIElement = true`) and does not display a Dock icon or normal application window.

## Current status

- Core usage retrieval works against the locally installed Codex `app-server` protocol.
- The menu-bar label shows a ChatGPT-style template icon and the five-hour remaining percentage.
- Manual refresh and 30-second polling work.
- Stale values remain visible when a later refresh fails.
- Codex CLI discovery supports the ChatGPT bundle, `CODEX_CLI_PATH`, the process `PATH`, Homebrew paths, and common npm/version-manager locations.
- App-server response reads have a 10-second timeout and terminate the subprocess after failure.
- Launch at Login uses `SMAppService.mainApp`.
- Finder displays the app as **Codex Balance** with a complete multi-resolution application icon.
- Local release QA passes.

## Repository layout

```text
Package.swift
Assets/
  AppIcon.png              Original 1254px generated artwork
  AppIcon.icns             Packaged 16–1024px macOS icon
Sources/CodexBalance/
  App/CodexBalanceApp.swift
  Models/UsageSnapshot.swift
  Services/CodexExecutableResolver.swift
  Services/CodexUsageClient.swift
  Stores/UsageStore.swift
  Support/LoginItemManager.swift
  Support/SelfCheck.swift
  Views/UsagePopoverView.swift
script/
  build_and_run.sh         Build, install, launch, debug, and log entrypoint
  qa.sh                    Repeatable local release QA
  package_release.sh       Developer ID signing and optional notarization
.codex/environments/environment.toml
design-qa.md
```

## Build and run

The project is a Swift Package Manager executable that is staged into a macOS `.app` bundle by the project script.

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

The installed app is:

```text
/Applications/Codex Balance.app
```

The generated local bundle is:

```text
dist/Codex Balance.app
```

## QA

Run the complete local gate:

```bash
./script/qa.sh
```

It verifies:

1. Parser, percentage calculation, executable resolution, timeout, and short-read self-checks.
2. Release compilation.
3. Bundle executable and application icon.
4. `CFBundleIconFile` and `CFBundleDisplayName` metadata.
5. Code-signature structural integrity.
6. Application launch.
7. A successful live Codex usage refresh in Unified Logging.

Latest result:

```text
QA passed: release build, self-check, bundle metadata, icon, signature, launch, and live usage refresh
```

Finder list view and Quick Look were also inspected through Computer Use. The application name and icon rendered correctly. See `design-qa.md` for the visual QA record.

## Usage data flow

`UsageStore` polls `CodexUsageClient` every 30 seconds. The client resolves a Codex executable and starts:

```text
codex app-server --stdio
```

It sends JSONL requests for:

```text
initialize
account/rateLimits/read
```

The response is decoded from `rateLimitsByLimitId.codex`, falling back to `rateLimits`. The menu bar uses the primary/five-hour window; the popover also displays the secondary/seven-day window and credits.

Important: this app-server method is not currently treated as a stable public product API. Protocol changes in future Codex releases are a material maintenance risk. Keep parser failures user-visible and test against new Codex releases before shipping updates.

## Icon behavior

The Finder/application icon is original artwork stored in `Assets` and bundled through `CFBundleIconFile`.

The menu-bar icon currently loads:

```text
/Applications/ChatGPT.app/Contents/Resources/chatgptTemplate@2x.png
```

at its native 18pt Retina size. If ChatGPT is not installed there, it falls back to the SF Symbol `sparkles`.

Before commercial release, replace the ChatGPT menu-bar mark with an original bundled monochrome template asset. Depending on another application's private resource path is fragile, and using the ChatGPT mark may create trademark or implied-endorsement risk.

## Signing and release state

The current installed artifact is:

- Architecture: `arm64` only.
- Signing: ad-hoc.
- Hardened Runtime: enabled.
- Team identifier: none.
- Notarization: not performed.

This is suitable for local development and QA, but not ready for public download.

There are no valid code-signing identities installed on the current Mac. The machine also has Command Line Tools rather than the full Xcode installation. A Universal 2 build attempt was blocked because SwiftPM's multi-architecture path requires Xcode's `xcbuild` support.

## Recommended distribution route

Direct website distribution is the best initial route. The current design launches a user-installed Codex CLI and reads its authenticated local environment; Mac App Store sandboxing is likely to block this architecture.

For direct distribution:

1. Join the Apple Developer Program.
2. Install the current full Xcode release and select it with `xcode-select`.
3. Create and install a `Developer ID Application` certificate.
4. Decide whether to support Apple Silicon only or compile Universal 2 for Intel Macs.
5. Store notarization credentials in a Keychain profile.
6. Sign with Hardened Runtime and a secure timestamp.
7. Submit the ZIP to Apple's notary service and staple the ticket.
8. Test the downloaded artifact on a clean Mac account or separate Mac.
9. Publish the signed/notarized ZIP or DMG from the product website.

The release script expects:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="codex-balance-notary" \
./script/package_release.sh
```

Without `NOTARY_PROFILE`, the script signs and creates `dist/CodexBalance.zip` but does not notarize it.

## Mac App Store considerations

Mac App Store submission requires an Apple Developer Program membership and App Sandbox. Selling also requires the Paid Apps Agreement plus banking and tax information.

The current subprocess architecture should be considered incompatible until proven otherwise under App Sandbox. Do not add sandbox entitlements and submit blindly. First prototype whether a sandboxed build can legitimately discover, launch, and communicate with the user's Codex CLI; otherwise redesign around a supported API or approved helper architecture.

## Commercial and brand risks

- `Codex Balance` contains an OpenAI product name. Confirm that the final product name complies with OpenAI's current brand guidelines before publishing.
- Do not imply that the app is built, supported, certified, or endorsed by OpenAI.
- Replace the ChatGPT menu-bar icon before sale unless explicit permission covers that use.
- Clearly disclose that Codex/ChatGPT installation, authentication, and an eligible user plan may be required.
- Add a privacy policy even if no analytics are collected; state what stays local and whether any diagnostics leave the Mac.
- Add Terms of Sale, refund handling, support contact details, and license activation only when the chosen sales channel requires them.

Safer neutral product-name directions include `QuotaBar`, `Usage Meter`, or `Token Balance`, subject to normal trademark checks. (`QuotaBar` was tried on 2026-09-14 and reverted at the user's request — the product is intentionally named after Codex.)

## Highest-priority next steps

1. Choose the final commercial name and replace the menu-bar ChatGPT mark with an original bundled template icon.
2. Install full Xcode and produce/test a Universal 2 release, or explicitly document Apple Silicon-only support.
3. Enroll in the Apple Developer Program and install a Developer ID certificate.
4. Run the signing/notarization script and test Gatekeeper acceptance on a clean machine.
5. Add first-run prerequisite guidance for missing Codex CLI, signed-out accounts, and unsupported Codex versions.
6. Add update delivery, crash reporting/privacy decisions, a support URL, and a public privacy policy.
7. Beta test across supported macOS versions, display scales, light/dark appearances, offline state, expired sessions, missing CLI, hung CLI, and changed server responses.

## Known limitations

- `arm64` only today.
- No Developer ID signature or notarization.
- No automatic updater.
- No installer or DMG.
- No license/payment integration.
- No crash reporting or opt-in diagnostics.
- No dedicated onboarding or prerequisite checker.
- Menu-bar icon uses a ChatGPT application resource when available.
- Usage retrieval depends on a local, potentially changing Codex app-server protocol.

## Git state

At handoff time, the repository has no committed project files; the implementation is present as untracked files. Review the complete tree, confirm `.gitignore`, then create the initial commit before beginning release work. Do not assume there is a rollback point until that commit exists.
