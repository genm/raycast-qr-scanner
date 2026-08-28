import CoreGraphics
import QRScannerCore
import ScreenCaptureKit

public enum ScreenScanner {
  public static func scan(requestPermissionIfNeeded: Bool = true) async throws -> [ScanResult] {
    guard ScreenCaptureAuthorization.isGranted(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
      preflight: CGPreflightScreenCaptureAccess,
      request: CGRequestScreenCaptureAccess
    ) else {
      throw ScanError.screenPermissionDenied
    }

    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard !content.displays.isEmpty else {
      throw ScanError.screenUnavailable
    }

    var results: [ScanResult] = []
    for display in content.displays {
      let filter = SCContentFilter(display: display, excludingWindows: [])
      let configuration = SCStreamConfiguration()
      configuration.width = display.width
      configuration.height = display.height
      configuration.showsCursor = false
      configuration.capturesAudio = false

      let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
      let values = try QRDecoder.decode(cgImage: image)
      results.append(contentsOf: values.map { ScanResult(value: $0, source: .screen, displayID: display.displayID) })
    }

    guard !results.isEmpty else {
      throw ScanError.noQRCodeFound
    }

    return results
  }
}

enum ScreenCaptureAuthorization {
  static func isGranted(
    requestPermissionIfNeeded: Bool,
    preflight: () -> Bool,
    request: () -> Bool
  ) -> Bool {
    guard !preflight() else { return true }
    guard requestPermissionIfNeeded else { return false }
    return request()
  }
}
