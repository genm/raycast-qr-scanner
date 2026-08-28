# QR Scanner

Scan QR codes from Raycast on macOS and Windows, or from the macOS command line, using a camera, every visible display, or an image on the clipboard. QR recognition runs locally; no image or QR content is sent to an external service.

This project is pre-release software. The source and macOS CLI are ready for development and review; a Raycast Store release has not been published from this repository.

## Commands

- **Scan QR from Camera** opens a floating native camera preview. Detection freezes the matched frame, highlights each QR code for one second, then closes only the camera panel and shows the results in Raycast.
- **Scan QR from Screen** captures each connected display once and returns every QR code it finds.
- **Scan QR from Clipboard** reads copied images without requiring Screen Recording access.

Every result remains in Raycast until you explicitly open or copy it. This prevents an untrusted QR code from triggering a network request or launching another application without confirmation. Wi-Fi payloads show their parsed fields and provide separate copy actions. Duplicate payloads found on more than one display are shown once.

On macOS, the camera preview is a nonactivating native panel that stays visible without taking focus from Raycast. On Windows, the command opens Windows Camera and scans that app's visible preview until it finds a QR code or you close the Camera window. When scanning finishes, the scanner restores Raycast so the returned result view is visible.

## Command-line interface

Run the same scanners without Raycast:

```sh
swift run --package-path cli qr-scanner camera
swift run --package-path cli qr-scanner screen
swift run --package-path cli qr-scanner clipboard
```

Successful scans write `ScanResult[]` JSON to stdout. Failures write `{ "code", "message" }` JSON to stderr and exit nonzero. Add `--pretty` for formatted JSON or `--help` for usage. Scanning never opens a decoded URL automatically.

Camera and Screen Recording approval for the CLI is separate from Raycast. macOS can attribute it to the invoking terminal or executable it identifies, so follow the actual system prompt rather than granting additional Raycast access. See [CLI usage and contracts](docs/cli.md) for build instructions, output schemas, and exit statuses.

## Privacy and permissions

- On macOS, camera scans request Camera access for Raycast and process frames only in memory. On Windows, Windows Camera owns camera access and the extension scans its visible window.
- On macOS, screen scans check existing Screen Recording access for Raycast and capture each visible display once. If access is missing, Raycast fails fast and offers a System Settings action instead of waiting for the synchronous macOS permission request. On Windows, PowerShell and .NET capture each visible display once.
- Clipboard scans read image data from the current clipboard and do not request Camera or Screen Recording access.
- The extension has no telemetry, analytics, accounts, update checks, or extension-owned network service.
- Windows captures use a per-scan temporary directory inside Raycast's extension support directory and delete it on success or failure. QR content is retained only by Raycast's normal UI and clipboard behavior; the extension has no database or scan history.

Opening a recognized `http`, `https`, `mailto`, or `tel` payload is always a separate user action. Other URI schemes are displayed as text.

## Requirements

- macOS 14 or newer, or Windows 10/11 with Windows Camera installed. macOS screen scanning uses Apple's one-shot `SCScreenshotManager` API.
- Raycast with extension development support.
- Node.js 24.20.0 or newer for development.
- The npm version declared by `packageManager`. The repository pins it because its install-script allowlist is part of the dependency security policy.
- Xcode 16.3 or newer with Swift 6 support when building on macOS. The current checks also pass with Xcode 26.6; CI pins Xcode 16.4 for a stable hosted toolchain.

## Install for development

1. Install the declared Node.js, npm, and workflow-linting tools with `mise install`, then run `mise run setup`. Without mise, use Node.js 24.20.0 or newer and the npm version declared in `package.json`, then run `npm ci`.
2. In Raycast, run **Import Extension** and select this directory.
3. Run `mise run dev` (or `npm run dev`), or start development from Raycast's **Manage Extensions** command.

macOS attributes protected resources to Raycast. The first camera scan can show a system permission prompt. Screen scanning checks the existing Screen Recording grant and, when it is missing, immediately offers **Open System Settings**. Grant the permission to Raycast and restart Raycast when macOS requests it.

Use `npm install` only when intentionally changing dependencies and the lockfile. npm is configured to save exact versions, reject incompatible Node.js engines, and fail when a dependency introduces an unreviewed install script.

On macOS, protected resources are attributed to Raycast. The first camera or screen scan can show a system permission prompt. If access was denied, use the command's **Open System Settings** action, grant the permission to Raycast, and restart Raycast when macOS requests it. On Windows, accept any camera prompt shown by Windows Camera.

To uninstall a development copy, open **Manage Extensions** in Raycast, select **QR Scanner**, and choose **Uninstall Extension**. The extension stores no scan history. On macOS, Camera and Screen Recording permissions belong to Raycast and can be revoked separately in **System Settings > Privacy & Security**; on Windows, camera permission belongs to Windows Camera.

## Development checks

```sh
npm run check
```

The full check lints, runs TypeScript and Swift tests, builds the extension, and audits production dependencies at high severity. TypeScript tests write JSON to `test-results/vitest.json`; Swift tests write xUnit XML to `test-results/swift.xml`. Swift tests generate real QR images with Core Image and pass BGRA `CMSampleBuffer` frames through Vision. The matrix covers rotation, mirroring, apparent distance, QR-free frames, bounding boxes, frozen-frame generation, aspect-fill overlay coordinates, the nonactivating camera panel contract, and restoration of the presenting application.

Stop `npm run dev` and wait for its native build to finish before running `npm run build` or `npm run check`. Raycast debug and release builds share one Xcode build database; the prebuild guard fails with an actionable error instead of allowing concurrent builds to produce a misleading package-import failure.

## Architecture

The TypeScript entry points share result classification and Raycast UI in `src/`. `src/lib/windows.ts` owns the Windows adapter. `swift/ScannerKit` contains the reusable macOS libraries, while `swift/` and `cli/` are separate macOS host adapters:

- `QRScannerCore`: `ScanResult`, stable error codes, and one `VNDetectBarcodesRequest` implementation restricted to QR symbology.
- `QRScannerMac`: camera, screen, and clipboard capture plus the native camera panel.
- `cli/QRScannerCLI`: an independent package for command parsing, JSON stdout/stderr, and process exit status.
- `QRScannerNative`: `@raycast` entry points that return core results through the generated bridge.
- Windows adapter: PowerShell/.NET capture plus the local `jsQR` decoder for screen, clipboard, and Windows Camera preview images.

On macOS, camera capture uses `AVCaptureSession` and `AVCaptureVideoDataOutput` to produce BGRA `CMSampleBuffer` frames. Vision detects QR payloads and normalized bounds, and an `NSPanel` presents the live and one-second success states. Screen capture uses `SCShareableContent` and `SCScreenshotManager`; clipboard capture uses `NSPasteboard` and `NSImage`. On Windows, the adapter uses built-in PowerShell/.NET APIs to capture displays, clipboard images, and the visible Windows Camera window, then decodes PNG pixels locally.

The native boundary returns structured JSON through Raycast's official [`extensions-swift-tools`](https://github.com/raycast/extensions-swift-tools) bridge. Permission denial, restricted camera access, missing hardware, empty clipboard, image conversion failure, and no QR result remain distinct errors.

Detailed implementation and verification references:

- [Architecture and data flow](docs/architecture.md)
- [CLI usage and contracts](docs/cli.md)
- [Testing and acceptance](docs/testing.md)
- [Troubleshooting and privacy-safe diagnostics](docs/troubleshooting.md)

## Project policies

- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Governance](GOVERNANCE.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Third-party dependencies and assets](THIRD_PARTY_NOTICES.md)

The project is licensed under the [MIT License](LICENSE). Contributions are accepted under the same license.
