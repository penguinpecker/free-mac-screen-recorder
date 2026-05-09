import SwiftUI

struct RecordingsListView: View {
    @ObservedObject var library: RecordingsLibrary
    @Environment(\.dismiss) private var dismiss

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
                        RecordingRow(file: file, library: library)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.body).lineLimit(1)
                Text("\(file.createdAt.formatted(date: .abbreviated, time: .shortened))  ·  \(file.formattedSize)  ·  \(file.formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { library.open(file) }            label: { Image(systemName: "play.circle") }.buttonStyle(.borderless).help("Open")
            Button { library.revealInFinder(file) }  label: { Image(systemName: "folder") }.buttonStyle(.borderless).help("Reveal in Finder")
            Button(role: .destructive) {
                library.delete(file)
            } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Move to Trash")
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Open") { library.open(file) }
            Button("Reveal in Finder") { library.revealInFinder(file) }
            Divider()
            Button("Move to Trash", role: .destructive) { library.delete(file) }
        }
    }
}
