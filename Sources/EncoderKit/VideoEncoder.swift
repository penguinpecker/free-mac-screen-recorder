import AVFoundation
import CoreMedia
import Foundation
import OSLog

/// Wraps `AVAssetWriter` to consume `CMSampleBuffer`s from ScreenCaptureKit
/// and from `AVCaptureSession` audio inputs, and produce a single output file.
///
/// Pattern follows Apple's "Capturing screen content in macOS" sample:
/// https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
public final class VideoEncoder: @unchecked Sendable {
    public enum EncoderError: Error {
        case writerInitFailed(String)
        case notStarted
        case alreadyStarted
        case finishFailed(String)
    }

    private let log = Logger(subsystem: "com.freemacscreenrecorder.app", category: "VideoEncoder")
    private let settings: RecordingSettings

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?

    private var sessionStarted = false
    private let queue = DispatchQueue(label: "com.freemacscreenrecorder.encoder", qos: .userInitiated)

    // Pause / resume: track total paused duration so PTS can be rewritten and
    // the recording excises pause intervals rather than freezing on a frame.
    private var paused = false
    private var pauseStartPTS: CMTime?
    private var totalPausedDuration: CMTime = .zero
    private var lastSeenPTS: CMTime = .zero

    public init(settings: RecordingSettings) {
        self.settings = settings
    }

    public var isPaused: Bool {
        queue.sync { paused }
    }

    public func pause() {
        queue.sync {
            guard !paused else { return }
            paused = true
            pauseStartPTS = lastSeenPTS
        }
    }

    public func resume() {
        queue.sync {
            guard paused, let start = pauseStartPTS else { paused = false; return }
            // Add the gap between when we paused and "now" to the offset so the
            // next frame appears immediately after the last appended one.
            let gap = CMTimeSubtract(lastSeenPTS, start)
            totalPausedDuration = CMTimeAdd(totalPausedDuration, gap)
            paused = false
            pauseStartPTS = nil
        }
    }

    public func start() throws {
        guard writer == nil else { throw EncoderError.alreadyStarted }

        // Make sure the parent directory exists and remove any stale file.
        let url = settings.outputURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: settings.codec.avFileType)
        } catch {
            throw EncoderError.writerInitFailed(error.localizedDescription)
        }
        writer.shouldOptimizeForNetworkUse = true

        // ── Video input ────────────────────────────────────────────────────
        var videoSettings: [String: Any] = [
            AVVideoCodecKey: settings.codec.avVideoCodec,
            AVVideoWidthKey: settings.width,
            AVVideoHeightKey: settings.height,
        ]
        switch settings.codec {
        case .h264, .hevc:
            videoSettings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: settings.effectiveBitrate,
                AVVideoExpectedSourceFrameRateKey: settings.fps,
                AVVideoMaxKeyFrameIntervalKey: settings.fps * 2,
                AVVideoAllowFrameReorderingKey: false,
            ]
        case .proRes422, .proRes4444:
            // ProRes is intra-frame; no bitrate / GOP knobs.
            break
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw EncoderError.writerInitFailed("Writer rejected video input")
        }
        writer.add(videoInput)
        self.videoInput = videoInput

        // ── Audio inputs (mic + system audio as separate tracks) ──────────
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48_000,
            AVEncoderBitRateKey: 192_000,
        ]
        if settings.captureMicrophone {
            let mic = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            mic.expectsMediaDataInRealTime = true
            if writer.canAdd(mic) {
                writer.add(mic)
                self.micInput = mic
            }
        }
        if settings.captureSystemAudio {
            let sys = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            sys.expectsMediaDataInRealTime = true
            if writer.canAdd(sys) {
                writer.add(sys)
                self.systemAudioInput = sys
            }
        }

        guard writer.startWriting() else {
            throw EncoderError.writerInitFailed(
                writer.error?.localizedDescription ?? "startWriting() returned false"
            )
        }
        self.writer = writer
        log.info("Encoder started: \(url.path, privacy: .public)")
    }

    public enum SampleKind: Sendable {
        case video
        case microphone
        case systemAudio
    }

    /// Append a sample buffer. Called from the SCStream / AVCaptureSession
    /// delegate threads — internally serialized onto the encoder queue.
    public func append(_ sampleBuffer: CMSampleBuffer, kind: SampleKind) {
        queue.async { [weak self] in
            guard let self, let writer = self.writer else { return }

            let originalPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            // Track the most-recent PTS we've seen even when paused so we can
            // measure the gap correctly on resume.
            self.lastSeenPTS = originalPTS

            if self.paused { return }

            // Start the session at the timestamp of the first video frame —
            // this is what ScreenCaptureKit recommends to keep video/audio
            // tracks aligned.
            if !self.sessionStarted {
                guard kind == .video else { return }   // wait for first video frame
                writer.startSession(atSourceTime: originalPTS)
                self.sessionStarted = true
                self.log.info("Encoder session started @\(originalPTS.seconds, privacy: .public)s")
            }

            let input: AVAssetWriterInput?
            switch kind {
            case .video:        input = self.videoInput
            case .microphone:   input = self.micInput
            case .systemAudio:  input = self.systemAudioInput
            }
            guard let input, input.isReadyForMoreMediaData else { return }

            // Rewrite PTS to subtract any time the user spent paused so the
            // pause interval is excised from the output rather than freezing
            // on a single frame.
            let buffer: CMSampleBuffer
            if self.totalPausedDuration > .zero {
                let adjustedPTS = CMTimeSubtract(originalPTS, self.totalPausedDuration)
                let timing = CMSampleTimingInfo(
                    duration: CMSampleBufferGetDuration(sampleBuffer),
                    presentationTimeStamp: adjustedPTS,
                    decodeTimeStamp: .invalid
                )
                var rewritten: CMSampleBuffer?
                let status = CMSampleBufferCreateCopyWithNewTiming(
                    allocator: kCFAllocatorDefault,
                    sampleBuffer: sampleBuffer,
                    sampleTimingEntryCount: 1,
                    sampleTimingArray: [timing],
                    sampleBufferOut: &rewritten
                )
                guard status == noErr, let rewritten else { return }
                buffer = rewritten
            } else {
                buffer = sampleBuffer
            }

            input.append(buffer)
        }
    }

    public func finish() async throws -> URL {
        guard let writer = self.writer else { throw EncoderError.notStarted }

        // Drain queued appends before finalizing.
        await withCheckedContinuation { cont in
            queue.async { cont.resume() }
        }

        videoInput?.markAsFinished()
        micInput?.markAsFinished()
        systemAudioInput?.markAsFinished()

        await writer.finishWriting()

        if writer.status == .failed {
            throw EncoderError.finishFailed(
                writer.error?.localizedDescription ?? "unknown writer failure"
            )
        }
        log.info("Encoder finished: \(writer.outputURL.path, privacy: .public)")
        return writer.outputURL
    }
}
