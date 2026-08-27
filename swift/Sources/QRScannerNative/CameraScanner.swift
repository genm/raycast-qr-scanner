import AppKit
@preconcurrency import AVFoundation
import CoreFoundation
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
  static func scan(
    sampleBuffer: CMSampleBuffer,
    orientation: CGImagePropertyOrientation = .up
  ) throws -> [ScanResult] {
    try QRDecoder.decode(sampleBuffer: sampleBuffer, orientation: orientation)
      .map { ScanResult(value: $0, source: .camera) }
  }
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

private final class CameraFrameDeliveryState: @unchecked Sendable {
  private let lock = NSLock()
  private var receivedFirstFrame = false

  func markFrameReceived() -> Bool {
    lock.withLock {
      guard !receivedFirstFrame else { return false }
      receivedFirstFrame = true
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
  private let frameDeliveryState = CameraFrameDeliveryState()
  private var panel: NSPanel?
  private weak var instructionLabel: NSTextField?
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
    application.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)

    sessionQueue.async { [session] in
      CameraDiagnostics.logger.info("Starting camera capture session")
      session.startRunning()
    }
  }

  private func makePanel(previewing session: AVCaptureSession) -> NSPanel {
    let panel = NSPanel(
      contentRect: CGRect(x: 0, y: 0, width: 560, height: 420),
      styleMask: [.titled, .closable, .miniaturizable],
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
    if frameDeliveryState.markFrameReceived() {
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
      let results = try CameraFrameProcessor.scan(sampleBuffer: sampleBuffer, orientation: orientation)
      guard !results.isEmpty else { return }
      CameraDiagnostics.logger.info("Detected \(results.count) QR code(s)")
      performOnMainRunLoop { [weak self] in
        self?.finish(.success(results))
      }
    } catch {
      CameraDiagnostics.logger.error("Vision failed to process a camera frame: \(String(describing: error))")
      performOnMainRunLoop { [weak self] in
        self?.finish(.failure(ScanError.imageConversionFailed))
      }
    }
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
