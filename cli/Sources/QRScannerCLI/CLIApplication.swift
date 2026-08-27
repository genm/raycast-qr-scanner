import Foundation
import QRScannerCore
import QRScannerMac

enum CLICommand: String, CaseIterable, Sendable {
  case camera
  case screen
  case clipboard
}

struct CLIOptions: Equatable, Sendable {
  let command: CLICommand
  let pretty: Bool
}

enum CLIParseResult: Equatable, Sendable {
  case help
  case run(CLIOptions)
  case failure(String)
}

struct CLIExecution: Equatable, Sendable {
  let standardOutput: String
  let standardError: String
  let exitCode: Int32
}

struct CLIErrorOutput: Codable, Equatable, Sendable {
  let code: String
  let message: String
}

enum CLIExitCode {
  static let success: Int32 = 0
  static let dataError: Int32 = 65
  static let noInput: Int32 = 66
  static let unavailable: Int32 = 69
  static let software: Int32 = 70
  static let noPermission: Int32 = 77
  static let cancelled: Int32 = 130
  static let usage: Int32 = 64
}

typealias CLIScanOperation = @Sendable (CLICommand) async throws -> [ScanResult]

enum CLIApplication {
  static let usage = """
    Usage: qr-scanner [--pretty] <camera|screen|clipboard>

    Scan QR codes locally and write ScanResult[] JSON to stdout.

    Options:
      --pretty  Pretty-print JSON output.
      -h, --help  Show this help text.
    """

  static func parse(arguments: [String]) -> CLIParseResult {
    if arguments.contains("--help") || arguments.contains("-h") {
      return .help
    }

    var command: CLICommand?
    var pretty = false
    for argument in arguments {
      if argument == "--pretty" {
        pretty = true
      } else if argument.hasPrefix("-") {
        return .failure("Unknown option: \(argument)")
      } else if let parsedCommand = CLICommand(rawValue: argument) {
        guard command == nil else {
          return .failure("Only one scan command can be specified.")
        }
        command = parsedCommand
      } else {
        return .failure("Unknown command: \(argument)")
      }
    }

    guard let command else {
      return .failure("A scan command is required.")
    }
    return .run(CLIOptions(command: command, pretty: pretty))
  }

  static func run(
    arguments: [String],
    scan: @escaping CLIScanOperation = scanLive
  ) async -> CLIExecution {
    switch parse(arguments: arguments) {
    case .help:
      return CLIExecution(
        standardOutput: "\(usage)\n", standardError: "", exitCode: CLIExitCode.success)
    case .failure(let message):
      return failure(
        CLIErrorOutput(code: "QRSCANNER_CLI_USAGE", message: message),
        exitCode: CLIExitCode.usage
      )
    case .run(let options):
      do {
        let results = try await scan(options.command)
        guard !results.isEmpty else {
          throw ScanError.noQRCodeFound
        }
        return CLIExecution(
          standardOutput: try encode(results, pretty: options.pretty),
          standardError: "",
          exitCode: CLIExitCode.success
        )
      } catch let error as ScanError {
        return failure(
          CLIErrorOutput(code: error.code.rawValue, message: error.message),
          exitCode: exitCode(for: error)
        )
      } catch {
        return failure(
          CLIErrorOutput(code: "QRSCANNER_CLI_INTERNAL_ERROR", message: error.localizedDescription),
          exitCode: CLIExitCode.software
        )
      }
    }
  }

  private static func scanLive(command: CLICommand) async throws -> [ScanResult] {
    switch command {
    case .camera:
      try await CameraScanner.scan()
    case .screen:
      try await ScreenScanner.scan()
    case .clipboard:
      try await ClipboardScanner.scan()
    }
  }

  private static func failure(_ error: CLIErrorOutput, exitCode: Int32) -> CLIExecution {
    do {
      return CLIExecution(
        standardOutput: "",
        standardError: try encode(error, pretty: false),
        exitCode: exitCode
      )
    } catch {
      return CLIExecution(
        standardOutput: "",
        standardError:
          "{\"code\":\"QRSCANNER_CLI_INTERNAL_ERROR\",\"message\":\"Failed to encode CLI error output.\"}\n",
        exitCode: CLIExitCode.software
      )
    }
  }

  private static func encode<T: Encodable>(_ value: T, pretty: Bool) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
    let data = try encoder.encode(value)
    guard let output = String(data: data, encoding: .utf8) else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: [], debugDescription: "JSON output was not valid UTF-8.")
      )
    }
    return "\(output)\n"
  }

  private static func exitCode(for error: ScanError) -> Int32 {
    switch error {
    case .cameraPermissionDenied, .cameraRestricted, .screenPermissionDenied:
      CLIExitCode.noPermission
    case .clipboardHasNoImage, .noQRCodeFound:
      CLIExitCode.noInput
    case .cameraUnavailable, .cameraConfigurationFailed, .cameraInterrupted, .screenUnavailable:
      CLIExitCode.unavailable
    case .imageConversionFailed:
      CLIExitCode.dataError
    case .cameraCancelled:
      CLIExitCode.cancelled
    }
  }
}
