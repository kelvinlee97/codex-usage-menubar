#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${CODEX_BALANCE_INSTALL_DIR:-/Applications}"
APP_BUNDLE="$INSTALL_DIR/Codex Usage.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
SWIFT_RUN_ARGS=(--package-path "$ROOT_DIR")
if [[ "${CODEX_BALANCE_SWIFTPM_DISABLE_SANDBOX:-0}" == "1" ]]; then
  SWIFT_RUN_ARGS+=(--disable-sandbox)
fi

CODEX_BALANCE_SELF_CHECK=1 swift run "${SWIFT_RUN_ARGS[@]}" CodexBalance
CODEX_BALANCE_UNIVERSAL="${CODEX_BALANCE_UNIVERSAL:-1}" \
CODEX_BALANCE_CONFIGURATION=release \
  "$ROOT_DIR/script/build_and_run.sh" --verify

test -x "$APP_BUNDLE/Contents/MacOS/CodexBalance"
test -s "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
test "$(plutil -extract CFBundleIconFile raw "$INFO_PLIST")" = "AppIcon"
test "$(plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" = "Codex Usage"
codesign --verify --strict --verbose=2 "$APP_BUNDLE"
archs="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/CodexBalance")"
if [[ "${CODEX_BALANCE_UNIVERSAL:-1}" == "1" ]]; then
  [[ "$archs" == *arm64* && "$archs" == *x86_64* ]] || {
    echo "QA failed: expected a universal binary, got: $archs" >&2
    exit 1
  }
fi
echo "architectures: $archs"

app_pid="$(pgrep -x CodexBalance | head -1)"
for _ in {1..10}; do
  if /usr/bin/log show --last 1m --info --predicate "processIdentifier == $app_pid AND eventMessage CONTAINS 'Codex usage refreshed successfully'" | grep -q refreshed; then
    echo "QA passed: release build, self-check, bundle metadata, icon, signature, launch, and live usage refresh"
    exit 0
  fi
  sleep 1
done

echo "QA failed: live usage refresh was not observed" >&2
exit 1
