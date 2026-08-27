import { ScanSource } from "./result";

export type ScanErrorPresentation = {
  title: string;
  message: string;
  settingsTarget?: string;
  isCancellation?: boolean;
};

const CAMERA_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera";
const SCREEN_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture";

export function presentNativeError(error: unknown, source: ScanSource): ScanErrorPresentation {
  const message = error instanceof Error ? error.message : String(error);

  if (message.includes("QRSCANNER_CAMERA_PERMISSION_DENIED")) {
    return {
      title: "Camera Access Required",
      message: "Allow Raycast to use the camera in System Settings, then run the command again.",
      settingsTarget: CAMERA_SETTINGS,
    };
  }
  if (message.includes("QRSCANNER_SCREEN_PERMISSION_DENIED")) {
    return {
      title: "Screen Recording Access Required",
      message: "Allow Raycast to record the screen in System Settings, restart Raycast, then run the command again.",
      settingsTarget: SCREEN_SETTINGS,
    };
  }
  if (message.includes("QRSCANNER_CLIPBOARD_NO_IMAGE")) {
    return { title: "No Image in Clipboard", message: "Copy an image containing a QR code and try again." };
  }
  if (message.includes("QRSCANNER_NO_QR_CODE")) {
    return { title: "No QR Code Found", message: `No QR code was found in the ${sourceLabel(source)}.` };
  }
  if (message.includes("QRSCANNER_CAMERA_CANCELLED")) {
    return {
      title: "Scan Cancelled",
      message: "The camera window was closed before a QR code was found.",
      isCancellation: true,
    };
  }

  return { title: "QR Scan Failed", message: stripMachineCode(message) };
}

function sourceLabel(source: ScanSource): string {
  if (source === "screen") return "visible screens";
  if (source === "clipboard") return "clipboard image";
  return "camera image";
}

function stripMachineCode(message: string): string {
  return message.replace(/^.*?QRSCANNER_[A-Z_]+:\s*/, "").trim() || "An unexpected error occurred.";
}
