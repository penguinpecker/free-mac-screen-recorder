import AppKit
import CoreGraphics
import OSLog
import QuartzCore

/// A floating chip near the bottom of the screen that shows the most recent
/// keystroke (with modifier symbols). Useful for tutorial recordings.
///
/// Note: capturing keyboard events from other apps requires the user to grant
/// Input Monitoring access in System Settings → Privacy & Security. macOS
/// surfaces this prompt automatically the first time the global monitor sees a
/// keystroke. The recording itself does not need this permission.
@MainActor
public final class KeystrokeOverlayController: ObservableObject {
    @Published public private(set) var isVisible: Bool = false
    @Published public var fadeAfterSeconds: TimeInterval = 1.5

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "Keystrokes")
    private var window: KeystrokePanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hideWorkItem: DispatchWorkItem?

    public init() {}

    public var windowID: CGWindowID? {
        guard let w = window else { return nil }
        return CGWindowID(w.windowNumber)
    }

    public func show() {
        guard !isVisible else { return }
        let panel = KeystrokePanel()
        window = panel
        installMonitors()
        isVisible = true
    }

    public func hide() {
        removeMonitors()
        window?.orderOut(nil)
        window = nil
        isVisible = false
    }

    // MARK: - Monitors

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
            return event
        }
    }

    private func removeMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor  { NSEvent.removeMonitor(l) }
        globalMonitor = nil; localMonitor = nil
    }

    private func handle(event: NSEvent) {
        // Show only "real" keystrokes — ignore pure modifier flag changes.
        guard event.type == .keyDown else { return }
        guard let text = Self.format(event: event), !text.isEmpty else { return }
        guard let window else { return }

        window.setText(text)
        window.orderFront(nil)

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.window?.fadeOut() }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeAfterSeconds, execute: work)
    }

    // MARK: - Formatting

    /// Build a string like "⌘⇧K" from an NSEvent.
    private static func format(event: NSEvent) -> String? {
        let mods = event.modifierFlags
        var prefix = ""
        if mods.contains(.control) { prefix += "⌃" }
        if mods.contains(.option)  { prefix += "⌥" }
        if mods.contains(.shift)   { prefix += "⇧" }
        if mods.contains(.command) { prefix += "⌘" }

        // Prefer characters ignoring modifiers (so "⇧A" shows the "A" not "a"…
        // wait, we want "A" which is the modified char, hmm). Use chars without
        // modifiers for the *base* key, then uppercase for visual clarity.
        let raw = event.charactersIgnoringModifiers ?? ""
        let glyph: String
        if let mapped = specialKeyGlyph(forKeyCode: Int(event.keyCode)) {
            glyph = mapped
        } else if !raw.isEmpty {
            glyph = raw.uppercased()
        } else {
            return nil
        }
        return prefix + glyph
    }

    private static func specialKeyGlyph(forKeyCode code: Int) -> String? {
        switch code {
        case 36, 76:   return "↩"     // return / numpad enter
        case 48:       return "⇥"     // tab
        case 49:       return "Space"
        case 51:       return "⌫"     // delete (backspace)
        case 53:       return "⎋"     // escape
        case 117:      return "⌦"     // forward delete
        case 123:      return "←"
        case 124:      return "→"
        case 125:      return "↓"
        case 126:      return "↑"
        case 122:      return "F1"
        case 120:      return "F2"
        case 99:       return "F3"
        case 118:      return "F4"
        case 96:       return "F5"
        case 97:       return "F6"
        case 98:       return "F7"
        case 100:      return "F8"
        case 101:      return "F9"
        case 109:      return "F10"
        case 103:      return "F11"
        case 111:      return "F12"
        default:       return nil
        }
    }
}

// MARK: - Panel

private final class KeystrokePanel: NSPanel {
    private let label = NSTextField(labelWithString: "")

    init() {
        let size = NSSize(width: 220, height: 64)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(
            x: screen.midX - size.width / 2,
            y: screen.minY + 100
        )
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let host = NSView(frame: NSRect(origin: .zero, size: size))
        host.wantsLayer = true
        host.layer?.cornerRadius = 16
        host.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        host.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        host.layer?.borderWidth = 1

        label.frame = host.bounds
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.monospacedSystemFont(ofSize: 28, weight: .semibold)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.lineBreakMode = .byTruncatingTail
        label.cell?.usesSingleLineMode = true
        host.addSubview(label)
        self.contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setText(_ s: String) {
        label.stringValue = s
        contentView?.layer?.opacity = 1
    }

    func fadeOut() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.duration = 0.25
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        contentView?.layer?.add(anim, forKey: "fade")
    }
}
