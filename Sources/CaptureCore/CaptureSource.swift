import CoreGraphics
import Foundation
import ScreenCaptureKit

/// What the user picked to record. The UI works in terms of identifiers
/// (`DisplayInfo.id`, `WindowInfo.id`, `AppInfo.id`); these get resolved into
/// live `SCDisplay` / `SCWindow` / `SCRunningApplication` objects when the
/// recording starts.
public enum CaptureSource: Sendable, Hashable {
    /// Whole display, optionally cropped to a region in display points.
    case display(id: CGDirectDisplayID, region: CGRect? = nil)

    /// A specific window. Captures only that window even if it moves.
    case window(id: CGWindowID)

    /// All on-screen windows of a given app on a given display.
    case application(pid: pid_t, displayID: CGDirectDisplayID)
}

/// Output dimensions and timing settings for the SCStream.
public struct CaptureGeometry: Sendable {
    public var outputWidth: Int
    public var outputHeight: Int
    public var fps: Int
    public var showsCursor: Bool

    public init(outputWidth: Int, outputHeight: Int, fps: Int = 60, showsCursor: Bool = true) {
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.fps = fps
        self.showsCursor = showsCursor
    }
}
