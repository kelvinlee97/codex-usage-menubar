#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to the notarytool keychain profile for a public release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Codex Balance.app"
ZIP_PATH="$ROOT_DIR/dist/CodexUsage.zip"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-release.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT

CODEX_BALANCE_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --verify
codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
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
