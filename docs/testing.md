# Testing and Acceptance

## Decisive local check

Run the repository-wide check from the project root:

```sh
npm run check
```

This command runs Raycast linting, TypeScript tests, Swift tests, a production extension build, and a high-severity production-dependency audit. Stop `npm run dev` and wait for its native build to finish first; debug and release builds share one Swift build database.

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

GitHub Actions runs the same `npm run check` command on `macos-15` with Xcode 16.4. Failed machine-readable test results are uploaded for three days; successful runs do not upload them.

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

## Other adverse paths

Exercise the affected path when changing permissions or source capture:

- camera permission denied or restricted;
- no camera available or capture interrupted;
- Screen Recording permission denied;
- no visible display;
- clipboard without an image;
- valid image with no QR code;
- Vision or image conversion failure.

Each path must remain distinguishable in the Raycast error UI and must not return an empty success.

`No QR Code Found` is a terminal result for static screen and clipboard inputs. A camera frame without a QR code keeps scanning; closing the camera before detection produces an explicit cancellation instead of an automatic no-QR timeout.
