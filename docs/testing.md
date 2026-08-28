# Testing and Acceptance

## Decisive local check

Run the repository-wide check from the project root:

```sh
mise run check
```

This task validates GitHub Actions with Actionlint, then runs `npm run check`, which performs TypeScript type checking, Raycast linting, TypeScript tests, Swift tests, a production extension build, and a high-severity production-dependency audit. Run it on macOS, and stop `npm run dev` before starting because debug and release builds share one Swift build database. Running `npm run check` directly covers the application checks when the declared Node.js and npm versions are already active.

Machine-readable results are written to:

- `test-results/vitest.json` for TypeScript tests
- `test-results/swift.xml` for Core and Mac Swift xUnit results
- `test-results/swift-cli.xml` for CLI Swift xUnit results

Judge the run from those result files and the command exit status. A timeout, missing file, skipped build, or dependency-provider failure is not a passing result.

## Camera CI matrix

The Swift tests generate QR images with Core Image, draw them into BGRA `CVPixelBuffer` values, wrap those buffers in `CMSampleBuffer`, and run the production Vision decoder. The matrix covers:

- a normal generated QR payload;
- rotations at 0, 90, 180, and 270 degrees;
- mirrored input with the corresponding Vision orientation;
- QR side-length ratios of 0.12, 0.25, and 0.5 relative to the frame's shorter edge;
- a frame without a QR code;
- normalized QR bounding-box extraction;
- frozen-frame `CGImage` dimensions;
- `resizeAspectFill` crop math;
- unflipped and flipped AppKit overlay coordinates;
- the `.nonactivatingPanel` presentation contract and presenting-application restoration.

Core contract tests separately lock the `ScanSource` raw values, encoded `ScanResult` JSON shape, stable error codes, and host-neutral native error messages used across bridge adapters.

CLI adapter tests inject a scanner instead of accessing real protected resources. They cover command routing, compact and pretty JSON, help and invalid arguments, every Core error code and exit-status mapping, and unexpected failures. `swift run ... --help` and an invalid CLI invocation provide subprocess-level stdout/stderr and exit-status checks without reading the real camera, screens, or clipboard.

The distance ratios are test inputs, not promised camera limits. Real recognition also depends on focus, lighting, contrast, perspective, damage, and camera characteristics.

GitHub Actions installs the npm version declared by `packageManager` and performs a clean `npm ci` on both platforms. The macOS job runs the same `npm run check` command on `macos-15` with Xcode 16.4. A Windows job separately checks the development-toolchain and error contracts, types, lint, TypeScript tests, and production dependency audit without trying to compile the macOS Swift package. Failed machine-readable test results are uploaded for three days; successful runs do not upload them.

The TypeScript matrix generates real PNG QR fixtures, including two distinct QR codes in one image and a QR-free image. It exercises the production PNG-to-RGBA and local decoding path used by every Windows source.

## Manual camera acceptance

Hosted CI cannot provide a physical camera, macOS TCC interaction, Raycast focus behavior, or human visual review. Camera-affecting changes therefore also require this checklist in a development import:

1. Start **Scan QR from Camera** from a Raycast view command.
2. Confirm the camera panel appears without dismissing or deactivating the underlying Raycast view.
3. Confirm the status changes from the opening message to `Camera active — looking for QR code…` after the first frame.
4. Present a realistic QR code near the center, then near an edge.
5. Confirm detection freezes the matched frame and the highlight surrounds the QR rather than a mirrored or vertically displaced location.
6. Confirm the success state remains visible for approximately one second.
7. Confirm only the camera panel closes, Raycast returns to the foreground, and the result list appears.
8. Confirm opening a URL remains an explicit action; scanning alone must not launch it.
9. Close the camera before detection and confirm Raycast presents cancellation rather than synthetic success.

Use reserved `.test` domains for generated fixtures and redact all real QR content from screenshots and issue reports.

## Windows manual acceptance

Windows capture APIs require an interactive desktop, clipboard, and Windows Camera, so hosted CI covers the decoder and contracts while a development import covers integration:

1. Run **Scan QR from Screen** with distinct test QR codes on two displays. Confirm Raycast hides before capture, restores itself, and lists both values with their display labels.
2. Run the screen command with no QR visible and confirm `No QR Code Found` rather than an empty result.
3. Copy an image containing multiple test QR codes and confirm **Scan QR from Clipboard** returns all distinct values.
4. Copy text instead of an image and confirm `No Image in Clipboard`.
5. Run **Scan QR from Camera**. Confirm Windows Camera opens, a visible test QR is returned, and scanning alone does not open its URL.
6. Start the camera command and close Windows Camera before detection. Confirm Raycast restores and presents cancellation.
7. Confirm the extension support directory contains no `scan-*` temporary directory after each success and failure case.

## Other adverse paths

Exercise the affected path when changing permissions or source capture:

- macOS camera permission denied or restricted;
- Windows Camera missing or closed before detection;
- no camera available or capture interrupted;
- Screen Recording permission denied;
- no visible display;
- clipboard without an image;
- valid image with no QR code;
- Vision or image conversion failure.

Each path must remain distinguishable in the Raycast error UI and must not return an empty success.

`No QR Code Found` is a terminal result for static screen and clipboard inputs. A camera frame without a QR code keeps scanning; closing the camera before detection produces an explicit cancellation instead of an automatic no-QR timeout.
