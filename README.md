# QR Scanner for Raycast

Scan QR codes from a Mac camera, every visible display, or an image on the clipboard. QR recognition runs locally with Apple's AVFoundation, ScreenCaptureKit, and Vision frameworks; no image or QR content is sent to an external service.

## Commands

- **Scan QR from Camera** opens a floating native camera preview and closes it when a QR code is detected.
- **Scan QR from Screen** captures each connected display once and returns every QR code it finds.
- **Scan QR from Clipboard** reads copied images without requiring Screen Recording access.

Every result remains in Raycast until you explicitly open or copy it. This prevents an untrusted QR code from triggering a network request or launching another application without confirmation. Wi-Fi payloads show their parsed fields and provide separate copy actions. Duplicate payloads found on more than one display are shown once.

## Requirements

- macOS 14 or newer. Screen scanning uses Apple's one-shot `SCScreenshotManager` API.
- Raycast with extension development support.
- Node.js 22.22.2 or newer for development.
- Xcode 16.3 or newer for the Raycast Swift bridge.

## Install for development

1. Run `npm install` in this directory.
2. In Raycast, run **Import Extension** and select this directory.
3. Run `npm run dev`, or start development from Raycast's **Manage Extensions** command.

macOS attributes protected resources to Raycast. The first camera or screen scan can show a system permission prompt. If access was denied, use the command's **Open System Settings** action, grant the permission to Raycast, and restart Raycast when macOS requests it.

## Development checks

```sh
npm test
npm run test:swift
npm run lint
npm run build
```

The TypeScript tests write JSON to `test-results/vitest.json`; the Swift tests write xUnit XML to `test-results/swift.xml`. Swift tests generate a real QR image with Core Image and verify that Vision decodes it, plus a QR-free image for the adverse path.

## Architecture

The TypeScript entry points share result classification and Raycast UI in `src/`. The Swift executable package in `swift/` owns protected macOS APIs:

- Camera: `AVCaptureSession` and `AVCaptureMetadataOutput`, with an `NSPanel` preview.
- Screen: `SCShareableContent` and `SCScreenshotManager` per display.
- Clipboard: `NSPasteboard` and `NSImage`.
- Image decoding: one `VNDetectBarcodesRequest` implementation restricted to QR symbology.

The native boundary returns structured JSON through Raycast's official [`extensions-swift-tools`](https://github.com/raycast/extensions-swift-tools) bridge. Permission denial, restricted camera access, missing hardware, empty clipboard, image conversion failure, and no QR result remain distinct errors.
