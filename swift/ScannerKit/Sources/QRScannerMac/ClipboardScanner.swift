import AppKit
import QRScannerCore

@MainActor
public enum ClipboardScanner {
  public static func scan() throws -> [ScanResult] {
    guard let images = NSPasteboard.general.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty else {
      throw ScanError.clipboardHasNoImage
    }

    let values = try images.flatMap { image -> [String] in
      guard let cgImage = image.qrScannerCGImage else {
        throw ScanError.imageConversionFailed
      }
      return try QRDecoder.decode(cgImage: cgImage)
    }

    guard !values.isEmpty else {
      throw ScanError.noQRCodeFound
    }

    return values.map { ScanResult(value: $0, source: .clipboard) }
  }
}

private extension NSImage {
  var qrScannerCGImage: CGImage? {
    var rect = CGRect(origin: .zero, size: size)
    return cgImage(forProposedRect: &rect, context: nil, hints: nil)
  }
}
