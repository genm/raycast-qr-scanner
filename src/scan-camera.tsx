import { ScanCommand } from "./components/scan-command";
import { scanCamera } from "./lib/native";

export default function Command() {
  return <ScanCommand source="camera" scan={scanCamera} />;
}
