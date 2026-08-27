import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import XCTest
@testable import QRScannerNative

final class QRDecoderTests: XCTestCase {
  func testDecodesGeneratedQRCode() throws {
    let message = "https://example.test/from-generated-qr"
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(message.utf8)
    filter.correctionLevel = "M"

    let context = CIContext(options: [.useSoftwareRenderer: true])
    let image = try XCTUnwrap(filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)))
    let cgImage = try XCTUnwrap(context.createCGImage(image, from: image.extent))

    XCTAssertEqual(try QRDecoder.decode(cgImage: cgImage), [message])
  }

  func testReturnsNoResultsForImageWithoutQRCode() throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: 640,
        height: 480,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))

    XCTAssertEqual(try QRDecoder.decode(cgImage: try XCTUnwrap(context.makeImage())), [])
  }
}
