# TODO — v1.0.0 release

Everything unchecked is pending. "Release day" is blocking; the rest is not.

Status: the code is ready and `./script/qa.sh` passes (release build, self-check,
universal binary, signature, live usage refresh). The only thing standing between
here and a published release is Apple credentials — verified absent on this machine:
`security find-identity -v -p codesigning` returns 0 identities, and no
`codex-usage-notary` keychain profile exists.

## Release day (blocking)

Steps 1–4 need an Apple account in a browser and must be done by hand.

- [ ] **1. Confirm a paid Apple Developer account** ($99/yr). Everything below
      depends on it; there is no way to get a Developer ID certificate or to
      notarize without one. No account → fall back to source-only distribution
      (drop the zip, document `./script/build_and_run.sh` as the install path,
      and remove the Download section's Gatekeeper claim from README).
- [ ] **2. Create the Developer ID Application certificate.** Full Xcode is not
      installed here, so use the web flow: generate a CSR in Keychain Access
      (Certificate Assistant → Request a Certificate from a Certificate Authority
      → "Saved to disk"), upload it at developer.apple.com/account → Certificates
      → + → *Developer ID Application*, download the `.cer`, double-click to
      install. Verify with `security find-identity -v -p codesigning`; the exact
      string it prints is `DEVELOPER_ID_APPLICATION`.
- [ ] **3. Create an app-specific password** at appleid.apple.com → Sign-In and
      Security → App-Specific Passwords. Not the Apple ID password itself.
- [ ] **4. Store the notary profile.**
      ```bash
      xcrun notarytool store-credentials "codex-usage-notary" \
        --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
      ```
- [ ] **5. Run the release script end-to-end.** This path has never executed —
      signing, notarization, stapling and the `spctl` check are all untested as
      written. Budget time for a first-run failure.
      ```bash
      DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
      NOTARY_PROFILE="codex-usage-notary" \
      ./script/package_release.sh
      ```
- [ ] **6. Tag and publish.** `git tag v1.0.0 && git push --tags`, create the
      GitHub release, attach `dist/CodexUsageMenubar.zip`. README already links to
      `/releases/latest`, so the download goes live the moment you publish.
- [ ] **7. Clean-machine install test.** Download the published asset in a browser
      (not a local file copy — quarantine only attaches to a real download), on
      another Mac or a fresh user account. Confirm: no Gatekeeper prompt, the
      menu bar reads `Codex <percent>`, Launch at Login sticks across a reboot.

## Nice to have (not blocking v1.0.0)

- [ ] Move `Sources/CodexBalance/Support/SelfCheck.swift` (133 lines) into a
      swift-testing target. Gets the test harness out of the shipped binary and
      replaces `Precondition failed: line 51` with named failures. Deliberately
      deferred until after v1.0.0 — it touches the code path being shipped.
- [x] Add a CI workflow that builds and runs the self-check on push.
      `.github/workflows/build.yml`, verified green against a real PR.
- [x] Read `LoginItemManager.requiresApproval` into `@State`, refreshed in
      `onAppear` and after the toggle's `setEnabled` call — the settings
      button no longer lingers after approval.
- [ ] Intel verification. The binary is universal and the x86_64 slice builds and
      links, but it has never been *run* on an Intel Mac. Needs physical Intel
      hardware; not something a dev-machine session can do.
- [x] Test on a machine with no Codex CLI installed — could not fully simulate
      (the resolver's hardcoded fallback paths found the real install on this
      machine regardless of `PATH`/`CODEX_CLI_PATH`), but confirmed by code
      inspection that `ClientError.codexNotFound`'s message is specific and
      actionable, not blank or cryptic, and added a self-check regression guard
      on the exact string.
- [x] Refresh when a usage window resets. `PollSchedule.interval(consecutiveFailures:snapshot:now:)`
      shortens the next poll to 5s once a window's `resetsAt` has passed (only on
      a successful poll; failure backoff is unaffected), instead of waiting the
      full 120s `successInterval`.
- [ ] Decide on an update story. There is no Sparkle/auto-updater, so v1.0.1
      means users re-downloading by hand with no prompt. A real decision, not a
      bug fix — left for you.
- [x] Add a "Troubleshooting" section to the README (CLI not found, service
      hung/stopped, protocol drift, nothing in the menu bar).
- [ ] Consider a DMG instead of a zip for a conventional drag-to-Applications
      install. A packaging preference, and testing it end-to-end needs
      notarization credentials anyway — left for the release-day pass.
- [ ] Re-run `./script/qa.sh` against a freshly updated Codex CLI before each
      release — the app-server JSON protocol is reverse-engineered and is the
      main breakage risk.

## Known gaps carried into v1.0.0

- Not sandboxed; Mac App Store distribution unproven for this subprocess architecture.
- No crash reporting or analytics (by design — see PRIVACY.md).
- Usage data depends on the Codex CLI's non-public app-server protocol.
- `MenuBarExtra` renders only the first sibling of a multi-view label, so the menu
  bar label must stay a single `Text` — see the comment in `CodexBalanceApp.swift`.

## Done this session

- Bundle renamed to `Codex Usage Menubar.app`; bundle id `com.kelvin.codexbalance` unchanged.
- Universal release binary (arm64 + x86_64) via per-arch builds joined with `lipo`.
- `package_release.sh` no longer replaces `/Applications` with an ad-hoc-signed copy.
- SIGPIPE ignored, so a dead Codex subprocess can no longer kill the app silently.
- Self-check made hermetic (no Codex CLI required) and given a broken-pipe guard.
- Menu bar shows the `Codex <percent>` wordmark instead of the gauge SF Symbol.
- README download section, corrected architecture claims, deduped limitations.
- Removed `handoff.md` and `design-qa.md`; `qa.sh` now names the check that failed.
