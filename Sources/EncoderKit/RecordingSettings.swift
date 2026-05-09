import CoreGraphics
import Foundation

public struct RecordingSettings: Sendable {
    public var width: Int
    public var height: Int
    public var fps: Int
    public var codec: OutputCodec
    public var bitrate: Int?              // bits per second; nil = auto
    public var captureMicrophone: Bool
    public var captureSystemAudio: Bool
    public var microphoneDeviceID: String?  // AVCaptureDevice.uniqueID
    public var outputURL: URL

    public init(
        width: Int,
        height: Int,
        fps: Int = 60,
        codec: OutputCodec = .h264,
        bitrate: Int? = nil,
        captureMicrophone: Bool = false,
        captureSystemAudio: Bool = true,
        microphoneDeviceID: String? = nil,
        outputURL: URL
    ) {
        self.width = width
        self.height = height
        self.fps = fps
        self.codec = codec
        self.bitrate = bitrate
        self.captureMicrophone = captureMicrophone
        self.captureSystemAudio = captureSystemAudio
        self.microphoneDeviceID = microphoneDeviceID
        self.outputURL = outputURL
    }

    /// Default bitrate (bps) when `bitrate` is nil. Heuristic: ~0.1 bits per
    /// pixel per frame for H.264, halved for HEVC.
    public var effectiveBitrate: Int {
        if let bitrate { return bitrate }
        let pixelsPerSecond = Double(width * height * fps)
        let bitsPerPixel: Double
        switch codec {
        case .h264:                       bitsPerPixel = 0.10
        case .hevc:                       bitsPerPixel = 0.06
        case .proRes422, .proRes4444:     bitsPerPixel = 0.0  // ProRes ignores this
        }
        return max(1_000_000, Int(pixelsPerSecond * bitsPerPixel))
    }
}
