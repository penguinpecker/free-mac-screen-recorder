import AppKit
import Combine
import EncoderKit
import Foundation

/// User preferences persisted to `UserDefaults`. Read once at init, written
/// on every change via Combine.
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private struct Keys {
        static let codec = "FMSR.defaults.codec"
        static let fps = "FMSR.defaults.fps"
        static let cursor = "FMSR.defaults.cursor"
        static let systemAudio = "FMSR.defaults.systemAudio"
        static let folderPath = "FMSR.defaults.outputFolderPath"
    }

    @Published public var defaultCodec: OutputCodec {
        didSet { UserDefaults.standard.set(defaultCodec.rawValue, forKey: Keys.codec) }
    }
    @Published public var defaultFPS: Int {
        didSet { UserDefaults.standard.set(defaultFPS, forKey: Keys.fps) }
    }
    @Published public var defaultShowsCursor: Bool {
        didSet { UserDefaults.standard.set(defaultShowsCursor, forKey: Keys.cursor) }
    }
    @Published public var defaultCaptureSystemAudio: Bool {
        didSet { UserDefaults.standard.set(defaultCaptureSystemAudio, forKey: Keys.systemAudio) }
    }
    @Published public var outputFolder: URL {
        didSet { UserDefaults.standard.set(outputFolder.path, forKey: Keys.folderPath) }
    }

    public init() {
        let d = UserDefaults.standard
        self.defaultCodec = OutputCodec(rawValue: d.string(forKey: Keys.codec) ?? "") ?? .h264
        let storedFPS = d.integer(forKey: Keys.fps)
        self.defaultFPS = storedFPS == 0 ? 60 : storedFPS
        // Provide explicit default so missing key isn't read as `false`.
        self.defaultShowsCursor = d.object(forKey: Keys.cursor) as? Bool ?? true
        self.defaultCaptureSystemAudio = d.object(forKey: Keys.systemAudio) as? Bool ?? true

        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                    ?? FileManager.default.homeDirectoryForCurrentUser
        let fallback = movies.appendingPathComponent("Free Mac Screen Recorder", isDirectory: true)
        if let stored = d.string(forKey: Keys.folderPath), !stored.isEmpty {
            self.outputFolder = URL(fileURLWithPath: stored, isDirectory: true)
        } else {
            self.outputFolder = fallback
        }
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    }

    public func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputFolder
        panel.message = "Choose where Free Mac Screen Recorder saves recordings"
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }
}
