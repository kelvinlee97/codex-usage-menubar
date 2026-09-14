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
- [ ] Add a CI workflow that builds and runs the self-check on push. The two
      merged workflows are Claude-triggered only; nothing verifies a build today.
      (The self-check is now hermetic, so a runner without Codex installed works.)
- [ ] Read `LoginItemManager.requiresApproval` into `@State` in `onAppear`
      instead of calling it during `body` — it is not observable, so the
      "Open Login Items Settings" button lingers after the user approves.
- [ ] Intel verification. The binary is universal and the x86_64 slice builds and
      links, but it has never been *run* on an Intel Mac.
- [ ] Test on a machine with no Codex CLI installed — confirm the popover's error
      state is understandable rather than a blank or cryptic panel.
- [ ] Refresh when a usage window resets. After `resetsAt` passes the popover
      shows "Resetting…" for up to `PollSchedule.successInterval` (120s), which is
      exactly when people look at it.
- [ ] Decide on an update story. There is no Sparkle/auto-updater, so v1.0.1
      means users re-downloading by hand with no prompt.
- [ ] Add a "Troubleshooting" section to the README (CLI not found, not logged in,
      app-server protocol changed under a new Codex CLI release).
- [ ] Consider a DMG instead of a zip for a conventional drag-to-Applications
      install.
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
