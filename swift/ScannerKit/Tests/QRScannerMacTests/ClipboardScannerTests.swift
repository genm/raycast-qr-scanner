import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import QRScannerCore
import XCTest
@testable import QRScannerMac

@MainActor
final class ClipboardScannerTests: XCTestCase {
  func testThrowsWhenPasteboardIsEmpty() {
    let pasteboard = NSPasteboard(name: .init("test-empty-\(UUID().uuidString)"))
    pasteboard.clearContents()

    XCTAssertThrowsError(try ClipboardScanner.scan(pasteboard: pasteboard)) { error in
      XCTAssertEqual(error as? ScanError, .clipboardHasNoImage)
    }
  }

  func testThrowsWhenPasteboardContainsNonImageFileURL() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let textFileURL = temporaryDirectory.appendingPathComponent("note.txt")
    try "hello world".write(to: textFileURL, atomically: true, encoding: .utf8)

    let pasteboard = NSPasteboard(name: .init("test-text-file-\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([textFileURL as NSURL])

    XCTAssertThrowsError(try ClipboardScanner.scan(pasteboard: pasteboard)) { error in
      XCTAssertEqual(error as? ScanError, .clipboardHasNoImage)
    }
  }

  func testThrowsWhenImageContainsNoQRCode() throws {
    let size = NSSize(width: 200, height: 200)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.white.setFill()
      rect.fill()
      return true
    }

    let pasteboard = NSPasteboard(name: .init("test-no-qr-\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([image])

    XCTAssertThrowsError(try ClipboardScanner.scan(pasteboard: pasteboard)) { error in
      XCTAssertEqual(error as? ScanError, .noQRCodeFound)
    }
  }

  func testDecodesDirectImageFromPasteboard() throws {
    let message = "https://example.test/clipboard-direct"
    let cgImage = try makeQRCode(message: message)
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

    let pasteboard = NSPasteboard(name: .init("test-direct-image-\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([nsImage])

    let results = try ClipboardScanner.scan(pasteboard: pasteboard)
    XCTAssertEqual(results, [ScanResult(value: message, source: .clipboard)])
  }

  func testDecodesImageFromCopiedFileURL() throws {
    let message = "https://example.test/clipboard-file-url"
    let cgImage = try makeQRCode(message: message)

    let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let imageFileURL = temporaryDirectory.appendingPathComponent("qrcode.png")
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    let pngData = try XCTUnwrap(bitmapRep.representation(using: .png, properties: [:]))
    try pngData.write(to: imageFileURL)

    let pasteboard = NSPasteboard(name: .init("test-file-url-\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([imageFileURL as NSURL])

    let results = try ClipboardScanner.scan(pasteboard: pasteboard)
    XCTAssertEqual(results, [ScanResult(value: message, source: .clipboard)])
  }

  private func makeQRCode(message: String) throws -> CGImage {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(message.utf8)
    filter.correctionLevel = "M"

    let context = CIContext(options: [.useSoftwareRenderer: true])
    let image = try XCTUnwrap(filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)))
    return try XCTUnwrap(context.createCGImage(image, from: image.extent))
  }
}
