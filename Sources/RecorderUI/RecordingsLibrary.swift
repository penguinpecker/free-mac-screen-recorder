import AVFoundation
import AppKit
import Combine
import Foundation

public struct RecordingFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let createdAt: Date
    public let sizeBytes: Int64
    public let duration: Double?       // seconds, nil if not yet known

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public var formattedDuration: String {
        guard let d = duration, d.isFinite, d > 0 else { return "—" }
        let total = Int(d)
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }
}

@MainActor
public final class RecordingsLibrary: ObservableObject {
    @Published public private(set) var files: [RecordingFile] = []

    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    public func reload() async {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            files = []
            return
        }
        let videoExts: Set<String> = ["mp4", "mov", "m4v"]
        let candidates = items.filter { videoExts.contains($0.pathExtension.lowercased()) }

        // Lightweight metadata first so the list renders immediately.
        let initial = candidates.map { url -> RecordingFile in
            let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            return RecordingFile(
                url: url,
                name: url.lastPathComponent,
                createdAt: attrs?.creationDate ?? Date.distantPast,
                sizeBytes: Int64(attrs?.fileSize ?? 0),
                duration: nil
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
        files = initial

        // Then load durations asynchronously and merge in.
        await withTaskGroup(of: (URL, Double?).self) { group in
            for f in initial {
                group.addTask {
                    let asset = AVURLAsset(url: f.url)
                    let dur = try? await asset.load(.duration)
                    return (f.url, dur.map { CMTimeGetSeconds($0) })
                }
            }
            for await (url, secs) in group {
                if let idx = files.firstIndex(where: { $0.url == url }) {
                    let f = files[idx]
                    files[idx] = RecordingFile(
                        url: f.url, name: f.name, createdAt: f.createdAt,
                        sizeBytes: f.sizeBytes, duration: secs
                    )
                }
            }
        }
    }

    public func revealInFinder(_ file: RecordingFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    public func open(_ file: RecordingFile) {
        NSWorkspace.shared.open(file.url)
    }

    public func delete(_ file: RecordingFile) {
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            files.removeAll { $0.url == file.url }
        } catch {
            // Surface in console; UI surfacing later.
            print("Delete failed: \(error.localizedDescription)")
        }
    }
}
