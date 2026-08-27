// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ScannerKit",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "QRScannerCore", targets: ["QRScannerCore"]),
    .library(name: "QRScannerMac", targets: ["QRScannerMac"]),
  ],
  targets: [
    .target(name: "QRScannerCore"),
    .target(name: "QRScannerMac", dependencies: ["QRScannerCore"]),
    .testTarget(name: "QRScannerCoreTests", dependencies: ["QRScannerCore"]),
    .testTarget(name: "QRScannerMacTests", dependencies: ["QRScannerCore", "QRScannerMac"]),
  ]
)
