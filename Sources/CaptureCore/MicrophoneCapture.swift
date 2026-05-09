import AVFoundation
import CoreMedia
import Foundation
import OSLog

/// Captures audio from a chosen `AVCaptureDevice` (microphone) and forwards
/// the raw `CMSampleBuffer`s to a callback. Used in tandem with `CaptureSession`
/// so the SCStream handles screen + system audio while this handles the mic.
final class MicrophoneCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {

    enum MicError: Error {
        case deviceNotFound
        case sessionFailed(String)
    }

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "MicrophoneCapture")
    private let session = AVCaptureSession()
    private let deviceUniqueID: String
    private let onSample: (CMSampleBuffer) -> Void
    private let queue = DispatchQueue(label: "com.freemacscreenrecorder.mic", qos: .userInitiated)

    init(deviceUniqueID: String, onSample: @escaping (CMSampleBuffer) -> Void) throws {
        self.deviceUniqueID = deviceUniqueID
        self.onSample = onSample
        super.init()

        guard let device = AVCaptureDevice(uniqueID: deviceUniqueID) else {
            throw MicError.deviceNotFound
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw MicError.sessionFailed(error.localizedDescription)
        }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func start() throws {
        session.startRunning()
        log.info("Microphone capture started (\(self.deviceUniqueID, privacy: .public))")
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
        log.info("Microphone capture stopped")
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard sampleBuffer.isValid else { return }
        onSample(sampleBuffer)
    }
}
