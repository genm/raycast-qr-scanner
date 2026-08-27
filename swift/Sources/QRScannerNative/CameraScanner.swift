import AppKit
@preconcurrency import AVFoundation
import CoreFoundation
import CoreImage
import ImageIO
import OSLog
import QuartzCore

enum CameraScanner {
  static func scan() async throws -> [ScanResult] {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      break
    case .notDetermined:
      guard await AVCaptureDevice.requestAccess(for: .video) else {
        throw ScanError.cameraPermissionDenied
      }
    case .denied:
      throw ScanError.cameraPermissionDenied
    case .restricted:
      throw ScanError.cameraRestricted
    @unknown default:
      throw ScanError.cameraPermissionDenied
    }

    return try await CameraScanController.run()
  }
}

enum CameraFrameProcessor {
  private static let imageContext = CIContext(options: [.cacheIntermediates: false])

  struct Detection: Equatable, Sendable {
    let result: ScanResult
    let boundingBox: CGRect
  }

  static func scan(
    sampleBuffer: CMSampleBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> [ScanResult] {
    try detect(sampleBuffer: sampleBuffer, orientation: orientation).map(\.result)
  }

  static func detect(
    sampleBuffer: CMSampleBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> [Detection] {
    try QRDecoder.detect(sampleBuffer: sampleBuffer, orientation: orientation).map {
      Detection(result: ScanResult(value: $0.value, source: .camera), boundingBox: $0.boundingBox)
    }
  }

  static func makeFrozenFrame(sampleBuffer: CMSampleBuffer) -> CGImage? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    let image = CIImage(cvPixelBuffer: imageBuffer)
    return imageContext.createCGImage(image, from: image.extent)
  }
}

enum CameraOverlayGeometry {
  static func rect(
    for visionBounds: CGRect,
    imageSize: CGSize,
    in destinationBounds: CGRect,
    destinationIsFlipped: Bool = false
  ) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0,
          destinationBounds.width > 0, destinationBounds.height > 0
    else { return .null }

    let scale = max(
      destinationBounds.width / imageSize.width,
      destinationBounds.height / imageSize.height
    )
    let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let displayedOrigin = CGPoint(
      x: destinationBounds.midX - displayedSize.width / 2,
      y: destinationBounds.midY - displayedSize.height / 2
    )

    // Vision uses a lower-left origin. Convert only when AppKit reports a flipped destination layer.
    var rect = CGRect(
      x: displayedOrigin.x + visionBounds.minX * displayedSize.width,
      y: displayedOrigin.y + visionBounds.minY * displayedSize.height,
      width: visionBounds.width * displayedSize.width,
      height: visionBounds.height * displayedSize.height
    )
    if destinationIsFlipped {
      rect.origin.y = destinationBounds.minY + destinationBounds.maxY - rect.maxY
    }
    return rect
  }
}

enum CameraPanelPresentation {
  // A nonactivating panel keeps Raycast's view command alive so it can render the returned scan results.
  static let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .nonactivatingPanel]
}

private enum CameraDiagnostics {
  static let logger = Logger(subsystem: "com.genm.qr-scanner", category: "camera")
}

// The nested AppKit run loop occupies its main-dispatch block, so enqueue UI work on the run loop itself.
private func performOnMainRunLoop(_ action: @escaping @MainActor () -> Void) {
  let mainRunLoop = CFRunLoopGetMain()
  CFRunLoopPerformBlock(mainRunLoop, CFRunLoopMode.commonModes.rawValue) {
    MainActor.assumeIsolated {
      action()
    }
  }
  CFRunLoopWakeUp(mainRunLoop)
}

private final class CameraFrameState: @unchecked Sendable {
  private let lock = NSLock()
  private var receivedFirstFrame = false
  private var detectedQRCode = false

  func markFrameReceived() -> Bool {
    lock.withLock {
      guard !receivedFirstFrame else { return false }
      receivedFirstFrame = true
      return true
    }
  }

  func claimDetection() -> Bool {
    lock.withLock {
      guard !detectedQRCode else { return false }
      detectedQRCode = true
      return true
    }
  }
}

@MainActor
private final class CameraScanController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, NSWindowDelegate {
  private static var activeController: CameraScanController?

  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.genm.qr-scanner.camera-session")
  private let metadataQueue = DispatchQueue(label: "com.genm.qr-scanner.camera-metadata")
  private let frameState = CameraFrameState()
  private var panel: NSPanel?
  private weak var instructionLabel: NSTextField?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var frozenFrameLayer: CALayer?
  private var successLayers: [CAShapeLayer] = []
  private var successTimer: Timer?
  private var notificationTokens: [NSObjectProtocol] = []
  private var continuation: CheckedContinuation<[ScanResult], Error>?
  private var didFinish = false
  private var isApplicationRunLoopRunning = false

  static func run() async throws -> [ScanResult] {
    guard activeController == nil else {
      throw ScanError.cameraConfigurationFailed
    }

    let controller = CameraScanController()
    activeController = controller
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        controller.continuation = continuation
        do {
          try controller.start()
          controller.isApplicationRunLoopRunning = true
          NSApplication.shared.run()
          controller.isApplicationRunLoopRunning = false
          if !controller.didFinish {
            controller.finish(.failure(ScanError.cameraCancelled))
          }
        } catch {
          controller.finish(.failure(error))
        }
      }
    } onCancel: {
      performOnMainRunLoop {
        activeController?.finish(.failure(CancellationError()))
      }
    }
  }

  private func start() throws {
    guard let camera = AVCaptureDevice.default(for: .video) else {
      throw ScanError.cameraUnavailable
    }

    let input = try AVCaptureDeviceInput(device: camera)
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.alwaysDiscardsLateVideoFrames = true
    // Keep production frames identical to the BGRA CMSampleBuffer exercised in hosted CI.
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]
    videoOutput.setSampleBufferDelegate(self, queue: metadataQueue)

    session.beginConfiguration()
    guard session.canAddInput(input), session.canAddOutput(videoOutput) else {
      session.commitConfiguration()
      throw ScanError.cameraConfigurationFailed
    }
    session.addInput(input)
    session.addOutput(videoOutput)
    if let connection = videoOutput.connection(with: .video), connection.isVideoMirroringSupported {
      // Vision needs the actual QR module layout; an automatically mirrored camera frame is no longer decodable.
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = false
    }
    session.commitConfiguration()

    let notificationCenter = NotificationCenter.default
    notificationTokens.append(notificationCenter.addObserver(
      forName: .AVCaptureSessionRuntimeError,
      object: session,
      queue: nil
    ) { [weak self] _ in
      CameraDiagnostics.logger.error("Camera capture session reported a runtime error")
      performOnMainRunLoop { [weak self] in
        self?.finish(.failure(ScanError.cameraConfigurationFailed))
      }
    })
    notificationTokens.append(notificationCenter.addObserver(
      forName: .AVCaptureSessionWasInterrupted,
      object: session,
      queue: nil
    ) { [weak self] _ in
      CameraDiagnostics.logger.error("Camera capture session was interrupted")
      performOnMainRunLoop { [weak self] in
        self?.finish(.failure(ScanError.cameraInterrupted))
      }
    })

    let panel = makePanel(previewing: session)
    self.panel = panel
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    panel.orderFrontRegardless()

    sessionQueue.async { [session] in
      CameraDiagnostics.logger.info("Starting camera capture session")
      session.startRunning()
    }
  }

  private func makePanel(previewing session: AVCaptureSession) -> NSPanel {
    let panel = NSPanel(
      contentRect: CGRect(x: 0, y: 0, width: 560, height: 420),
      styleMask: CameraPanelPresentation.styleMask,
      backing: .buffered,
      defer: false
    )
    panel.title = "Scan QR Code"
    panel.level = .floating
    // Raycast or another app may become active while the user positions a QR code; keep the preview visible.
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.delegate = self
    panel.center()

    guard let contentView = panel.contentView else { return panel }
    contentView.wantsLayer = true

    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.frame = contentView.bounds
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    contentView.layer = previewLayer
    self.previewLayer = previewLayer

    let instruction = NSTextField(labelWithString: "Hold a QR code in front of the camera")
    instruction.alignment = .center
    instruction.textColor = .white
    instruction.backgroundColor = NSColor.black.withAlphaComponent(0.65)
    instruction.drawsBackground = true
    instruction.translatesAutoresizingMaskIntoConstraints = false
    instructionLabel = instruction
    contentView.addSubview(instruction)
    NSLayoutConstraint.activate([
      instruction.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
      instruction.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
      instruction.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
      instruction.heightAnchor.constraint(equalToConstant: 32),
    ])

    return panel
  }

  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    if frameState.markFrameReceived() {
      if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
        CameraDiagnostics.logger.info(
          "Received first camera frame: width=\(width), height=\(height), pixelFormat=\(pixelFormat)"
        )
      } else {
        CameraDiagnostics.logger.error("Received camera sample without an image buffer")
      }
      performOnMainRunLoop { [weak self] in
        self?.instructionLabel?.stringValue = "Camera active — looking for QR code…"
      }
    }

    let orientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up
    do {
      let detections = try CameraFrameProcessor.detect(sampleBuffer: sampleBuffer, orientation: orientation)
      guard !detections.isEmpty, frameState.claimDetection() else { return }
      let frozenFrame = CameraFrameProcessor.makeFrozenFrame(sampleBuffer: sampleBuffer)
      let frameSize = CMSampleBufferGetImageBuffer(sampleBuffer).map {
        CGSize(width: CVPixelBufferGetWidth($0), height: CVPixelBufferGetHeight($0))
      } ?? .zero
      CameraDiagnostics.logger.info("Detected \(detections.count) QR code(s)")
      performOnMainRunLoop { [weak self] in
        self?.showDetectionSuccess(detections, frozenFrame: frozenFrame, frameSize: frameSize)
      }
    } catch {
      CameraDiagnostics.logger.error("Vision failed to process a camera frame: \(String(describing: error))")
      performOnMainRunLoop { [weak self] in
        self?.finish(.failure(ScanError.imageConversionFailed))
      }
    }
  }

  private func showDetectionSuccess(
    _ detections: [CameraFrameProcessor.Detection],
    frozenFrame: CGImage?,
    frameSize: CGSize
  ) {
    guard !didFinish, let previewLayer else { return }

    instructionLabel?.stringValue = detections.count == 1 ? "QR code detected" : "\(detections.count) QR codes detected"
    instructionLabel?.textColor = NSColor(calibratedRed: 0.7, green: 0.95, blue: 1, alpha: 1)
    instructionLabel?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.28, alpha: 0.82)

    if let frozenFrame {
      let layer = CALayer()
      layer.frame = previewLayer.bounds
      layer.contents = frozenFrame
      layer.contentsGravity = .resizeAspectFill
      layer.masksToBounds = true
      layer.zPosition = 5
      previewLayer.addSublayer(layer)
      frozenFrameLayer = layer
    }

    sessionQueue.async { [session] in
      if session.isRunning {
        session.stopRunning()
      }
    }

    successLayers = detections.map { detection in
      let detectedRect = CameraOverlayGeometry.rect(
        for: detection.boundingBox,
        imageSize: frameSize,
        in: previewLayer.bounds,
        destinationIsFlipped: previewLayer.isGeometryFlipped
      )
        .insetBy(dx: -7, dy: -7)
        .intersection(previewLayer.bounds)
      let highlight = CAShapeLayer()
      highlight.path = CGPath(roundedRect: detectedRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
      highlight.fillColor = NSColor.systemCyan.withAlphaComponent(0.08).cgColor
      highlight.strokeColor = NSColor(calibratedRed: 0.65, green: 0.95, blue: 1, alpha: 1).cgColor
      highlight.lineWidth = 4
      highlight.shadowColor = NSColor.systemCyan.cgColor
      highlight.shadowOpacity = 1
      highlight.shadowRadius = 12
      highlight.zPosition = 20
      previewLayer.addSublayer(highlight)

      let pulse = CABasicAnimation(keyPath: "opacity")
      pulse.fromValue = 0.35
      pulse.toValue = 1
      pulse.duration = 0.16
      pulse.autoreverses = true
      pulse.repeatCount = 1
      highlight.add(pulse, forKey: "successPulse")
      return highlight
    }

    let results = detections.map(\.result)
    let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.finish(.success(results))
      }
    }
    successTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func windowWillClose(_ notification: Notification) {
    finish(.failure(ScanError.cameraCancelled))
  }

  private func finish(_ result: Result<[ScanResult], Error>) {
    guard !didFinish else { return }
    didFinish = true
    switch result {
    case let .success(results):
      CameraDiagnostics.logger.info("Finishing camera scan with \(results.count) result(s)")
    case let .failure(error):
      CameraDiagnostics.logger.error("Finishing camera scan with error: \(String(describing: error))")
    }

    let continuation = continuation
    self.continuation = nil
    let panel = panel
    self.panel = nil
    instructionLabel = nil
    successTimer?.invalidate()
    successTimer = nil
    successLayers.forEach { $0.removeFromSuperlayer() }
    successLayers.removeAll()
    frozenFrameLayer?.removeFromSuperlayer()
    frozenFrameLayer = nil
    previewLayer = nil
    panel?.delegate = nil
    panel?.orderOut(nil)
    notificationTokens.forEach(NotificationCenter.default.removeObserver)
    notificationTokens.removeAll()

    sessionQueue.async { [session] in
      if session.isRunning {
        session.stopRunning()
      }
    }

    Self.activeController = nil
    stopApplicationRunLoop()
    continuation?.resume(with: result)
  }

  private func stopApplicationRunLoop() {
    // Camera setup can fail before AppKit is initialized; never touch the NSApp IUO on that path.
    guard isApplicationRunLoopRunning else { return }
    let application = NSApplication.shared
    guard application.isRunning else {
      isApplicationRunLoopRunning = false
      return
    }
    application.stop(nil)
    if let wakeEvent = NSEvent.otherEvent(
      with: .applicationDefined,
      location: .zero,
      modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: 0,
      context: nil,
      subtype: 0,
      data1: 0,
      data2: 0
    ) {
      application.postEvent(wakeEvent, atStart: false)
    }
  }
}
