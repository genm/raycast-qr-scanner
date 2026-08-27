import { scanCamera } from "swift:../swift";

import { ScanCommand } from "./components/scan-command";
import { NativeScanResult } from "./lib/result";

export default function Command() {
  return <ScanCommand source="camera" scan={() => scanCamera() as Promise<NativeScanResult[]>} />;
}
