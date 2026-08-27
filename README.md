# QR Scanner for Raycast

Scan QR codes from a Mac camera, every visible display, or an image on the clipboard. QR recognition runs locally with Apple's AVFoundation, ScreenCaptureKit, and Vision frameworks; no image or QR content is sent to an external service.

This project is pre-release software intended for macOS Raycast users. The source is ready for development and review; a Raycast Store release has not been published from this repository.

## Commands

- **Scan QR from Camera** opens a floating native camera preview and closes it when a QR code is detected.
- **Scan QR from Screen** captures each connected display once and returns every QR code it finds.
- **Scan QR from Clipboard** reads copied images without requiring Screen Recording access.

Every result remains in Raycast until you explicitly open or copy it. This prevents an untrusted QR code from triggering a network request or launching another application without confirmation. Wi-Fi payloads show their parsed fields and provide separate copy actions. Duplicate payloads found on more than one display are shown once.

## Privacy and permissions

- Camera scans request macOS Camera access for Raycast and process frames only in memory.
- Screen scans request macOS Screen Recording access for Raycast and capture each visible display once.
- Clipboard scans read image data from the current clipboard and do not request Camera or Screen Recording access.
- The extension has no telemetry, analytics, accounts, update checks, or extension-owned network service.
- QR content is retained only by Raycast's normal UI and clipboard behavior. This extension does not create its own files or database.

Opening a recognized `http`, `https`, `mailto`, or `tel` payload is always a separate user action. Other URI schemes are displayed as text.

## Requirements

- macOS 14 or newer. Screen scanning uses Apple's one-shot `SCScreenshotManager` API.
- Raycast with extension development support.
- Node.js 22.22.2 or newer for development.
- Xcode 16.3 or newer with Swift 6 support for the Raycast Swift bridge. The current checks also pass with Xcode 26.6; CI pins Xcode 16.4 for a stable hosted toolchain.

## Install for development

1. Run `npm install` in this directory.
2. In Raycast, run **Import Extension** and select this directory.
3. Run `npm run dev`, or start development from Raycast's **Manage Extensions** command.

macOS attributes protected resources to Raycast. The first camera or screen scan can show a system permission prompt. If access was denied, use the command's **Open System Settings** action, grant the permission to Raycast, and restart Raycast when macOS requests it.

To uninstall a development copy, open **Manage Extensions** in Raycast, select **QR Scanner**, and choose **Uninstall Extension**. The extension stores no application data. Camera and Screen Recording permissions belong to Raycast and can be revoked separately in **System Settings > Privacy & Security**.

## Development checks

```sh
npm run check
```

The full check lints, runs TypeScript and Swift tests, builds the extension, and audits production dependencies at high severity. TypeScript tests write JSON to `test-results/vitest.json`; Swift tests write xUnit XML to `test-results/swift.xml`. Swift tests generate a real QR image with Core Image and verify that Vision decodes it, plus a QR-free image for the adverse path.

Stop `npm run dev` and wait for its native build to finish before running `npm run build` or `npm run check`. Raycast debug and release builds share one Xcode build database; the prebuild guard fails with an actionable error instead of allowing concurrent builds to produce a misleading package-import failure.

## Architecture

The TypeScript entry points share result classification and Raycast UI in `src/`. The Swift executable package in `swift/` owns protected macOS APIs:

- Camera: `AVCaptureSession` and `AVCaptureMetadataOutput`, with an `NSPanel` preview.
- Screen: `SCShareableContent` and `SCScreenshotManager` per display.
- Clipboard: `NSPasteboard` and `NSImage`.
- Image decoding: one `VNDetectBarcodesRequest` implementation restricted to QR symbology.

The native boundary returns structured JSON through Raycast's official [`extensions-swift-tools`](https://github.com/raycast/extensions-swift-tools) bridge. Permission denial, restricted camera access, missing hardware, empty clipboard, image conversion failure, and no QR result remain distinct errors.

## Project policies

- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Governance](GOVERNANCE.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Third-party dependencies and assets](THIRD_PARTY_NOTICES.md)

The project is licensed under the [MIT License](LICENSE). Contributions are accepted under the same license.
