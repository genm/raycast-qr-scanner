import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import CoreMedia
import CoreVideo
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

  func testDecodesQRCodeFromCameraSampleBuffer() throws {
    let message = "https://example.test/from-camera-frame"
    let qrCode = try makeQRCode(message: message)
    let sampleBuffer = try makeCameraSampleBuffer(qrCode: qrCode, width: 1_280, height: 720)

    XCTAssertEqual(
      try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer),
      [ScanResult(value: message, source: .camera)]
    )
  }

  func testCameraPipelineDecodesRotatedQRCodes() throws {
    let message = "https://example.test/rotated-camera-frame"
    let qrCode = try makeQRCode(message: message)

    for rotationDegrees in [0.0, 90.0, 180.0, 270.0] {
      let sampleBuffer = try makeCameraSampleBuffer(
        qrCode: qrCode,
        width: 1_280,
        height: 720,
        rotationDegrees: rotationDegrees
      )

      XCTAssertEqual(
        try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer),
        [ScanResult(value: message, source: .camera)],
        "rotation=\(Int(rotationDegrees))"
      )
    }
  }

  func testCameraPipelineDecodesMirroredQRCodeWhenConnectionReportsMirroring() throws {
    let message = "https://example.test/mirrored-camera-frame"
    let sampleBuffer = try makeCameraSampleBuffer(
      qrCode: makeQRCode(message: message),
      width: 1_280,
      height: 720,
      mirrored: true
    )

    XCTAssertEqual(
      try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer, orientation: .upMirrored),
      [ScanResult(value: message, source: .camera)]
    )
  }

  func testCameraPipelineDecodesQRCodesAcrossDistances() throws {
    let message = "https://example.test/camera-distance"
    let qrCode = try makeQRCode(message: message)

    for frameRatio in [0.12, 0.25, 0.5] {
      let sampleBuffer = try makeCameraSampleBuffer(
        qrCode: qrCode,
        width: 1_280,
        height: 720,
        qrFrameRatio: frameRatio
      )

      XCTAssertEqual(
        try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer),
        [ScanResult(value: message, source: .camera)],
        "frame-ratio=\(frameRatio)"
      )
    }
  }

  func testCameraPipelineReturnsNoResultsForFrameWithoutQRCode() throws {
    let sampleBuffer = try makeCameraSampleBuffer(qrCode: nil, width: 1_280, height: 720)

    XCTAssertEqual(try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer), [])
  }

  private func makeQRCode(message: String) throws -> CGImage {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(message.utf8)
    filter.correctionLevel = "M"

    let context = CIContext(options: [.useSoftwareRenderer: true])
    let image = try XCTUnwrap(filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)))
    return try XCTUnwrap(context.createCGImage(image, from: image.extent))
  }

  private func makeCameraSampleBuffer(
    qrCode: CGImage?,
    width: Int,
    height: Int,
    qrFrameRatio: CGFloat = 0.5,
    rotationDegrees: CGFloat = 0,
    mirrored: Bool = false
  ) throws -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes: CFDictionary = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary
    XCTAssertEqual(
      CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        attributes,
        &pixelBuffer
      ),
      kCVReturnSuccess
    )
    let buffer = try XCTUnwrap(pixelBuffer)

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let context = try XCTUnwrap(
      CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      )
    )
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    if let qrCode {
      let qrSize = CGFloat(min(width, height)) * qrFrameRatio
      context.interpolationQuality = .none
      context.saveGState()
      context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
      context.rotate(by: rotationDegrees * .pi / 180)
      if mirrored {
        context.scaleBy(x: -1, y: 1)
      }
      context.draw(qrCode, in: CGRect(x: -qrSize / 2, y: -qrSize / 2, width: qrSize, height: qrSize))
      context.restoreGState()
    }

    var formatDescription: CMVideoFormatDescription?
    XCTAssertEqual(
      CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: buffer,
        formatDescriptionOut: &formatDescription
      ),
      noErr
    )
    var timing = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: 30),
      presentationTimeStamp: .zero,
      decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    XCTAssertEqual(
      CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: buffer,
        formatDescription: try XCTUnwrap(formatDescription),
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
      ),
      noErr
    )
    return try XCTUnwrap(sampleBuffer)
  }
}
