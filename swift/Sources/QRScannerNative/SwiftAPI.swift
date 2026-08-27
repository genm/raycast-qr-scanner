import Foundation
import QRScannerCore
import QRScannerMac
import RaycastSwiftMacros

@raycast
func scanCamera() async throws -> [ScanResult] {
  try await CameraScanner.scan()
}

@raycast
func scanScreen() async throws -> [ScanResult] {
  try await ScreenScanner.scan()
}

@raycast
func scanClipboard() async throws -> [ScanResult] {
  try await MainActor.run {
    try ClipboardScanner.scan()
  }
}
