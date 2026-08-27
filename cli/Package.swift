// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "QRScannerCLI",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "qr-scanner", targets: ["QRScannerCLI"])
  ],
  dependencies: [
    .package(path: "../swift/ScannerKit")
  ],
  targets: [
    .executableTarget(
      name: "QRScannerCLI",
      dependencies: [
        .product(name: "QRScannerCore", package: "ScannerKit"),
        .product(name: "QRScannerMac", package: "ScannerKit"),
      ]
    ),
    .testTarget(
      name: "QRScannerCLITests",
      dependencies: [
        "QRScannerCLI",
        .product(name: "QRScannerCore", package: "ScannerKit"),
      ]
    ),
  ]
)
