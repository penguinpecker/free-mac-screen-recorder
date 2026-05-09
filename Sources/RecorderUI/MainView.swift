import AppKit
import CaptureCore
import DeviceKit
import EncoderKit
import SwiftUI

public struct MainView: View {
    @ObservedObject private var vm: RecordingViewModel
    @State private var showLibrary = false

    public init(vm: RecordingViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            PresetsBar(vm: vm)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sourceSection
                    audioSection
                    overlaysSection
                    outputSection
                }
                .padding(20)
            }
            Divider()
            controlBar
        }
        .frame(minWidth: 560, minHeight: 640)
        .task { await vm.loadAvailableContent() }
        .sheet(isPresented: $showLibrary) {
            RecordingsListView(library: vm.library)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "record.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isRecording ? .red : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Free Mac Screen Recorder").font(.title2.bold())
                if case .recording(let started) = vm.status {
                    RecordingTimerView(startedAt: started)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.red)
                } else if case .paused = vm.status {
                    Text("Paused").font(.caption).foregroundStyle(.orange)
                } else {
                    Text(statusLine).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                showLibrary = true
            } label: {
                Image(systemName: "film.stack")
            }
            .buttonStyle(.borderless)
            .help("Browse past recordings")
            Button {
                Task { await vm.loadAvailableContent() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh available screens, windows, and apps")
        }
        .padding(16)
    }

    // MARK: - Sections

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Source")
            Picker("", selection: $vm.sourceKind) {
                ForEach(RecordingViewModel.SourceKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch vm.sourceKind {
            case .display: displayPicker
            case .window:  windowPicker
            case .app:     appPicker
            case .region:  regionPicker
            }

            HStack {
                Toggle("Show cursor", isOn: $vm.showsCursor)
                Spacer()
                Stepper("FPS: \(vm.fps)", value: $vm.fps, in: 24...120, step: 1)
                    .frame(width: 160)
            }

            customResolutionRow
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Audio")
            Toggle("Capture system audio", isOn: $vm.captureSystemAudio)
            Toggle("Capture microphone", isOn: $vm.captureMicrophone)
            if vm.captureMicrophone {
                Picker("Microphone", selection: $vm.selectedMicID) {
                    Text("None").tag(String?.none)
                    ForEach(vm.devices.microphones) { mic in
                        Text(mic.localizedName).tag(String?.some(mic.id))
                    }
                }
            }
            if isRecording {
                if vm.captureSystemAudio { LevelMeterView(monitor: vm.levels, kind: .system) }
                if vm.captureMicrophone  { LevelMeterView(monitor: vm.levels, kind: .mic) }
            }
        }
    }

    private var overlaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Overlays")

            // Webcam PiP
            HStack {
                Toggle("Webcam picture-in-picture", isOn: Binding(
                    get: { vm.webcamEnabled },
                    set: { _ in Task { await vm.toggleWebcam() } }
                ))
                Spacer()
            }
            if vm.webcamEnabled {
                Picker("Camera", selection: $vm.selectedWebcamDeviceID) {
                    ForEach(vm.devices.cameras) { c in
                        Text(c.localizedName).tag(String?.some(c.id))
                    }
                }
                .onChange(of: vm.selectedWebcamDeviceID) { newID in
                    if let id = newID { try? vm.webcam.setDevice(id) }
                }
                Picker("Position", selection: $vm.webcamCorner) {
                    ForEach(WebcamCorner.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                Picker("Size", selection: $vm.webcamSize) {
                    ForEach(WebcamSize.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            }

            // Click highlights
            Toggle("Highlight mouse clicks", isOn: Binding(
                get: { vm.clickHighlightsEnabled },
                set: { _ in vm.toggleClickHighlights() }
            ))

            // Keystroke overlay
            Toggle("Show keystrokes", isOn: Binding(
                get: { vm.keystrokesEnabled },
                set: { _ in vm.toggleKeystrokes() }
            ))

            Text("Overlays appear in display + region recordings. Keystrokes need Input Monitoring permission to capture keys typed in other apps.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Output")
            Picker("Codec", selection: $vm.codec) {
                ForEach(OutputCodec.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            Text("Saved to ~/Movies/Free Mac Screen Recorder/")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Pickers

    private var displayPicker: some View {
        Picker("Display", selection: $vm.selectedDisplayID) {
            ForEach(vm.displays) { d in
                Text(d.displayName).tag(CGDirectDisplayID?.some(d.id))
            }
        }
    }

    private var windowPicker: some View {
        Picker("Window", selection: $vm.selectedWindowID) {
            Text("Pick a window…").tag(CGWindowID?.none)
            ForEach(vm.windows) { w in
                Text(w.displayName).tag(CGWindowID?.some(w.id))
            }
        }
    }

    private var appPicker: some View {
        Picker("Application", selection: $vm.selectedAppPID) {
            Text("Pick an app…").tag(pid_t?.none)
            ForEach(vm.apps) { a in
                Text(a.displayName).tag(pid_t?.some(a.id))
            }
        }
    }

    private var regionPicker: some View {
        HStack(spacing: 12) {
            if let r = vm.selectedRegion {
                Label(
                    "\(Int(r.rect.width)) × \(Int(r.rect.height)) on display \(r.displayID)",
                    systemImage: "rectangle.dashed"
                )
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
            } else {
                Text("No region picked yet")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Select Region…") {
                Task { await vm.pickRegion() }
            }
        }
    }

    private var customResolutionRow: some View {
        HStack(spacing: 12) {
            Toggle("Custom output size", isOn: Binding(
                get: { vm.customWidth != nil },
                set: { on in
                    if on {
                        vm.customWidth  = vm.customWidth  ?? 1920
                        vm.customHeight = vm.customHeight ?? 1080
                    } else {
                        vm.customWidth = nil
                        vm.customHeight = nil
                    }
                }
            ))
            if vm.customWidth != nil {
                TextField("W", value: Binding($vm.customWidth, replacingNilWith: 1920), format: .number)
                    .frame(width: 70).textFieldStyle(.roundedBorder)
                Text("×")
                TextField("H", value: Binding($vm.customHeight, replacingNilWith: 1080), format: .number)
                    .frame(width: 70).textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            if case .finished(_) = vm.status {
                Button("Show in Finder") { vm.revealLastRecording() }
            }
            Spacer()
            if isActive {
                Button {
                    vm.togglePause()
                } label: {
                    Label(isPaused ? "Resume" : "Pause",
                          systemImage: isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.headline)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }
            Button {
                Task { await vm.toggleRecording() }
            } label: {
                Label(isActive ? "Stop Recording" : "Start Recording",
                      systemImage: isActive ? "stop.circle.fill" : "record.circle.fill")
                    .font(.headline)
                    .frame(minWidth: 180)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .red : .accentColor)
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .padding(16)
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        if case .recording = vm.status { return true }
        return false
    }

    private var isPaused: Bool {
        if case .paused = vm.status { return true }
        return false
    }

    private var isActive: Bool { isRecording || isPaused }

    private var statusLine: String {
        switch vm.status {
        case .idle:                       return "Idle"
        case .loadingContent:             return "Loading available screens…"
        case .ready:                      return "Ready"
        case .recording(let started):
            let secs = Int(Date().timeIntervalSince(started))
            return String(format: "Recording — %02d:%02d", secs / 60, secs % 60)
        case .paused:                     return "Paused"
        case .stopping:                   return "Stopping…"
        case .finished(let url):          return "Saved \(url.lastPathComponent)"
        case .error(let message):         return message
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s).font(.headline).foregroundStyle(.secondary)
    }
}

// Convenience: bind an optional value through a TextField using a fallback default.
private extension Binding where Value == Int? {
    init(_ source: Binding<Int?>, replacingNilWith fallback: Int) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0 }
        )
    }
}
