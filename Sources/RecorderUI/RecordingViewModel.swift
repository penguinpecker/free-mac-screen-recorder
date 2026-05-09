import AppKit
import CaptureCore
import Combine
import DeviceKit
import EncoderKit
import Foundation
import OSLog
import ScreenCaptureKit

/// Single source of truth for the UI. Owns a `CaptureSession`, a
/// `DeviceManager`, and the user's current selection.
@MainActor
public final class RecordingViewModel: ObservableObject {

    public enum SourceKind: String, CaseIterable, Identifiable {
        case display = "Display"
        case window  = "Window"
        case app     = "App"
        case region  = "Region"
        public var id: String { rawValue }
    }

    public enum Status: Equatable {
        case idle
        case loadingContent
        case ready
        case recording(startedAt: Date)
        case stopping
        case finished(URL)
        case error(String)
    }

    // ── Shareable content ──────────────────────────────────────────────────
    @Published public private(set) var displays: [DisplayInfo] = []
    @Published public private(set) var windows:  [WindowInfo]  = []
    @Published public private(set) var apps:     [AppInfo]     = []

    // ── User selection ─────────────────────────────────────────────────────
    @Published public var sourceKind: SourceKind = .display
    @Published public var selectedDisplayID: CGDirectDisplayID?
    @Published public var selectedWindowID: CGWindowID?
    @Published public var selectedAppPID: pid_t?
    @Published public var selectedRegion: RegionSelection?
    @Published public var selectedMicID: String?
    @Published public var captureSystemAudio: Bool = true
    @Published public var captureMicrophone: Bool = false
    @Published public var codec: OutputCodec = .h264
    @Published public var fps: Int = 60
    @Published public var showsCursor: Bool = true
    @Published public var customWidth: Int?
    @Published public var customHeight: Int?

    @Published public private(set) var status: Status = .idle

    public let devices: DeviceManager
    public let levels: AudioLevelMonitor
    public let library: RecordingsLibrary
    public let presets: PresetsStore
    private let session: CaptureSession
    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "ViewModel")
    private let bundleID: String
    private let outputFolder: URL

    public init(bundleID: String = "com.freemacscreenrecorder.app") {
        self.bundleID = bundleID
        self.devices = DeviceManager()
        let levels = AudioLevelMonitor()
        self.levels = levels
        self.session = CaptureSession(ourBundleID: bundleID, levels: levels)

        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                    ?? FileManager.default.homeDirectoryForCurrentUser
        self.outputFolder = movies.appendingPathComponent("Free Mac Screen Recorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        self.library = RecordingsLibrary(folder: outputFolder)
        self.presets = PresetsStore()
    }

    // MARK: - Presets

    /// Capture the current settings into a new preset.
    public func snapshotPreset(named name: String) -> Preset {
        Preset(
            name: name,
            sourceKindRaw: sourceKind.rawValue,
            codec: codec,
            fps: fps,
            showsCursor: showsCursor,
            captureSystemAudio: captureSystemAudio,
            captureMicrophone: captureMicrophone,
            customWidth: customWidth,
            customHeight: customHeight
        )
    }

    public func saveCurrentAsPreset(named name: String) {
        presets.add(snapshotPreset(named: name))
    }

    public func apply(_ preset: Preset) {
        if let kind = SourceKind(rawValue: preset.sourceKindRaw) { sourceKind = kind }
        codec = preset.codec
        fps = preset.fps
        showsCursor = preset.showsCursor
        captureSystemAudio = preset.captureSystemAudio
        captureMicrophone = preset.captureMicrophone
        customWidth = preset.customWidth
        customHeight = preset.customHeight
    }

    // MARK: - Loading

    public func loadAvailableContent() async {
        status = .loadingContent
        do {
            let content = try await ShareableContentLoader.load(excludingBundleID: bundleID)
            self.displays = content.displays
            self.windows  = content.windows
            self.apps     = content.apps
            if selectedDisplayID == nil { selectedDisplayID = displays.first?.id }
            status = .ready
        } catch {
            log.error("Could not load shareable content: \(error.localizedDescription, privacy: .public)")
            status = .error(
                "Couldn't enumerate screens. Grant Screen Recording in System Settings → Privacy & Security, then quit and relaunch."
            )
        }
    }

    // MARK: - Recording

    public func toggleRecording() async {
        switch status {
        case .recording: await stopRecording()
        default:         await startRecording()
        }
    }

    public func startRecording() async {
        guard let source = currentSource() else {
            status = .error("Pick a source to record first.")
            return
        }
        let geometry = currentGeometry(for: source)
        let url = freshOutputURL()

        var settings = RecordingSettings(
            width: geometry.outputWidth,
            height: geometry.outputHeight,
            fps: geometry.fps,
            codec: codec,
            captureMicrophone: captureMicrophone && selectedMicID != nil,
            captureSystemAudio: captureSystemAudio,
            microphoneDeviceID: captureMicrophone ? selectedMicID : nil,
            outputURL: url
        )
        settings.codec = codec

        do {
            try await session.start(source: source, geometry: geometry, settings: settings)
            status = .recording(startedAt: Date())
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    public func stopRecording() async {
        status = .stopping
        do {
            let url = try await session.stop()
            status = .finished(url)
            await library.reload()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    public func revealLastRecording() {
        if case .finished(let url) = status {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Present the region-selection overlay. The host app window stays open;
    /// it just gets covered by the translucent panel until the user finishes.
    public func pickRegion() async {
        let selector = RegionSelector()
        if let pick = await selector.present() {
            selectedRegion = pick
            sourceKind = .region
        }
    }

    // MARK: - Helpers

    private func currentSource() -> CaptureSource? {
        switch sourceKind {
        case .display:
            guard let id = selectedDisplayID else { return nil }
            return .display(id: id, region: nil)
        case .window:
            guard let id = selectedWindowID else { return nil }
            return .window(id: id)
        case .app:
            guard let pid = selectedAppPID,
                  let displayID = selectedDisplayID ?? displays.first?.id
            else { return nil }
            return .application(pid: pid, displayID: displayID)
        case .region:
            guard let pick = selectedRegion else { return nil }
            return .display(id: pick.displayID, region: pick.rect)
        }
    }

    private func currentGeometry(for source: CaptureSource) -> CaptureGeometry {
        let (w, h) = nativeSize(for: source)
        let outW = customWidth  ?? w
        let outH = customHeight ?? h
        return CaptureGeometry(outputWidth: outW, outputHeight: outH, fps: fps, showsCursor: showsCursor)
    }

    private func nativeSize(for source: CaptureSource) -> (Int, Int) {
        switch source {
        case .display(let id, let region):
            if let region { return (Int(region.width), Int(region.height)) }
            if let d = displays.first(where: { $0.id == id }) { return (d.width, d.height) }
            return (1920, 1080)
        case .window(let id):
            if let w = windows.first(where: { $0.id == id }) {
                return (Int(w.frame.width), Int(w.frame.height))
            }
            return (1920, 1080)
        case .application(_, let did):
            if let d = displays.first(where: { $0.id == did }) { return (d.width, d.height) }
            return (1920, 1080)
        }
    }

    private func freshOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())
        return outputFolder.appendingPathComponent("Recording_\(stamp).\(codec.fileExtension)")
    }
}
