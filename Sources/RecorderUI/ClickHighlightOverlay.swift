import AppKit
import CoreGraphics
import OSLog
import QuartzCore

/// Floats one transparent, mouse-passthrough panel over each display and
/// renders a ripple at every click. Window IDs are exposed so the recorder's
/// SCContentFilter can except them, letting the highlights appear in display /
/// region captures.
@MainActor
public final class ClickHighlightController: ObservableObject {

    @Published public private(set) var isVisible: Bool = false
    @Published public var color: NSColor = .systemBlue
    @Published public var rippleSize: CGFloat = 70

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "ClickHighlight")
    private var panels: [ClickHighlightPanel] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?

    public init() {}

    public var windowIDs: [CGWindowID] {
        panels.map { CGWindowID($0.windowNumber) }
    }

    public func show() {
        guard !isVisible else { return }
        panels = NSScreen.screens.map { screen in
            let p = ClickHighlightPanel(screen: screen)
            p.orderFront(nil)
            return p
        }
        installMonitors()
        isVisible = true
    }

    public func hide() {
        removeMonitors()
        for p in panels { p.orderOut(nil) }
        panels.removeAll()
        isVisible = false
    }

    // MARK: - Mouse monitoring

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.spawnRipple(globalLocation: NSEvent.mouseLocation, button: event.type) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.spawnRipple(globalLocation: NSEvent.mouseLocation, button: event.type) }
            return event
        }
    }

    private func removeMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor  { NSEvent.removeMonitor(l) }
        globalMonitor = nil; localMonitor = nil
    }

    private func spawnRipple(globalLocation: NSPoint, button: NSEvent.EventType) {
        guard let panel = panels.first(where: { $0.frame.contains(globalLocation) }) else { return }
        let local = panel.convertPoint(fromScreen: globalLocation)
        let tint: NSColor
        switch button {
        case .rightMouseDown:  tint = .systemRed
        case .otherMouseDown:  tint = .systemYellow
        default:               tint = color
        }
        panel.spawnRipple(at: local, color: tint, diameter: rippleSize)
    }
}

// MARK: - Panel

private final class ClickHighlightPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        self.contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func spawnRipple(at point: CGPoint, color: NSColor, diameter: CGFloat) {
        guard let host = contentView?.layer else { return }
        let radius = diameter / 2
        let circle = CAShapeLayer()
        circle.frame = CGRect(x: point.x - radius, y: point.y - radius, width: diameter, height: diameter)
        circle.path = CGPath(ellipseIn: CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter)), transform: nil)
        circle.fillColor = color.withAlphaComponent(0.35).cgColor
        circle.strokeColor = color.withAlphaComponent(0.9).cgColor
        circle.lineWidth = 3
        host.addSublayer(circle)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.5
        scale.toValue = 1.6

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.55
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        circle.add(group, forKey: "ripple")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            circle.removeFromSuperlayer()
        }
    }
}
