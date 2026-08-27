// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "QRScannerNative",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "QRScannerCore", targets: ["QRScannerCore"]),
    .library(name: "QRScannerMac", targets: ["QRScannerMac"]),
    .executable(name: "QRScannerNative", targets: ["QRScannerNative"]),
  ],
  dependencies: [
    .package(url: "https://github.com/raycast/extensions-swift-tools.git", from: "1.1.0"),
  ],
  targets: [
    .target(name: "QRScannerCore"),
    .target(name: "QRScannerMac", dependencies: ["QRScannerCore"]),
    .executableTarget(
      name: "QRScannerNative",
      dependencies: [
        "QRScannerCore",
        "QRScannerMac",
        .product(name: "RaycastSwiftMacros", package: "extensions-swift-tools"),
        .product(name: "RaycastSwiftPlugin", package: "extensions-swift-tools"),
        .product(name: "RaycastTypeScriptPlugin", package: "extensions-swift-tools"),
      ]
    ),
    .testTarget(name: "QRScannerCoreTests", dependencies: ["QRScannerCore"]),
    .testTarget(name: "QRScannerMacTests", dependencies: ["QRScannerCore", "QRScannerMac"]),
  ]
)
