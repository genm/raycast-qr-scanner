import CoreGraphics
import CoreMedia
import ImageIO
import Vision

struct DetectedQRCode: Equatable, Sendable {
  let value: String
  let boundingBox: CGRect
}

enum QRDecoder {
  static func decode(cgImage: CGImage) throws -> [String] {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
    try handler.perform([request])

    return (request.results ?? []).compactMap(\.payloadStringValue)
  }

  static func decode(
    sampleBuffer: CMSampleBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> [String] {
    try detect(sampleBuffer: sampleBuffer, orientation: orientation).map(\.value)
  }

  static func detect(
    sampleBuffer: CMSampleBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> [DetectedQRCode] {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]

    let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: orientation)
    try handler.perform([request])

    return (request.results ?? []).compactMap { observation in
      guard let value = observation.payloadStringValue else { return nil }
      return DetectedQRCode(value: value, boundingBox: observation.boundingBox)
    }
  }
}
