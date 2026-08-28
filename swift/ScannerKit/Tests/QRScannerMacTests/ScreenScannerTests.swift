import XCTest
@testable import QRScannerMac

final class ScreenScannerTests: XCTestCase {
  func testPreflightOnlyModeFailsWithoutInvokingSystemPermissionRequest() {
    var requestWasCalled = false

    let isGranted = ScreenCaptureAuthorization.isGranted(
      requestPermissionIfNeeded: false,
      preflight: { false },
      request: {
        requestWasCalled = true
        return true
      }
    )

    XCTAssertFalse(isGranted)
    XCTAssertFalse(requestWasCalled)
  }

  func testRequestModeUsesSystemPermissionRequestAfterPreflightFails() {
    var requestWasCalled = false

    let isGranted = ScreenCaptureAuthorization.isGranted(
      requestPermissionIfNeeded: true,
      preflight: { false },
      request: {
        requestWasCalled = true
        return true
      }
    )

    XCTAssertTrue(isGranted)
    XCTAssertTrue(requestWasCalled)
  }

  func testGrantedPreflightDoesNotInvokeSystemPermissionRequest() {
    var requestWasCalled = false

    let isGranted = ScreenCaptureAuthorization.isGranted(
      requestPermissionIfNeeded: true,
      preflight: { true },
      request: {
        requestWasCalled = true
        return false
      }
    )

    XCTAssertTrue(isGranted)
    XCTAssertFalse(requestWasCalled)
  }
}
