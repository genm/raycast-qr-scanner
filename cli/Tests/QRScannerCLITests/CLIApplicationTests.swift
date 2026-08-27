import Foundation
import QRScannerCore
import XCTest

@testable import QRScannerCLI

final class CLIApplicationTests: XCTestCase {
  func testWritesScanResultsAsJSON() async throws {
    let execution = await CLIApplication.run(arguments: ["screen"]) { command in
      guard command == .screen else { throw TestFailure.unexpectedCommand }
      return [ScanResult(value: "https://example.test/from-cli", source: .screen, displayID: 7)]
    }

    XCTAssertEqual(execution.exitCode, CLIExitCode.success)
    XCTAssertEqual(execution.standardError, "")
    let results = try JSONDecoder().decode(
      [ScanResult].self, from: Data(execution.standardOutput.utf8))
    XCTAssertEqual(
      results, [ScanResult(value: "https://example.test/from-cli", source: .screen, displayID: 7)])
  }

  func testPrettyPrintsSuccessfulJSONWhenRequested() async {
    let execution = await CLIApplication.run(arguments: ["--pretty", "clipboard"]) { _ in
      [ScanResult(value: "text", source: .clipboard)]
    }

    XCTAssertEqual(execution.exitCode, CLIExitCode.success)
    XCTAssertTrue(execution.standardOutput.contains("\n  {"))
  }

  func testRejectsAnEmptyScanResultAsNoQRCodeFound() async throws {
    let execution = await CLIApplication.run(arguments: ["screen"]) { _ in [] }

    XCTAssertEqual(execution.exitCode, CLIExitCode.noInput)
    XCTAssertEqual(execution.standardOutput, "")
    XCTAssertEqual(
      try decodeError(execution.standardError),
      CLIErrorOutput(
        code: ScanError.noQRCodeFound.code.rawValue, message: ScanError.noQRCodeFound.message)
    )
  }

  func testReturnsMachineReadableUsageFailureWithoutScanning() async throws {
    let execution = await CLIApplication.run(arguments: ["--unknown"]) { _ in
      throw TestFailure.scanShouldNotRun
    }

    XCTAssertEqual(execution.exitCode, CLIExitCode.usage)
    XCTAssertEqual(execution.standardOutput, "")
    let error = try decodeError(execution.standardError)
    XCTAssertEqual(error.code, "QRSCANNER_CLI_USAGE")
    XCTAssertEqual(error.message, "Unknown option: --unknown")
  }

  func testHelpIsSuccessfulAndDoesNotScan() async {
    let execution = await CLIApplication.run(arguments: ["--help"]) { _ in
      throw TestFailure.scanShouldNotRun
    }

    XCTAssertEqual(execution.exitCode, CLIExitCode.success)
    XCTAssertEqual(execution.standardError, "")
    XCTAssertTrue(execution.standardOutput.contains("Usage: qr-scanner"))
  }

  func testRejectsMissingAndMultipleCommands() {
    XCTAssertEqual(CLIApplication.parse(arguments: []), .failure("A scan command is required."))
    XCTAssertEqual(
      CLIApplication.parse(arguments: ["camera", "screen"]),
      .failure("Only one scan command can be specified.")
    )
  }

  func testMapsEveryCoreErrorToStableJSONAndExitStatus() async throws {
    let cases: [(ScanError, Int32)] = [
      (.cameraPermissionDenied, CLIExitCode.noPermission),
      (.cameraRestricted, CLIExitCode.noPermission),
      (.cameraUnavailable, CLIExitCode.unavailable),
      (.cameraConfigurationFailed, CLIExitCode.unavailable),
      (.cameraInterrupted, CLIExitCode.unavailable),
      (.cameraCancelled, CLIExitCode.cancelled),
      (.screenPermissionDenied, CLIExitCode.noPermission),
      (.screenUnavailable, CLIExitCode.unavailable),
      (.clipboardHasNoImage, CLIExitCode.noInput),
      (.imageConversionFailed, CLIExitCode.dataError),
      (.noQRCodeFound, CLIExitCode.noInput),
    ]

    for (scanError, exitCode) in cases {
      let execution = await CLIApplication.run(arguments: ["camera"]) { _ in throw scanError }
      let output = try decodeError(execution.standardError)

      XCTAssertEqual(execution.exitCode, exitCode, scanError.code.rawValue)
      XCTAssertEqual(execution.standardOutput, "", scanError.code.rawValue)
      XCTAssertEqual(
        output, CLIErrorOutput(code: scanError.code.rawValue, message: scanError.message))
    }
  }

  func testSurfacesUnexpectedFailuresWithoutSyntheticSuccess() async throws {
    let execution = await CLIApplication.run(arguments: ["camera"]) { _ in
      throw TestFailure.unexpectedCommand
    }

    XCTAssertEqual(execution.exitCode, CLIExitCode.software)
    XCTAssertEqual(execution.standardOutput, "")
    XCTAssertEqual(
      try decodeError(execution.standardError),
      CLIErrorOutput(
        code: "QRSCANNER_CLI_INTERNAL_ERROR", message: "The CLI received an unexpected command.")
    )
  }

  private func decodeError(_ output: String) throws -> CLIErrorOutput {
    try JSONDecoder().decode(CLIErrorOutput.self, from: Data(output.utf8))
  }
}

private enum TestFailure: LocalizedError {
  case scanShouldNotRun
  case unexpectedCommand

  var errorDescription: String? {
    switch self {
    case .scanShouldNotRun: "The scan operation should not have run."
    case .unexpectedCommand: "The CLI received an unexpected command."
    }
  }
}
