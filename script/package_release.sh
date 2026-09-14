#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application certificate name}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Codex Balance.app"
ZIP_PATH="$ROOT_DIR/dist/CodexBalance.zip"

CODEX_BALANCE_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --verify
codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
fi

echo "$ZIP_PATH"
