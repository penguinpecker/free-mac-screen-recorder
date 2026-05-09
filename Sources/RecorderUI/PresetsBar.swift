import SwiftUI

struct PresetsBar: View {
    @ObservedObject var vm: RecordingViewModel
    @State private var showSaveSheet = false
    @State private var newPresetName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
            Menu {
                if vm.presets.presets.isEmpty {
                    Text("No presets saved").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.presets.presets) { p in
                        Button {
                            vm.apply(p)
                        } label: {
                            Text(p.name)
                        }
                    }
                    Divider()
                    Menu("Delete preset…") {
                        ForEach(vm.presets.presets) { p in
                            Button(role: .destructive) {
                                vm.presets.delete(id: p.id)
                            } label: {
                                Text(p.name)
                            }
                        }
                    }
                }
            } label: {
                Text("Presets")
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 100)

            Button("Save current…") {
                newPresetName = "Preset \(vm.presets.presets.count + 1)"
                showSaveSheet = true
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .sheet(isPresented: $showSaveSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Save current settings as preset").font(.headline)
                TextField("Name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                HStack {
                    Spacer()
                    Button("Cancel") { showSaveSheet = false }
                    Button("Save") {
                        let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        vm.saveCurrentAsPreset(named: trimmed)
                        showSaveSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
    }
}
