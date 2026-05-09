import EncoderKit
import SwiftUI
import UniformTypeIdentifiers

struct RecordingsListView: View {
    @ObservedObject var library: RecordingsLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var renamingID: URL?
    @State private var renameText: String = ""
    @State private var exportingID: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recordings").font(.title2.bold())
                Spacer()
                Button {
                    Task { await library.reload() }
                } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            if library.files.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "film.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No recordings yet").foregroundStyle(.secondary)
                    Text("Files saved to ~/Movies/Free Mac Screen Recorder/")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(library.files) { file in
                        RecordingRow(
                            file: file,
                            library: library,
                            renamingID: $renamingID,
                            renameText: $renameText,
                            exportingID: $exportingID
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 540, minHeight: 420)
        .task { await library.reload() }
    }
}

private struct RecordingRow: View {
    let file: RecordingFile
    @ObservedObject var library: RecordingsLibrary
    @Binding var renamingID: URL?
    @Binding var renameText: String
    @Binding var exportingID: URL?

    private var isRenaming: Bool { renamingID == file.url }
    private var isExporting: Bool { exportingID == file.url }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.url.pathExtension.lowercased() == "gif" ? "photo" : "film")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    HStack(spacing: 6) {
                        TextField("Name", text: $renameText, onCommit: commitRename)
                            .textFieldStyle(.roundedBorder)
                        Button("Save", action: commitRename).keyboardShortcut(.defaultAction)
                        Button("Cancel") { renamingID = nil }
                    }
                } else {
                    Text(file.name).font(.body).lineLimit(1)
                    Text("\(file.createdAt.formatted(date: .abbreviated, time: .shortened))  ·  \(file.formattedSize)  ·  \(file.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isExporting {
                ProgressView().scaleEffect(0.6)
            }
            Button { library.open(file) }            label: { Image(systemName: "play.circle") }.buttonStyle(.borderless).help("Open")
            Button { library.revealInFinder(file) }  label: { Image(systemName: "folder") }.buttonStyle(.borderless).help("Reveal in Finder")
            Button(role: .destructive) {
                library.delete(file)
            } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Move to Trash")
        }
        .padding(.vertical, 4)
        .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { library.open(file) }
            Button("Reveal in Finder") { library.revealInFinder(file) }
            Divider()
            Button("Rename…") { startRename() }
            if file.url.pathExtension.lowercased() != "gif" {
                Button("Export as GIF") { exportGIF() }
            }
            Divider()
            Button("Move to Trash", role: .destructive) { library.delete(file) }
        }
    }

    private func startRename() {
        renameText = file.url.deletingPathExtension().lastPathComponent
        renamingID = file.url
    }

    private func commitRename() {
        let target = file
        let newName = renameText
        renamingID = nil
        do {
            try library.rename(target, to: newName)
        } catch {
            // surface as console for now; UI surfacing later
            print("Rename failed: \(error.localizedDescription)")
        }
    }

    private func exportGIF() {
        exportingID = file.url
        Task {
            do {
                _ = try await library.exportGIF(file)
            } catch {
                print("GIF export failed: \(error.localizedDescription)")
            }
            exportingID = nil
        }
    }
}
