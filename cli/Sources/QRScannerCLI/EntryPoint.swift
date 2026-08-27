import Darwin
import Foundation

@main
struct QRScannerCLIEntryPoint {
  static func main() async {
    let execution = await CLIApplication.run(arguments: Array(CommandLine.arguments.dropFirst()))
    write(execution.standardOutput, to: .standardOutput)
    write(execution.standardError, to: .standardError)
    exit(execution.exitCode)
  }

  private static func write(_ value: String, to handle: FileHandle) {
    guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
    handle.write(data)
  }
}
