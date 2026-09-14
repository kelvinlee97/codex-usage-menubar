# TODO — v1.0.0 release

Everything here is pending. Items in "Release day" are blocking; the rest are not.

## Release day (blocking)

- [ ] **Set up signing credentials.** A Developer ID Application certificate in the
      login keychain, and a notarytool keychain profile:
      `xcrun notarytool store-credentials "codex-usage-notary" --apple-id <id> --team-id <TEAMID> --password <app-specific-password>`
- [ ] **Run the release script end-to-end.** This path has never been executed —
      signing, notarization, stapling, and the `spctl` check are untested as written.
      Budget time for a first-run failure.
      ```bash
      DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
      NOTARY_PROFILE="codex-usage-notary" \
      ./script/package_release.sh
      ```
- [ ] **Clean-machine install test.** Extract `dist/CodexUsage.zip` on another Mac or
      a fresh user account, double-click, and confirm: no Gatekeeper prompt, menu-bar
      percentage appears, Launch at Login toggle sticks. Quarantine only applies to a
      real browser download, so download the published asset rather than copying the
      local file.
- [ ] **Tag and publish.** `git tag v1.0.0 && git push --tags`, create the GitHub
      release, attach `dist/CodexUsage.zip`. The README already links to
      `/releases/latest`, so the download goes live on publish.
- [ ] **Verify the published link** by downloading the asset from the release page.

## Nice to have (not blocking v1.0.0)

- [ ] Intel verification. The binary is universal and the x86_64 slice builds and
      links, but it has never been *run* on an Intel Mac.
- [ ] Test on a machine with no Codex CLI installed — confirm the error state in the
      popover is understandable, not a blank or cryptic panel.
- [ ] Decide on an update story. There's no Sparkle/auto-updater, so v1.0.1 means
      users re-downloading manually with no prompt.
- [ ] Add a short "Troubleshooting" section to the README (CLI not found, not logged
      in, app-server protocol changed under a new Codex CLI release).
- [ ] Consider a DMG instead of a zip for a more conventional drag-to-Applications
      install.
- [ ] Re-run `./script/qa.sh` against a freshly updated Codex CLI before each release
      — the app-server JSON protocol is reverse-engineered and is the main
      breakage risk.

## Known gaps carried into v1.0.0

- Not sandboxed; Mac App Store distribution unproven for this subprocess architecture.
- No crash reporting or analytics (by design — see PRIVACY.md).
- Usage data depends on the Codex CLI's non-public app-server protocol.
