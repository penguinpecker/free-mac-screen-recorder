import AVFoundation
import Foundation

/// A normalized representation of an AVCaptureDevice for UI display.
public struct AVDevice: Identifiable, Hashable, Sendable {
    public let id: String           // AVCaptureDevice.uniqueID
    public let localizedName: String
    public let modelID: String
    public let manufacturer: String
    public let kind: Kind

    public enum Kind: String, Sendable {
        case camera
        case microphone
    }

    public init(_ device: AVCaptureDevice, kind: Kind) {
        self.id = device.uniqueID
        self.localizedName = device.localizedName
        self.modelID = device.modelID
        self.manufacturer = device.manufacturer
        self.kind = kind
    }
}
