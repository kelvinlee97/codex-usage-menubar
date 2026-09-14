#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to the notarytool keychain profile for a public release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Codex Usage.app"
ZIP_PATH="$ROOT_DIR/dist/CodexUsage.zip"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-release.XXXXXX")"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-stage.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR" "$STAGE_DIR"' EXIT

# Stage the smoke-test install outside /Applications: the copy build_and_run.sh
# installs and launches is ad-hoc signed, and must not replace a real install.
CODEX_BALANCE_CONFIGURATION=release \
CODEX_BALANCE_UNIVERSAL=1 \
CODEX_BALANCE_INSTALL_DIR="$STAGE_DIR" \
  "$ROOT_DIR/script/build_and_run.sh" --verify
pkill -x CodexBalance >/dev/null 2>&1 || true

codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"
# The shipped binary must run on both architectures.
lipo -archs "$APP_BUNDLE/Contents/MacOS/CodexBalance"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

# Rebuild the distributable after stapling so the ticket is present in the ZIP.
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# Validate the exact app that recipients will extract from the final ZIP.
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
FINAL_APP="$VERIFY_DIR/$(basename "$APP_BUNDLE")"
xcrun stapler validate "$FINAL_APP"
spctl -a -vvv --type execute "$FINAL_APP"

echo "Public release verified: $ZIP_PATH"
