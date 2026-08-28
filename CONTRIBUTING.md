# Contributing

Thanks for helping improve QR Scanner. Small, focused fixes and documentation improvements are welcome. Open an issue before starting a large behavior or architecture change so the design can be agreed before implementation.

## Development setup

You need macOS 14 or newer, Raycast with extension development support, Node.js 24.20.0 or newer, and Xcode 16.3 or newer with Swift 6 support.

```sh
mise install
mise run setup
mise run check
```

The mise configuration reads the Node.js version from `.node-version`, pins the same npm version declared by `packageManager`, and provides the repository's Actionlint and ShellCheck versions. The repository check fails if the Node.js or npm declarations drift, and `mise run check` validates GitHub Actions before running the npm checks. If mise is unavailable, use Node.js 24.20.0 or newer with the npm version declared in `package.json`, then run `npm ci` and `npm run check` directly.

Use `npm install` only when intentionally changing dependencies and committing the corresponding `package-lock.json` update. Exact dependency versions are saved by default. Install scripts fail closed unless their reviewed, version-pinned package appears in `allowScripts` in `package.json`.

Import the repository with Raycast's **Import Extension** command and use `npm run dev` for an interactive test. Camera and screen flows require their corresponding macOS permissions; clipboard scanning does not.

Stop `npm run dev` and wait for its native `xcodebuild` process to finish before running `npm run check`; debug and release builds cannot share the same Swift build database concurrently.

## What to verify

- Add or update an automated test for behavior changes.
- Exercise the normal path and a realistic error or empty path.
- Run `npm run check` before opening a pull request.
- For UI changes, test the affected command in Raycast and attach screenshots that contain no private QR content, personal data, or unrelated desktop content.
- Do not weaken types, skip checks, or replace real failures with synthetic success.

Use [docs/testing.md](docs/testing.md) for the automated matrix and manual camera acceptance checklist. Camera changes must preserve the nonactivating panel behavior, the one-second success state, result delivery back to Raycast, and alignment between the frozen frame and Vision bounding boxes.

The test suite emits machine-readable results under `test-results/`. CI uploads those files only when a check fails.

## Pull requests

Keep each pull request coherent and explain the user-visible result, verification performed, and any permissions or privacy impact. Never include credentials, private QR payloads, customer data, or screenshots of an unredacted desktop.

Contributions are licensed under the project's MIT License (inbound equals outbound). By submitting a contribution, you represent that you have the right to provide it under those terms. Disclose materially AI-assisted code or assets in the pull request and review their provenance, security, and license compatibility as carefully as any other contribution.

Security vulnerabilities must follow [SECURITY.md](SECURITY.md), not a public issue. Community behavior is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

Implementation boundaries and native/TypeScript ownership are documented in [docs/architecture.md](docs/architecture.md). Reproduction and sanitized logging steps are in [docs/troubleshooting.md](docs/troubleshooting.md).
