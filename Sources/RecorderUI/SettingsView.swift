import EncoderKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section("Defaults") {
                Picker("Codec", selection: $settings.defaultCodec) {
                    ForEach(OutputCodec.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                Stepper(value: $settings.defaultFPS, in: 24...120, step: 1) {
                    Text("Frame rate: \(settings.defaultFPS) fps")
                }
                Toggle("Show cursor", isOn: $settings.defaultShowsCursor)
                Toggle("Capture system audio", isOn: $settings.defaultCaptureSystemAudio)
            }

            Section("Output") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Recordings folder").font(.body)
                        Text(settings.outputFolder.path)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose…") { settings.pickOutputFolder() }
                }
            }

            Section("Hotkeys") {
                LabeledContent("Start recording", value: "⌘⇧R")
                LabeledContent("Stop recording",  value: "⌘⇧S")
                Text("Hotkeys are system-wide. Rebinding from inside the app is on the roadmap.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App", value: "Free Mac Screen Recorder")
                LabeledContent("Project", value: "github.com/penguinpecker/free-mac-screen-recorder")
                Text("MIT licensed. Built on ScreenCaptureKit, AVFoundation, and VideoToolbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 480)
        .padding(.bottom, 12)
    }
}
