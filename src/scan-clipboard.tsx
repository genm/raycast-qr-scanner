import { ScanCommand } from "./components/scan-command";
import { scanClipboard } from "./lib/native";

export default function Command() {
  return <ScanCommand source="clipboard" scan={scanClipboard} />;
}
