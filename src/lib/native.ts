import {
  scanCamera as scanCameraNative,
  scanClipboard as scanClipboardNative,
  scanScreen as scanScreenNative,
} from "swift:../../swift";

import { NativeScanResult } from "./result";
import { singleFlight } from "./single-flight";
import { scanWindowsCamera, scanWindowsClipboard, scanWindowsScreen } from "./windows";

// Keep the Swift package import at one module boundary so multi-entry builds compile it once.
export const scanCamera = singleFlight(() =>
  process.platform === "win32" ? scanWindowsCamera() : (scanCameraNative() as Promise<NativeScanResult[]>),
);
export const scanScreen = singleFlight(() =>
  process.platform === "win32" ? scanWindowsScreen() : (scanScreenNative() as Promise<NativeScanResult[]>),
);
export const scanClipboard = singleFlight(() =>
  process.platform === "win32" ? scanWindowsClipboard() : (scanClipboardNative() as Promise<NativeScanResult[]>),
);
