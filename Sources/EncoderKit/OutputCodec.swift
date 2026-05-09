import AVFoundation
import VideoToolbox

/// Output codec selection. The container is derived from the codec — H.264/HEVC
/// produce `.mp4`; ProRes variants must be muxed into `.mov`.
public enum OutputCodec: String, CaseIterable, Codable, Sendable, Identifiable {
    case h264
    case hevc
    case proRes422
    case proRes4444

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .h264:       return "H.264 (MP4)"
        case .hevc:       return "HEVC / H.265 (MP4)"
        case .proRes422:  return "Apple ProRes 422 (MOV)"
        case .proRes4444: return "Apple ProRes 4444 (MOV)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .h264, .hevc:               return "mp4"
        case .proRes422, .proRes4444:    return "mov"
        }
    }

    public var avFileType: AVFileType {
        switch self {
        case .h264, .hevc:               return .mp4
        case .proRes422, .proRes4444:    return .mov
        }
    }

    public var avVideoCodec: AVVideoCodecType {
        switch self {
        case .h264:       return .h264
        case .hevc:       return .hevc
        case .proRes422:  return .proRes422
        case .proRes4444: return .proRes4444
        }
    }
}
