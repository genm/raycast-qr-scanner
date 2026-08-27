# Command-Line Interface

The `qr-scanner` executable is a macOS adapter over `QRScannerCore` and `QRScannerMac`. It does not depend on Raycast APIs and does not open decoded URLs or write scan history.

## Run from source

```sh
swift run --package-path cli qr-scanner camera
swift run --package-path cli qr-scanner screen
swift run --package-path cli qr-scanner clipboard
```

Use `--pretty` before or after the command for formatted JSON:

```sh
swift run --package-path cli qr-scanner --pretty screen
```

Build a release binary with:

```sh
swift build --package-path cli --configuration release --product qr-scanner
```

## Success output

A successful scan writes an array of Core `ScanResult` values to stdout and exits with status 0:

```json
[
  {
    "displayID": 1,
    "source": "screen",
    "value": "https://example.test/from-screen"
  }
]
```

`displayID` is present only for screen results. Camera and clipboard results contain `source` and `value`.

## Error output

Failures write one JSON object to stderr and do not write synthetic success data to stdout:

```json
{
  "code": "QRSCANNER_SCREEN_PERMISSION_DENIED",
  "message": "Screen recording access is denied."
}
```

Core scanner failures preserve their `ScanErrorCode`. CLI argument and unexpected adapter failures use `QRSCANNER_CLI_USAGE` and `QRSCANNER_CLI_INTERNAL_ERROR` respectively.

| Exit status | Meaning                                                    |
| ----------- | ---------------------------------------------------------- |
| 0           | Successful scan or `--help`                                |
| 64          | Invalid CLI usage                                          |
| 65          | Image data could not be prepared                           |
| 66          | Required input or a QR result was absent                   |
| 69          | Camera or screen service was unavailable or interrupted    |
| 70          | Unexpected CLI or native failure                           |
| 77          | Camera or Screen Recording access was denied or restricted |
| 130         | The camera panel was closed before detection               |

## Permissions and privacy

Camera and Screen Recording approval for the CLI is separate from Raycast. macOS can attribute protected-resource access to the terminal application or executable identity it recognizes. Follow the system prompt and inspect **System Settings > Privacy & Security** for the actual requesting process.

Clipboard scanning reads the current clipboard image. Screen scanning captures each visible display once. Camera frames, screenshots, clipboard images, and decoded values remain local to the process. Do not paste CLI JSON containing private QR payloads into public issues or logs.

## Automation contract

- stdout contains only successful `ScanResult[]` JSON;
- stderr contains only failure JSON during scan execution;
- all JSON records end with a newline;
- an empty or QR-free input is a nonzero failure, not `[]`;
- decoded URLs are data and are never opened automatically.

Future MCP or other host adapters should import `QRScannerCore` and `QRScannerMac` directly. The CLI JSON contract is for shell composition, not an internal transport between adapters.
