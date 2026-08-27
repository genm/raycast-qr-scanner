import { scanClipboard } from "swift:../swift";

import { ScanCommand } from "./components/scan-command";
import { NativeScanResult } from "./lib/result";

export default function Command() {
  return <ScanCommand source="clipboard" scan={() => scanClipboard() as Promise<NativeScanResult[]>} />;
}
