#!/usr/bin/env bash
# Local release gate: builds, self-checks, and proves the installed bundle
# actually launches and reads live usage from the Codex CLI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${CODEX_BALANCE_INSTALL_DIR:-/Applications}"
UNIVERSAL="${CODEX_BALANCE_UNIVERSAL:-1}"
APP_BUNDLE="$INSTALL_DIR/Codex Usage.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

fail() { echo "QA failed: $*" >&2; exit 1; }

require() { # require <what> <command...>
  local what="$1"; shift
  "$@" >/dev/null 2>&1 || fail "$what"
}

expect() { # expect <what> <actual> <wanted>
  [[ "$2" == "$3" ]] || fail "$1 — expected \"$3\", got \"$2\""
}

SWIFT_RUN_ARGS=(--package-path "$ROOT_DIR")
if [[ "${CODEX_BALANCE_SWIFTPM_DISABLE_SANDBOX:-0}" == "1" ]]; then
  SWIFT_RUN_ARGS+=(--disable-sandbox)
fi

CODEX_BALANCE_SELF_CHECK=1 swift run "${SWIFT_RUN_ARGS[@]}" CodexBalance
CODEX_BALANCE_UNIVERSAL="$UNIVERSAL" \
CODEX_BALANCE_CONFIGURATION=release \
  "$ROOT_DIR/script/build_and_run.sh" --verify

require "the app binary is missing or not executable" \
  test -x "$APP_BUNDLE/Contents/MacOS/CodexBalance"
require "the app icon is missing from the bundle" \
  test -s "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
expect "CFBundleIconFile" "$(plutil -extract CFBundleIconFile raw "$INFO_PLIST")" "AppIcon"
expect "CFBundleDisplayName" "$(plutil -extract CFBundleDisplayName raw "$INFO_PLIST")" "Codex Usage"
require "the code signature is invalid" \
  codesign --verify --strict "$APP_BUNDLE"

archs="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/CodexBalance")"
if [[ "$UNIVERSAL" == "1" && ( "$archs" != *arm64* || "$archs" != *x86_64* ) ]]; then
  fail "expected a universal binary, got: $archs"
fi
echo "architectures: $archs"

app_pid="$(pgrep -x CodexBalance | head -1)"
[[ -n "$app_pid" ]] || fail "the app is not running after launch"

# The refresh is asynchronous: poll the app's own log until it reports success.
for _ in {1..10}; do
  if /usr/bin/log show --last 1m --info \
      --predicate "processIdentifier == $app_pid AND eventMessage CONTAINS 'Codex usage refreshed successfully'" \
      | grep -q refreshed; then
    echo "QA passed: release build, self-check, bundle metadata, icon, signature, launch, and live usage refresh"
    exit 0
  fi
  sleep 1
done

fail "live usage refresh was not observed"
