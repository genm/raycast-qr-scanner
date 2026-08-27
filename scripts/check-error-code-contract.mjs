import { readFileSync } from "node:fs";

const [swiftPath = "swift/Sources/QRScannerCore/Models.swift", typescriptPath = "src/lib/native-error.ts"] =
  process.argv.slice(2);
const codePattern = /QRSCANNER_[A-Z_]+/g;

function extractCodes(path) {
  return new Set(readFileSync(path, "utf8").match(codePattern) ?? []);
}

const swiftCodes = extractCodes(swiftPath);
const typescriptCodes = extractCodes(typescriptPath);
const missingFromTypescript = [...swiftCodes].filter((code) => !typescriptCodes.has(code));
const missingFromSwift = [...typescriptCodes].filter((code) => !swiftCodes.has(code));

if (swiftCodes.size === 0 || missingFromTypescript.length > 0 || missingFromSwift.length > 0) {
  console.error(
    JSON.stringify({
      error: "native-error-contract-mismatch",
      swiftPath,
      typescriptPath,
      missingFromTypescript,
      missingFromSwift,
    }),
  );
  process.exit(1);
}

console.log(JSON.stringify({ nativeErrorCodes: swiftCodes.size, contract: "matched" }));
