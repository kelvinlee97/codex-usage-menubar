# Privacy Policy

Codex Usage is a local macOS menu-bar utility. It does not collect, transmit, or store any personal data on remote servers.

## What the app does

- Runs `codex app-server --stdio` as a local subprocess to read your Codex usage limits and credit balance from your existing, already-authenticated Codex CLI session.
- Displays that data (five-hour window, seven-day window, reset times, credit balance) only in the menu-bar popover on your Mac.
- Stores your Launch at Login preference using Apple's `SMAppService`, which is local to your Mac.

## What the app does not do

- No analytics, telemetry, or crash reporting are collected or sent anywhere.
- No network requests are made by this app itself, other than opening your default browser to the Codex usage page when you click "Open Codex Usage."
- No data is written to disk beyond normal macOS application/login-item state; the app has no database, cache file, or account of its own.
- No data is shared with, or sent to, OpenAI, Anthropic, or any third party by this app.

## Third-party dependency

This app reads data from your local Codex CLI installation (`https://github.com/openai/codex`), which is a separate, independently maintained tool. Refer to OpenAI's own privacy policy and terms for what the Codex CLI itself collects or transmits as part of your normal Codex/ChatGPT usage.

## Disclosure

Codex Usage is an independent, unofficial utility and is not affiliated with, endorsed by, or supported by OpenAI.

## Contact

Questions about this policy can be directed to the maintainer via the project's GitHub repository.
