import Combine
import EncoderKit
import Foundation

public struct Preset: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String

    public var sourceKindRaw: String           // RecordingViewModel.SourceKind.rawValue
    public var codec: OutputCodec
    public var fps: Int
    public var showsCursor: Bool
    public var captureSystemAudio: Bool
    public var captureMicrophone: Bool
    public var customWidth: Int?
    public var customHeight: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        sourceKindRaw: String,
        codec: OutputCodec,
        fps: Int,
        showsCursor: Bool,
        captureSystemAudio: Bool,
        captureMicrophone: Bool,
        customWidth: Int?,
        customHeight: Int?
    ) {
        self.id = id; self.name = name
        self.sourceKindRaw = sourceKindRaw
        self.codec = codec; self.fps = fps
        self.showsCursor = showsCursor
        self.captureSystemAudio = captureSystemAudio
        self.captureMicrophone = captureMicrophone
        self.customWidth = customWidth; self.customHeight = customHeight
    }
}

@MainActor
public final class PresetsStore: ObservableObject {
    @Published public private(set) var presets: [Preset] = []

    private let defaults = UserDefaults.standard
    private let key = "FreeMacScreenRecorder.presets.v1"

    public init() { load() }

    public func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data)
        else { return }
        presets = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: key)
        }
    }

    public func add(_ preset: Preset) {
        presets.append(preset)
        persist()
    }

    public func update(_ preset: Preset) {
        if let i = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[i] = preset
            persist()
        }
    }

    public func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        persist()
    }
}
