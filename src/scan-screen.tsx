import { ScanCommand } from "./components/scan-command";
import { scanScreen } from "./lib/native";

export default function Command() {
  return <ScanCommand source="screen" scan={scanScreen} />;
}
