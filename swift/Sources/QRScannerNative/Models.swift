import Foundation

enum ScanSource: String, Codable, Sendable {
  case camera
  case screen
  case clipboard
}

struct ScanResult: Codable, Equatable, Sendable {
  let value: String
  let source: ScanSource
  let displayID: UInt32?

  init(value: String, source: ScanSource, displayID: UInt32? = nil) {
    self.value = value
    self.source = source
    self.displayID = displayID
  }
}

enum ScanError: Error, LocalizedError, CustomStringConvertible, Sendable {
  case cameraPermissionDenied
  case cameraRestricted
  case cameraUnavailable
  case cameraConfigurationFailed
  case cameraInterrupted
  case cameraCancelled
  case screenPermissionDenied
  case screenUnavailable
  case clipboardHasNoImage
  case imageConversionFailed
  case noQRCodeFound

  var errorDescription: String? {
    switch self {
    case .cameraPermissionDenied:
      "QRSCANNER_CAMERA_PERMISSION_DENIED: Allow Raycast to use the camera in System Settings."
    case .cameraRestricted:
      "QRSCANNER_CAMERA_RESTRICTED: Camera access is restricted on this Mac."
    case .cameraUnavailable:
      "QRSCANNER_CAMERA_UNAVAILABLE: No available camera was found."
    case .cameraConfigurationFailed:
      "QRSCANNER_CAMERA_CONFIGURATION_FAILED: The camera capture session could not be configured."
    case .cameraInterrupted:
      "QRSCANNER_CAMERA_INTERRUPTED: The camera capture session was interrupted."
    case .cameraCancelled:
      "QRSCANNER_CAMERA_CANCELLED: Camera scanning was cancelled."
    case .screenPermissionDenied:
      "QRSCANNER_SCREEN_PERMISSION_DENIED: Allow Raycast to record the screen in System Settings, then restart Raycast."
    case .screenUnavailable:
      "QRSCANNER_SCREEN_UNAVAILABLE: No display was available to scan."
    case .clipboardHasNoImage:
      "QRSCANNER_CLIPBOARD_NO_IMAGE: The clipboard does not contain an image."
    case .imageConversionFailed:
      "QRSCANNER_IMAGE_CONVERSION_FAILED: The image could not be prepared for QR detection."
    case .noQRCodeFound:
      "QRSCANNER_NO_QR_CODE: No QR code was found."
    }
  }

  var description: String { errorDescription ?? "QR Scanner failed." }
}
