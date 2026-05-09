import Accelerate
import AVFoundation
import Combine
import CoreMedia
import Foundation

/// Tracks peak audio levels (0…1) for system audio and microphone, with a
/// fast attack / slow decay for VU-style behavior. Drives the level bars in
/// the UI and is safe to update from any thread.
@MainActor
public final class AudioLevelMonitor: ObservableObject {
    @Published public private(set) var systemAudioLevel: Float = 0
    @Published public private(set) var microphoneLevel: Float = 0

    /// Linear amplitude per second the meter decays when no new sample arrives.
    private let decayPerSecond: Float = 3.0
    private var lastSystemUpdate: Date = Date()
    private var lastMicUpdate: Date = Date()

    public nonisolated init() {}

    public func reset() {
        systemAudioLevel = 0
        microphoneLevel = 0
    }

    public nonisolated func ingestSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        let peak = Self.peakAmplitude(from: sampleBuffer)
        Task { @MainActor in self.applySystem(peak: peak) }
    }

    public nonisolated func ingestMicrophone(_ sampleBuffer: CMSampleBuffer) {
        let peak = Self.peakAmplitude(from: sampleBuffer)
        Task { @MainActor in self.applyMic(peak: peak) }
    }

    private func applySystem(peak: Float) {
        let now = Date()
        let dt = Float(now.timeIntervalSince(lastSystemUpdate))
        let decayed = max(0, systemAudioLevel - decayPerSecond * dt)
        systemAudioLevel = max(decayed, peak)
        lastSystemUpdate = now
    }

    private func applyMic(peak: Float) {
        let now = Date()
        let dt = Float(now.timeIntervalSince(lastMicUpdate))
        let decayed = max(0, microphoneLevel - decayPerSecond * dt)
        microphoneLevel = max(decayed, peak)
        lastMicUpdate = now
    }

    // MARK: - Peak extraction

    /// Returns the peak absolute amplitude in [0, 1] for an audio sample buffer.
    /// Handles 32-bit float (most common for SCK + AVCapture) and falls back to
    /// 16-bit signed integer if that's what the format description reports.
    nonisolated static func peakAmplitude(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return 0 }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            block, atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr, let dp = dataPointer else { return 0 }

        // Determine the sample format from the buffer's format description.
        var bytesPerSample = 4
        var isFloat = true
        if let fd = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee {
            bytesPerSample = Int(asbd.mBitsPerChannel / 8)
            isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        }

        let count = length / max(bytesPerSample, 1)
        guard count > 0 else { return 0 }

        if isFloat && bytesPerSample == 4 {
            let ptr = dp.withMemoryRebound(to: Float32.self, capacity: count) { $0 }
            var peak: Float = 0
            vDSP_maxmgv(ptr, 1, &peak, vDSP_Length(count))
            return min(peak, 1)
        } else if !isFloat && bytesPerSample == 2 {
            let ptr = dp.withMemoryRebound(to: Int16.self, capacity: count) { $0 }
            var peak: Int16 = 0
            // vDSP doesn't have an Int16 maxmgv variant on every platform; loop.
            for i in 0..<count {
                let v = abs(Int(ptr[i]))
                if v > peak { peak = Int16(v) }
            }
            return Float(peak) / Float(Int16.max)
        }
        return 0
    }
}
