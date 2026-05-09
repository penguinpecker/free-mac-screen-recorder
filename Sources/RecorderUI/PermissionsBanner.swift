import AppKit
@preconcurrency import AVFoundation
import CoreGraphics
import Combine
import SwiftUI

/// Polls TCC permission states (Screen Recording, Camera, Microphone) and
/// publishes changes so the UI can show a prominent banner. Also exposes
/// helpers to deep-link to the right Privacy & Security pane.
@MainActor
public final class PermissionsMonitor: ObservableObject {
    @Published public private(set) var hasScreenRecording: Bool = false
    @Published public private(set) var hasCamera: Bool = false
    @Published public private(set) var hasMicrophone: Bool = false

    private var pollTask: Task<Void, Never>?

    public init() {
        refresh()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.refresh()
            }
        }
    }

    deinit { pollTask?.cancel() }

    public func refresh() {
        // CGPreflightScreenCaptureAccess() returns true if our process has been
        // granted Screen Recording in System Settings. It does NOT prompt.
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        hasCamera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public func requestScreenRecordingPrompt() {
        // Triggers the OS prompt the first time; thereafter is a no-op.
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    public func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    public func openCameraSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
    }

    public func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    public func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

// MARK: - Banner

struct PermissionsBanner: View {
    @ObservedObject var monitor: PermissionsMonitor

    var body: some View {
        if !monitor.hasScreenRecording {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording permission required")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Recording will not start until you grant Screen Recording in System Settings, then quit and relaunch the app.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                VStack(spacing: 6) {
                    Button("Open Settings") {
                        monitor.requestScreenRecordingPrompt()
                        monitor.openScreenRecordingSettings()
                    }
                    .controlSize(.small)
                    Button("Quit & Relaunch") { monitor.relaunchApp() }
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.red.opacity(0.85))
        }
    }
}
