import AppKit
import QRScannerCore

@MainActor
public enum ClipboardScanner {
  public static func scan() throws -> [ScanResult] {
    try scan(pasteboard: .general)
  }

  static func scan(pasteboard: NSPasteboard) throws -> [ScanResult] {
    let images = loadImages(from: pasteboard)
    guard !images.isEmpty else {
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

  static func loadImages(from pasteboard: NSPasteboard) -> [NSImage] {
    if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty {
      return images
    }

    if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
      let fileImages = urls.compactMap { url -> NSImage? in
        guard url.isFileURL else { return nil }
        return NSImage(contentsOf: url)
      }
      if !fileImages.isEmpty {
        return fileImages
      }
    }

    return []
  }
}

private extension NSImage {
  var qrScannerCGImage: CGImage? {
    var rect = CGRect(origin: .zero, size: size)
    return cgImage(forProposedRect: &rect, context: nil, hints: nil)
  }
}
