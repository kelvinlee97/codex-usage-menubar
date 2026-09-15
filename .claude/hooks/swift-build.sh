#!/bin/bash
# PostToolUse hook: typecheck (and self-check) after editing Swift sources.
# Reads the tool payload on stdin; exits 2 with stderr to feed failures back to Claude.
set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)

case "$file" in
  *Sources/CodexBalance/*.swift) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0

if ! out=$(swift build 2>&1); then
  echo "swift build failed after editing $file:" >&2
  printf '%s\n' "$out" | tail -30 >&2
  exit 2
fi

# Services/ and Support/ carry the logic the self-check covers (parser, percentage
# math, executable resolution, pipe timeouts), so run it there.
case "$file" in
  *Sources/CodexBalance/Services/*|*Sources/CodexBalance/Support/*)
    if ! out=$(CODEX_BALANCE_SELF_CHECK=1 swift run CodexBalance 2>&1); then
      echo "Self-check failed after editing $file:" >&2
      printf '%s\n' "$out" | tail -30 >&2
      exit 2
    fi
    ;;
esac

exit 0
