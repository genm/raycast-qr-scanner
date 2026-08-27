import { describe, expect, it } from "vitest";

import { NATIVE_ERROR_CODES, presentNativeError } from "./native-error";

describe("presentNativeError", () => {
  it("offers the camera privacy settings for a denied camera", () => {
    const result = presentNativeError(new Error("QRSCANNER_CAMERA_PERMISSION_DENIED: Allow access."), "camera");

    expect(result.title).toBe("Camera Access Required");
    expect(result.settingsTarget).toContain("Privacy_Camera");
  });

  it("keeps an empty clipboard distinct from a QR-free image", () => {
    const emptyClipboard = presentNativeError(new Error("QRSCANNER_CLIPBOARD_NO_IMAGE: Empty."), "clipboard");
    const noCode = presentNativeError(new Error("QRSCANNER_NO_QR_CODE: None."), "clipboard");

    expect(emptyClipboard.title).toBe("No Image in Clipboard");
    expect(noCode.title).toBe("No QR Code Found");
  });

  it("does not hide an unexpected native failure", () => {
    const result = presentNativeError(new Error("QRSCANNER_UNEXPECTED: Camera is busy."), "camera");

    expect(result).toEqual({ title: "QR Scan Failed", message: "Camera is busy." });
  });

  it("keeps every Swift error code represented at the Raycast adapter boundary", () => {
    expect(Object.values(NATIVE_ERROR_CODES)).toEqual([
      "QRSCANNER_CAMERA_PERMISSION_DENIED",
      "QRSCANNER_CAMERA_RESTRICTED",
      "QRSCANNER_CAMERA_UNAVAILABLE",
      "QRSCANNER_CAMERA_CONFIGURATION_FAILED",
      "QRSCANNER_CAMERA_INTERRUPTED",
      "QRSCANNER_CAMERA_CANCELLED",
      "QRSCANNER_SCREEN_PERMISSION_DENIED",
      "QRSCANNER_SCREEN_UNAVAILABLE",
      "QRSCANNER_CLIPBOARD_NO_IMAGE",
      "QRSCANNER_IMAGE_CONVERSION_FAILED",
      "QRSCANNER_NO_QR_CODE",
    ]);
  });

  it("presents host-specific guidance for screen permission and camera cancellation", () => {
    const screen = presentNativeError(new Error(`${NATIVE_ERROR_CODES.screenPermissionDenied}: Denied.`), "screen");
    const cancelled = presentNativeError(new Error(`${NATIVE_ERROR_CODES.cameraCancelled}: Closed.`), "camera");

    expect(screen.settingsTarget).toContain("Privacy_ScreenCapture");
    expect(screen.message).toContain("Raycast");
    expect(cancelled.isCancellation).toBe(true);
  });

  it.each([
    ["camera", "camera image"],
    ["screen", "visible screens"],
    ["clipboard", "clipboard image"],
  ] as const)("labels a QR-free %s scan without hiding the failure", (source, label) => {
    const result = presentNativeError(new Error(`${NATIVE_ERROR_CODES.noQRCodeFound}: None.`), source);

    expect(result.message).toContain(label);
  });

  it("surfaces non-Error and malformed native failures", () => {
    expect(presentNativeError("native bridge failed", "camera").message).toBe("native bridge failed");
    expect(presentNativeError("QRSCANNER_UNKNOWN:", "camera").message).toBe("An unexpected error occurred.");
  });
});
