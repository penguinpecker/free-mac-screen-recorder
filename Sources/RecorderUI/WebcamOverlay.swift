import AVFoundation
import AppKit
import CoreGraphics
import OSLog
import QuartzCore

/// Position of the webcam overlay on the chosen display.
public enum WebcamCorner: String, CaseIterable, Identifiable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

/// One of three preset sizes for the webcam picture-in-picture window.
public enum WebcamSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large
    public var id: String { rawValue }
    public var pixels: CGSize {
        switch self {
        case .small:  return CGSize(width: 160, height: 160)
        case .medium: return CGSize(width: 220, height: 220)
        case .large:  return CGSize(width: 300, height: 300)
        }
    }
    public var displayName: String { rawValue.capitalized }
}

/// A floating, rounded, draggable picture-in-picture preview of a chosen
/// `AVCaptureDevice`. Lives independently of the recording lifecycle — the
/// recorder asks for `windowID` and excepts it from its SCContentFilter so the
/// overlay appears in display / region captures.
@MainActor
public final class WebcamOverlayController: ObservableObject {

    @Published public private(set) var isVisible: Bool = false
    @Published public var corner: WebcamCorner = .bottomRight {
        didSet { reposition() }
    }
    @Published public var size: WebcamSize = .medium {
        didSet { reposition() }
    }

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "Webcam")
    private let captureSession = AVCaptureSession()
    private var window: WebcamPanel?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDeviceID: String?

    public init() {}

    /// CGWindowID of the overlay panel — used by SCContentFilter exceptions.
    public var windowID: CGWindowID? {
        guard let w = window else { return nil }
        return CGWindowID(w.windowNumber)
    }

    public func show(deviceID: String) throws {
        try configureSession(deviceID: deviceID)
        if window == nil {
            let panel = makePanel()
            self.window = panel
            attachPreviewLayer(to: panel)
        }
        currentDeviceID = deviceID
        captureSession.startRunning()
        reposition()
        window?.orderFront(nil)
        isVisible = true
        log.info("Webcam overlay shown")
    }

    public func hide() {
        captureSession.stopRunning()
        window?.orderOut(nil)
        isVisible = false
    }

    public func setDevice(_ deviceID: String) throws {
        try configureSession(deviceID: deviceID)
        currentDeviceID = deviceID
    }

    // MARK: - Internals

    private func configureSession(deviceID: String) throws {
        guard let device = AVCaptureDevice(uniqueID: deviceID) else {
            throw NSError(domain: "Webcam", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Camera not found"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canSetSessionPreset(.medium) { captureSession.sessionPreset = .medium }
        captureSession.commitConfiguration()
    }

    private func makePanel() -> WebcamPanel {
        let frame = NSRect(origin: .zero, size: size.pixels)
        let panel = WebcamPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let host = NSView(frame: frame)
        host.wantsLayer = true
        host.layer?.cornerRadius = min(frame.width, frame.height) / 2  // circular
        host.layer?.masksToBounds = true
        host.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        host.layer?.borderWidth = 2
        panel.contentView = host
        return panel
    }

    private func attachPreviewLayer(to panel: WebcamPanel) {
        guard let host = panel.contentView else { return }
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = host.bounds
        layer.cornerRadius = min(host.bounds.width, host.bounds.height) / 2
        layer.masksToBounds = true
        host.layer?.addSublayer(layer)
        previewLayer = layer
    }

    private func reposition() {
        guard let panel = window, let screen = NSScreen.main else { return }
        let target = size.pixels
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 24
        let origin: NSPoint
        switch corner {
        case .topLeft:
            origin = NSPoint(
                x: visibleFrame.minX + margin,
                y: visibleFrame.maxY - target.height - margin
            )
        case .topRight:
            origin = NSPoint(
                x: visibleFrame.maxX - target.width - margin,
                y: visibleFrame.maxY - target.height - margin
            )
        case .bottomLeft:
            origin = NSPoint(
                x: visibleFrame.minX + margin,
                y: visibleFrame.minY + margin
            )
        case .bottomRight:
            origin = NSPoint(
                x: visibleFrame.maxX - target.width - margin,
                y: visibleFrame.minY + margin
            )
        }
        panel.setFrame(NSRect(origin: origin, size: target), display: true, animate: false)
        // Resize host + preview layer to match new size and keep it circular.
        if let host = panel.contentView {
            host.frame = NSRect(origin: .zero, size: target)
            host.layer?.cornerRadius = min(target.width, target.height) / 2
            previewLayer?.frame = host.bounds
            previewLayer?.cornerRadius = host.layer?.cornerRadius ?? 0
        }
    }
}

/// NSPanel subclass so the window can become key for keyboard input but
/// doesn't activate the app — we want the underlying app to keep focus.
private final class WebcamPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
