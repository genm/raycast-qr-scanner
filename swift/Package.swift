// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "QRScannerNative",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "QRScannerNative", targets: ["QRScannerNative"])
  ],
  dependencies: [
    .package(path: "ScannerKit"),
    .package(url: "https://github.com/raycast/extensions-swift-tools.git", from: "1.1.0"),
  ],
  targets: [
    .executableTarget(
      name: "QRScannerNative",
      dependencies: [
        .product(name: "QRScannerCore", package: "ScannerKit"),
        .product(name: "QRScannerMac", package: "ScannerKit"),
        .product(name: "RaycastSwiftMacros", package: "extensions-swift-tools"),
        .product(name: "RaycastSwiftPlugin", package: "extensions-swift-tools"),
        .product(name: "RaycastTypeScriptPlugin", package: "extensions-swift-tools"),
      ]
    )
  ]
)
