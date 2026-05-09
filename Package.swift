// swift-tools-version: 5.9
// Free Mac Screen Recorder — Swift Package
// Targets macOS 13+ (ScreenCaptureKit baseline) on Apple Silicon.

import PackageDescription

let package = Package(
    name: "FreeMacScreenRecorder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FreeMacScreenRecorder", targets: ["FreeMacScreenRecorder"]),
        .library(name: "CaptureCore", targets: ["CaptureCore"]),
        .library(name: "DeviceKit", targets: ["DeviceKit"]),
        .library(name: "EncoderKit", targets: ["EncoderKit"]),
        .library(name: "RecorderUI", targets: ["RecorderUI"]),
    ],
    targets: [
        .executableTarget(
            name: "FreeMacScreenRecorder",
            dependencies: ["CaptureCore", "DeviceKit", "EncoderKit", "RecorderUI"],
            path: "Sources/FreeMacScreenRecorder"
        ),
        .target(
            name: "CaptureCore",
            dependencies: ["EncoderKit"],
            path: "Sources/CaptureCore"
        ),
        .target(
            name: "DeviceKit",
            path: "Sources/DeviceKit"
        ),
        .target(
            name: "EncoderKit",
            path: "Sources/EncoderKit"
        ),
        .target(
            name: "RecorderUI",
            dependencies: ["CaptureCore", "DeviceKit", "EncoderKit"],
            path: "Sources/RecorderUI"
        ),
    ]
)
