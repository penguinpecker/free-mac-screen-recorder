import AppKit
import Carbon.HIToolbox
import OSLog

/// A single Carbon-registered global hotkey. Carbon's `RegisterEventHotKey` is
/// the only no-permissions, system-level hotkey API on macOS — neither
/// Accessibility nor Input Monitoring is required.
public final class GlobalHotkey {
    public typealias Handler = () -> Void

    private let handler: Handler
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// `keyCode` is a Carbon virtual key code (e.g. `kVK_ANSI_R = 15`).
    /// `modifiers` is an OR of `cmdKey | shiftKey | optionKey | controlKey`.
    public init(keyCode: Int, modifiers: Int, handler: @escaping Handler) {
        self.handler = handler
        register(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        if let h = eventHandler { RemoveEventHandler(h) }
        if let r = hotKeyRef    { UnregisterEventHotKey(r) }
    }

    private func register(keyCode: Int, modifiers: Int) {
        let hotKeyID = EventHotKeyID(signature: 0x46734D52 /* "FsMR" */, id: UInt32.random(in: 1...UInt32.max))
        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard regStatus == noErr else { return }
        self.hotKeyRef = ref

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, _, ptr -> OSStatus in
            guard let ptr else { return noErr }
            let me = Unmanaged<GlobalHotkey>.fromOpaque(ptr).takeUnretainedValue()
            DispatchQueue.main.async { me.handler() }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            userData,
            &eventHandler
        )
    }
}

/// High-level toggle: ⌘⇧R starts recording, ⌘⇧S stops.
@MainActor
public final class GlobalHotkeyController {
    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "Hotkeys")
    private var startKey: GlobalHotkey?
    private var stopKey: GlobalHotkey?

    public init() {}

    public func install(start: @escaping @MainActor () -> Void,
                        stop:  @escaping @MainActor () -> Void) {
        let cmdShift = cmdKey | shiftKey
        startKey = GlobalHotkey(keyCode: kVK_ANSI_R, modifiers: cmdShift) {
            Task { @MainActor in start() }
        }
        stopKey = GlobalHotkey(keyCode: kVK_ANSI_S, modifiers: cmdShift) {
            Task { @MainActor in stop() }
        }
        log.info("Global hotkeys installed: ⌘⇧R / ⌘⇧S")
    }

    public func uninstall() {
        startKey = nil
        stopKey = nil
    }
}
