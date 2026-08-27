import CoreGraphics
import CoreMedia
import Vision

enum QRDecoder {
  static func decode(cgImage: CGImage) throws -> [String] {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
    try handler.perform([request])

    return (request.results ?? []).compactMap(\.payloadStringValue)
  }

  static func decode(sampleBuffer: CMSampleBuffer) throws -> [String] {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]

    let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
    try handler.perform([request])

    return (request.results ?? []).compactMap(\.payloadStringValue)
  }
}
