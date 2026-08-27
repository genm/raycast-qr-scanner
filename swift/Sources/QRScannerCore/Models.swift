import Foundation

public enum ScanSource: String, CaseIterable, Codable, Sendable {
  case camera
  case screen
  case clipboard
}

public struct ScanResult: Codable, Equatable, Sendable {
  public let value: String
  public let source: ScanSource
  public let displayID: UInt32?

  public init(value: String, source: ScanSource, displayID: UInt32? = nil) {
    self.value = value
    self.source = source
    self.displayID = displayID
  }
}

public enum ScanErrorCode: String, CaseIterable, Codable, Sendable {
  case cameraPermissionDenied = "QRSCANNER_CAMERA_PERMISSION_DENIED"
  case cameraRestricted = "QRSCANNER_CAMERA_RESTRICTED"
  case cameraUnavailable = "QRSCANNER_CAMERA_UNAVAILABLE"
  case cameraConfigurationFailed = "QRSCANNER_CAMERA_CONFIGURATION_FAILED"
  case cameraInterrupted = "QRSCANNER_CAMERA_INTERRUPTED"
  case cameraCancelled = "QRSCANNER_CAMERA_CANCELLED"
  case screenPermissionDenied = "QRSCANNER_SCREEN_PERMISSION_DENIED"
  case screenUnavailable = "QRSCANNER_SCREEN_UNAVAILABLE"
  case clipboardHasNoImage = "QRSCANNER_CLIPBOARD_NO_IMAGE"
  case imageConversionFailed = "QRSCANNER_IMAGE_CONVERSION_FAILED"
  case noQRCodeFound = "QRSCANNER_NO_QR_CODE"
}

public enum ScanError: Error, LocalizedError, CustomStringConvertible, Sendable {
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

  public var code: ScanErrorCode {
    switch self {
    case .cameraPermissionDenied: .cameraPermissionDenied
    case .cameraRestricted: .cameraRestricted
    case .cameraUnavailable: .cameraUnavailable
    case .cameraConfigurationFailed: .cameraConfigurationFailed
    case .cameraInterrupted: .cameraInterrupted
    case .cameraCancelled: .cameraCancelled
    case .screenPermissionDenied: .screenPermissionDenied
    case .screenUnavailable: .screenUnavailable
    case .clipboardHasNoImage: .clipboardHasNoImage
    case .imageConversionFailed: .imageConversionFailed
    case .noQRCodeFound: .noQRCodeFound
    }
  }

  public var errorDescription: String? {
    "\(code.rawValue): \(message)"
  }

  public var description: String { errorDescription ?? "QR Scanner failed." }

  private var message: String {
    switch self {
    case .cameraPermissionDenied:
      "Camera access is denied."
    case .cameraRestricted:
      "Camera access is restricted on this Mac."
    case .cameraUnavailable:
      "No available camera was found."
    case .cameraConfigurationFailed:
      "The camera capture session could not be configured."
    case .cameraInterrupted:
      "The camera capture session was interrupted."
    case .cameraCancelled:
      "Camera scanning was cancelled."
    case .screenPermissionDenied:
      "Screen recording access is denied."
    case .screenUnavailable:
      "No display was available to scan."
    case .clipboardHasNoImage:
      "The clipboard does not contain an image."
    case .imageConversionFailed:
      "The image could not be prepared for QR detection."
    case .noQRCodeFound:
      "No QR code was found."
    }
  }
}
