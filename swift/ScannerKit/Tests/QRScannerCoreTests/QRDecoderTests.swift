import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import QRScannerCore
import XCTest

final class QRDecoderTests: XCTestCase {
  func testDecodesGeneratedQRCode() throws {
    let message = "https://example.test/from-generated-qr"

    XCTAssertEqual(try QRDecoder.decode(cgImage: makeQRCode(message: message)), [message])
  }

  func testDecodesFidoHybridQRCode() throws {
    let message =
      "FIDO:/333536986729023101900514898282206507478832499810394616328939171432525164832007214567361368903544184100030234061231042500070214287790524650362650854032130107096654083076"

    XCTAssertEqual(try QRDecoder.decode(cgImage: makeQRCode(message: message)), [message])
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

  private func makeQRCode(message: String) throws -> CGImage {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(message.utf8)
    filter.correctionLevel = "M"

    let context = CIContext(options: [.useSoftwareRenderer: true])
    let image = try XCTUnwrap(filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)))
    return try XCTUnwrap(context.createCGImage(image, from: image.extent))
  }
}
