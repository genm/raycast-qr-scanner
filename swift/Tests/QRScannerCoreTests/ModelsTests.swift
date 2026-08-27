import Foundation
import QRScannerCore
import XCTest

final class ModelsTests: XCTestCase {
  func testScanSourceRawValuesRemainStableAcrossHostAdapters() {
    XCTAssertEqual(
      ScanSource.allCases.map(\.rawValue),
      ["camera", "screen", "clipboard"]
    )
  }

  func testScanResultJSONContractIncludesOnlyPresentFields() throws {
    let encoder = JSONEncoder()
    let camera = try jsonObject(encoder.encode(ScanResult(value: "camera", source: .camera)))
    let screen = try jsonObject(encoder.encode(ScanResult(value: "screen", source: .screen, displayID: 42)))

    XCTAssertEqual(camera, ["value": "camera", "source": "camera"])
    XCTAssertEqual(screen, ["value": "screen", "source": "screen", "displayID": 42])
  }

  func testEveryScanErrorHasAStableCodeAndHostNeutralMessage() {
    let errors: [ScanError] = [
      .cameraPermissionDenied,
      .cameraRestricted,
      .cameraUnavailable,
      .cameraConfigurationFailed,
      .cameraInterrupted,
      .cameraCancelled,
      .screenPermissionDenied,
      .screenUnavailable,
      .clipboardHasNoImage,
      .imageConversionFailed,
      .noQRCodeFound,
    ]

    XCTAssertEqual(errors.map(\.code), ScanErrorCode.allCases)
    for error in errors {
      let description = error.localizedDescription
      XCTAssertTrue(description.hasPrefix("\(error.code.rawValue): "))
      XCTAssertFalse(description.localizedCaseInsensitiveContains("Raycast"))
    }
  }

  private func jsonObject(_ data: Data) throws -> NSDictionary {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }
}
