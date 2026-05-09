# Free Mac Screen Recorder

A native macOS screen recorder for Apple Silicon, built on Apple's
**ScreenCaptureKit** + **AVFoundation** + **VideoToolbox**.

- Record any **display**, **window**, or **app**
- Custom region + custom output resolution
- Microphone and **system audio** (macOS 13+)
- Hardware-accelerated **H.264 / HEVC / ProRes** output
- Live device picker (cameras, mics) with hot-swap
- 100% local, no telemetry, no watermark

## Status

Early development. Phase 1 MVP: display capture → MP4 with mic audio.
See `docs/roadmap.md` for the feature roadmap.

## Requirements

- macOS 13.0 (Ventura) or later — macOS 14+ recommended
- Apple Silicon (Apple Silicon native; Intel may work but is untested)
- Swift 5.9+ (Xcode 15+ for full development; Command Line Tools sufficient
  to compile the binary)

## Build

```bash
# Just compile (fast feedback loop)
swift build

# Build a runnable .app bundle (release, ad-hoc signed for local dev)
./Scripts/build-app.sh release
open "dist/Free Mac Screen Recorder.app"
```

> **Note**: To distribute the app to other machines you need full Xcode plus
> a Developer ID certificate, and to notarize the bundle with `notarytool`.
> The build script above produces an ad-hoc signed bundle that runs locally
> only.

## First-launch permissions

On first run, macOS will prompt for:

- **Screen Recording** — required for ScreenCaptureKit
- **Camera** — only if you enable webcam PiP
- **Microphone** — only if you enable mic capture

Grant them in *System Settings → Privacy & Security* and **relaunch the app**.

## Architecture

```
FreeMacScreenRecorder (executable)
└── RecorderUI       — SwiftUI views, app entry point
    ├── CaptureCore  — ScreenCaptureKit wrapper, SCStream lifecycle
    ├── DeviceKit    — AVFoundation device enumeration + hot-swap
    └── EncoderKit   — AVAssetWriter + VideoToolbox configuration
```

## Foundations

This project is a clean-room implementation built on Apple's first-party
APIs and patterns from the most trusted open-source references:

- [Apple — ScreenCaptureKit documentation](https://developer.apple.com/documentation/screencapturekit/)
- [Apple — Capturing screen content in macOS (sample code)](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [WWDC22 — Meet ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2022/10156/)
- [Aperture by Sindre Sorhus (MIT)](https://github.com/wulkano/Aperture) — embedding patterns
- [QuickRecorder (lihaoyun6, GPL-3.0)](https://github.com/lihaoyun6/QuickRecorder) — feature reference only

No code is copied from GPL projects. Patterns from MIT-licensed projects
are followed as references; original code is written here.

## License

MIT (see `LICENSE`).
