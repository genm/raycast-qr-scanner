declare module "swift:../../swift" {
  import { NativeScanResult } from "./lib/result";

  export function scanCamera(): Promise<NativeScanResult[]>;
  export function scanClipboard(): Promise<NativeScanResult[]>;
  export function scanScreen(): Promise<NativeScanResult[]>;
}
