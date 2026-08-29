import { readFileSync } from "node:fs";

const [
  packagePath = "package.json",
  nodeVersionPath = ".node-version",
  misePath = "mise.toml",
  npmrcPath = ".npmrc",
] = process.argv.slice(2);
const packageJson = JSON.parse(readFileSync(packagePath, "utf8"));
const nodeVersion = readFileSync(nodeVersionPath, "utf8").trim();
const miseConfig = readFileSync(misePath, "utf8");
const npmrc = new Set(
  readFileSync(npmrcPath, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean),
);

const declaredNpm = /^npm@(?<version>\d+\.\d+\.\d+)$/.exec(packageJson.packageManager);
const miseNpm = /^"npm:npm"\s*=\s*"(?<version>\d+\.\d+\.\d+)"$/m.exec(miseConfig);
const requiredNpmrc = ["engine-strict=true", "save-exact=true", "strict-allow-scripts=true"];
const missingNpmrc = requiredNpmrc.filter((entry) => !npmrc.has(entry));

const errors = [];
if (packageJson.engines?.node !== `>=${nodeVersion}`) {
  errors.push(".node-version must match the minimum Node.js version in package.json");
}
if (!declaredNpm) {
  errors.push('packageManager must pin npm as "npm@<exact-version>"');
}
if (!miseNpm || miseNpm.groups.version !== declaredNpm?.groups.version) {
  errors.push("mise.toml must pin the npm version declared by packageManager");
}
if (missingNpmrc.length > 0) {
  errors.push(`.npmrc is missing required settings: ${missingNpmrc.join(", ")}`);
}

if (errors.length > 0) {
  console.error(JSON.stringify({ error: "development-toolchain-contract-mismatch", errors }));
  process.exit(1);
}

console.log(
  JSON.stringify({
    node: nodeVersion,
    npm: declaredNpm.groups.version,
    installScripts: "strict-allowlist",
    dependencyVersions: "exact",
    contract: "matched",
  }),
);
