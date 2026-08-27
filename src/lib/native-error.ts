import { ScanSource } from "./result";

export type ScanErrorPresentation = {
  title: string;
  message: string;
  settingsTarget?: string;
  isCancellation?: boolean;
};

const CAMERA_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera";
const SCREEN_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture";

export const NATIVE_ERROR_CODES = {
  cameraPermissionDenied: "QRSCANNER_CAMERA_PERMISSION_DENIED",
  cameraRestricted: "QRSCANNER_CAMERA_RESTRICTED",
  cameraUnavailable: "QRSCANNER_CAMERA_UNAVAILABLE",
  cameraConfigurationFailed: "QRSCANNER_CAMERA_CONFIGURATION_FAILED",
  cameraInterrupted: "QRSCANNER_CAMERA_INTERRUPTED",
  cameraCancelled: "QRSCANNER_CAMERA_CANCELLED",
  screenPermissionDenied: "QRSCANNER_SCREEN_PERMISSION_DENIED",
  screenUnavailable: "QRSCANNER_SCREEN_UNAVAILABLE",
  clipboardHasNoImage: "QRSCANNER_CLIPBOARD_NO_IMAGE",
  imageConversionFailed: "QRSCANNER_IMAGE_CONVERSION_FAILED",
  noQRCodeFound: "QRSCANNER_NO_QR_CODE",
} as const;

type NativeErrorCode = (typeof NATIVE_ERROR_CODES)[keyof typeof NATIVE_ERROR_CODES];

export function presentNativeError(error: unknown, source: ScanSource): ScanErrorPresentation {
  const message = error instanceof Error ? error.message : String(error);
  const code = extractNativeErrorCode(message);

  if (code === NATIVE_ERROR_CODES.cameraPermissionDenied) {
    return {
      title: "Camera Access Required",
      message: "Allow Raycast to use the camera in System Settings, then run the command again.",
      settingsTarget: CAMERA_SETTINGS,
    };
  }
  if (code === NATIVE_ERROR_CODES.screenPermissionDenied) {
    return {
      title: "Screen Recording Access Required",
      message: "Allow Raycast to record the screen in System Settings, restart Raycast, then run the command again.",
      settingsTarget: SCREEN_SETTINGS,
    };
  }
  if (code === NATIVE_ERROR_CODES.clipboardHasNoImage) {
    return { title: "No Image in Clipboard", message: "Copy an image containing a QR code and try again." };
  }
  if (code === NATIVE_ERROR_CODES.noQRCodeFound) {
    return { title: "No QR Code Found", message: `No QR code was found in the ${sourceLabel(source)}.` };
  }
  if (code === NATIVE_ERROR_CODES.cameraCancelled) {
    return {
      title: "Scan Cancelled",
      message: "The camera window was closed before a QR code was found.",
      isCancellation: true,
    };
  }

  const genericPresentation = code ? GENERIC_PRESENTATIONS[code] : undefined;
  if (genericPresentation) return genericPresentation;

  return { title: "QR Scan Failed", message: stripMachineCode(message) };
}

const GENERIC_PRESENTATIONS: Partial<Record<NativeErrorCode, ScanErrorPresentation>> = {
  [NATIVE_ERROR_CODES.cameraRestricted]: {
    title: "Camera Access Restricted",
    message: "Camera access is restricted by macOS or device policy.",
  },
  [NATIVE_ERROR_CODES.cameraUnavailable]: {
    title: "Camera Unavailable",
    message: "No available camera was found.",
  },
  [NATIVE_ERROR_CODES.cameraConfigurationFailed]: {
    title: "Camera Unavailable",
    message: "The camera could not be configured. Close other camera apps and try again.",
  },
  [NATIVE_ERROR_CODES.cameraInterrupted]: {
    title: "Camera Interrupted",
    message: "The camera session was interrupted. Wait for the camera to become available and try again.",
  },
  [NATIVE_ERROR_CODES.screenUnavailable]: {
    title: "Screen Unavailable",
    message: "No visible display was available to scan.",
  },
  [NATIVE_ERROR_CODES.imageConversionFailed]: {
    title: "Image Could Not Be Scanned",
    message: "The image could not be prepared for QR detection.",
  },
};

function sourceLabel(source: ScanSource): string {
  if (source === "screen") return "visible screens";
  if (source === "clipboard") return "clipboard image";
  return "camera image";
}

function stripMachineCode(message: string): string {
  return message.replace(/^.*?QRSCANNER_[A-Z_]+:\s*/, "").trim() || "An unexpected error occurred.";
}

function extractNativeErrorCode(message: string): NativeErrorCode | undefined {
  return Object.values(NATIVE_ERROR_CODES).find((code) => message.includes(code));
}
