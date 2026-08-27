# Contributing

Thanks for helping improve QR Scanner. Small, focused fixes and documentation improvements are welcome. Open an issue before starting a large behavior or architecture change so the design can be agreed before implementation.

## Development setup

You need macOS 14 or newer, Raycast with extension development support, Node.js 22.22.2 or newer, and Xcode 16.3 or newer with Swift 6 support.

```sh
npm install
npm run check
```

Import the repository with Raycast's **Import Extension** command and use `npm run dev` for an interactive test. Camera and screen flows require their corresponding macOS permissions; clipboard scanning does not.

Stop `npm run dev` and wait for its native `xcodebuild` process to finish before running `npm run check`; debug and release builds cannot share the same Swift build database concurrently.

## What to verify

- Add or update an automated test for behavior changes.
- Exercise the normal path and a realistic error or empty path.
- Run `npm run check` before opening a pull request.
- For UI changes, test the affected command in Raycast and attach screenshots that contain no private QR content, personal data, or unrelated desktop content.
- Do not weaken types, skip checks, or replace real failures with synthetic success.

The test suite emits machine-readable results under `test-results/`. CI uploads those files only when a check fails.

## Pull requests

Keep each pull request coherent and explain the user-visible result, verification performed, and any permissions or privacy impact. Never include credentials, private QR payloads, customer data, or screenshots of an unredacted desktop.

Contributions are licensed under the project's MIT License (inbound equals outbound). By submitting a contribution, you represent that you have the right to provide it under those terms. Disclose materially AI-assisted code or assets in the pull request and review their provenance, security, and license compatibility as carefully as any other contribution.

Security vulnerabilities must follow [SECURITY.md](SECURITY.md), not a public issue. Community behavior is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
