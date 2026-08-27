import { scanScreen } from "swift:../swift";

import { ScanCommand } from "./components/scan-command";
import { NativeScanResult } from "./lib/result";

export default function Command() {
  return <ScanCommand source="screen" scan={() => scanScreen() as Promise<NativeScanResult[]>} />;
}
