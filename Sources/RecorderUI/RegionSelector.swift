import AppKit
import CoreGraphics
import Foundation
import OSLog

/// The result of a region pick: a rect in display-points (top-left origin, the
/// coordinate system `SCStreamConfiguration.sourceRect` expects) plus the
/// `CGDirectDisplayID` of the screen the user dragged on.
public struct RegionSelection: Sendable, Hashable {
    public let displayID: CGDirectDisplayID
    public let rect: CGRect             // in display points, top-down origin
    public var size: CGSize { rect.size }
}

/// Presents a translucent borderless overlay across every screen and resolves
/// to a `RegionSelection` when the user finishes a drag (or `nil` on Escape).
@MainActor
public final class RegionSelector {
    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "RegionSelector")
    private var overlays: [RegionOverlayWindow] = []
    private var continuation: CheckedContinuation<RegionSelection?, Never>?

    public init() {}

    public func present() async -> RegionSelection? {
        await withCheckedContinuation { (cont: CheckedContinuation<RegionSelection?, Never>) in
            self.continuation = cont
            self.showOverlays()
        }
    }

    private func showOverlays() {
        overlays = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.cg_displayID else { return nil }
            let panel = RegionOverlayWindow(screen: screen, displayID: displayID, owner: self)
            panel.makeKeyAndOrderFront(nil)
            return panel
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func finish(with selection: RegionSelection?) {
        let cont = self.continuation
        self.continuation = nil
        for w in overlays { w.orderOut(nil) }
        overlays.removeAll()
        cont?.resume(returning: selection)
    }
}

// MARK: - Overlay window

final class RegionOverlayWindow: NSPanel {
    weak var owner: RegionSelector?
    let displayID: CGDirectDisplayID
    let displayScreen: NSScreen

    init(screen: NSScreen, displayID: CGDirectDisplayID, owner: RegionSelector) {
        self.displayID = displayID
        self.displayScreen = screen
        self.owner = owner
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        self.hasShadow = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        let view = RegionSelectView(window: self)
        self.contentView = view
        self.makeFirstResponder(view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Custom view that tracks the drag

final class RegionSelectView: NSView {
    private weak var overlay: RegionOverlayWindow?
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var trackingArea: NSTrackingArea?

    init(window: RegionOverlayWindow) {
        self.overlay = window
        super.init(frame: window.contentView?.bounds ?? .zero)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override var acceptsFirstResponder: Bool { true }

    // ── Mouse handling ─────────────────────────────────────────────────────

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        defer { startPoint = nil; currentPoint = nil; needsDisplay = true }

        guard let rectPoints = currentSelectionRectPoints(), rectPoints.width >= 8, rectPoints.height >= 8 else {
            // Drag too small — treat as cancel
            overlay?.owner?.finish(with: nil)
            return
        }
        // Convert from this overlay's view coords (bottom-up, screen-relative)
        // to display points (top-down, display-relative).
        guard let overlay else { return }
        let screenFrame = overlay.displayScreen.frame
        let rectGlobalScreen = CGRect(
            x: screenFrame.origin.x + rectPoints.origin.x,
            y: screenFrame.origin.y + rectPoints.origin.y,
            width: rectPoints.width,
            height: rectPoints.height
        )
        // y-flip into display top-down coords: SCK uses (0,0) at display top-left.
        let displayHeight = overlay.displayScreen.frame.height
        let yTopDown = displayHeight - (rectPoints.origin.y + rectPoints.height)
        let rectDisplay = CGRect(
            x: rectPoints.origin.x,
            y: yTopDown,
            width: rectPoints.width,
            height: rectPoints.height
        )
        _ = rectGlobalScreen   // (kept for future multi-display calculations)

        let selection = RegionSelection(displayID: overlay.displayID, rect: rectDisplay)
        overlay.owner?.finish(with: selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {     // Escape
            overlay?.owner?.finish(with: nil)
            return
        }
        super.keyDown(with: event)
    }

    // ── Drawing ────────────────────────────────────────────────────────────

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSColor.black.withAlphaComponent(0.25)
        bg.setFill()
        bounds.fill()

        guard let rect = currentSelectionRectPoints() else { return }

        // "Cut out" the selected area by erasing it.
        NSColor.clear.setFill()
        rect.fill(using: .copy)

        // Border
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()

        // Dimensions label
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
        ]
        let labelSize = (label as NSString).size(withAttributes: attrs)
        let labelOrigin = NSPoint(
            x: rect.origin.x + 6,
            y: max(rect.origin.y - labelSize.height - 6, 4)
        )
        (label as NSString).draw(at: labelOrigin, withAttributes: attrs)
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private func currentSelectionRectPoints() -> NSRect? {
        guard let s = startPoint, let c = currentPoint else { return nil }
        return NSRect(
            x: min(s.x, c.x),
            y: min(s.y, c.y),
            width: abs(c.x - s.x),
            height: abs(c.y - s.y)
        )
    }
}

// MARK: - NSScreen helpers

extension NSScreen {
    /// The CGDirectDisplayID for this screen, derived from
    /// `deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]`.
    var cg_displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let n = deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(n.uint32Value)
    }
}
