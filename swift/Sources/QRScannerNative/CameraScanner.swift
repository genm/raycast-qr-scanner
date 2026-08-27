import AppKit
@preconcurrency import AVFoundation
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

@MainActor
private final class CameraScanController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, NSWindowDelegate {
  private static var activeController: CameraScanController?

  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.genm.qr-scanner.camera-session")
  private let metadataQueue = DispatchQueue(label: "com.genm.qr-scanner.camera-metadata")
  private var panel: NSPanel?
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
      Task { @MainActor in
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
    videoOutput.setSampleBufferDelegate(self, queue: metadataQueue)

    session.beginConfiguration()
    guard session.canAddInput(input), session.canAddOutput(videoOutput) else {
      session.commitConfiguration()
      throw ScanError.cameraConfigurationFailed
    }
    session.addInput(input)
    session.addOutput(videoOutput)
    session.commitConfiguration()

    let notificationCenter = NotificationCenter.default
    notificationTokens.append(notificationCenter.addObserver(
      forName: .AVCaptureSessionRuntimeError,
      object: session,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.finish(.failure(ScanError.cameraConfigurationFailed))
      }
    })
    notificationTokens.append(notificationCenter.addObserver(
      forName: .AVCaptureSessionWasInterrupted,
      object: session,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
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
    let result = Result { try QRDecoder.decode(sampleBuffer: sampleBuffer) }

    Task { @MainActor [weak self] in
      switch result {
      case let .success(values) where !values.isEmpty:
        self?.finish(.success(values.map { ScanResult(value: $0, source: .camera) }))
      case .success:
        break
      case let .failure(error):
        self?.finish(.failure(error))
      }
    }
  }

  func windowWillClose(_ notification: Notification) {
    finish(.failure(ScanError.cameraCancelled))
  }

  private func finish(_ result: Result<[ScanResult], Error>) {
    guard !didFinish else { return }
    didFinish = true

    let continuation = continuation
    self.continuation = nil
    let panel = panel
    self.panel = nil
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
