import { describe, expect, it } from "vitest";

import { presentNativeError } from "./native-error";

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
    const result = presentNativeError(new Error("QRSCANNER_CAMERA_CONFIGURATION_FAILED: Camera is busy."), "camera");

    expect(result).toEqual({ title: "QR Scan Failed", message: "Camera is busy." });
  });
});
