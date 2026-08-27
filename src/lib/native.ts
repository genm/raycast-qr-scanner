import {
  scanCamera as scanCameraNative,
  scanClipboard as scanClipboardNative,
  scanScreen as scanScreenNative,
} from "swift:../../swift";

import { NativeScanResult } from "./result";
import { singleFlight } from "./single-flight";

// Keep the Swift package import at one module boundary so multi-entry builds compile it once.
export const scanCamera = singleFlight(() => scanCameraNative() as Promise<NativeScanResult[]>);
export const scanScreen = singleFlight(() => scanScreenNative() as Promise<NativeScanResult[]>);
export const scanClipboard = singleFlight(() => scanClipboardNative() as Promise<NativeScanResult[]>);
