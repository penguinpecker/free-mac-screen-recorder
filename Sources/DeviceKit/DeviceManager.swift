import AVFoundation
import Combine
import Foundation
import OSLog

/// Lists available cameras and microphones on the system and republishes the
/// list whenever a device is connected, disconnected, or marked unsuitable.
///
/// Pattern documented at:
/// https://developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession
@MainActor
public final class DeviceManager: ObservableObject {
    @Published public private(set) var cameras: [AVDevice] = []
    @Published public private(set) var microphones: [AVDevice] = []

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "DeviceManager")
    private var observers: [NSObjectProtocol] = []

    public init() {
        refresh()
        let handler: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected, object: nil, queue: nil, using: handler
        ))
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: nil, using: handler
        ))
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func refresh() {
        let cameraSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: cameraDeviceTypes(),
            mediaType: .video,
            position: .unspecified
        )
        let micSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: micDeviceTypes(),
            mediaType: .audio,
            position: .unspecified
        )

        cameras = cameraSession.devices.map { AVDevice($0, kind: .camera) }
        microphones = micSession.devices.map { AVDevice($0, kind: .microphone) }

        log.info("Devices: \(self.cameras.count) cameras, \(self.microphones.count) microphones")
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private func cameraDeviceTypes() -> [AVCaptureDevice.DeviceType] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            types.append(.external)
            types.append(.continuityCamera)
            types.append(.deskViewCamera)
        } else {
            // macOS 13: external USB / virtual cameras come through this type.
            types.append(.externalUnknown)
        }
        return types
    }

    private func micDeviceTypes() -> [AVCaptureDevice.DeviceType] {
        if #available(macOS 14.0, *) {
            return [.microphone, .external]
        } else {
            return [.builtInMicrophone]
        }
    }

    /// Resolve a stored device id back into a live AVCaptureDevice.
    public func captureDevice(for id: String) -> AVCaptureDevice? {
        AVCaptureDevice(uniqueID: id)
    }
}
