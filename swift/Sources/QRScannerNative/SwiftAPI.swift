import Foundation
import QRScannerCore
import QRScannerMac
import RaycastSwiftMacros

@raycast
func scanCamera() async throws -> [ScanResult] {
  try await CameraScanner.scan(
    presentingApplicationBundleIdentifier: "com.raycast.macos",
    presentingApplicationRevealURL: URL(string: "raycast://")
  )
}

@raycast
func scanScreen() async throws -> [ScanResult] {
  // Raycast can show an actionable Settings state; avoid blocking on macOS's synchronous request dialog.
  try await ScreenScanner.scan(requestPermissionIfNeeded: false)
}

@raycast
func scanClipboard() async throws -> [ScanResult] {
  try await MainActor.run {
    try ClipboardScanner.scan()
  }
}
