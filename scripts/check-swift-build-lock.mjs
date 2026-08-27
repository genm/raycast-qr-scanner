import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const buildDatabase = resolve("swift/.raycast-swift-build/Build/Intermediates.noindex/XCBuildData/build.db");

if (!existsSync(buildDatabase)) process.exit(0);

const result = spawnSync("lsof", ["-t", buildDatabase], { encoding: "utf8" });
if (result.error) {
  console.error(`Unable to check the Swift build lock: ${result.error.message}`);
  process.exit(1);
}

if (result.status === 0 && result.stdout.trim()) {
  // Raycast's debug and release builds share one Xcode build database and cannot run concurrently.
  console.error(
    "The Raycast Swift build is already running. Stop `npm run dev`, wait for xcodebuild to exit, and retry.",
  );
  process.exit(1);
}

if (result.status !== 1) {
  console.error(`Unable to check the Swift build lock (lsof exited with ${result.status ?? "no status"}).`);
  process.exit(1);
}
