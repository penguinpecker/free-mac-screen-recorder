# Free Mac Screen Recorder

> A free, open-source, **native macOS screen recorder** for Apple Silicon —
> built on Apple's **ScreenCaptureKit**, **AVFoundation**, and
> **VideoToolbox**. Record any display, window, app, or custom region with
> system audio, microphone, webcam picture-in-picture, and click highlights.
> No watermark. No subscription. No telemetry. No cloud upload.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: macOS 13+](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-success)]()
[![Swift 6](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/penguinpecker/free-mac-screen-recorder/pulls)

**Free Mac Screen Recorder** is a privacy-first, native screen recording app
for macOS — a free open-source alternative to Loom, CleanShot X, ScreenFlow,
Camtasia, and the built-in QuickTime Player. Capture your **screen**, a
**single window**, a **specific app**, or a **custom drag-selected region**.
Record **system audio** and **microphone** at the same time. Add a circular
**webcam picture-in-picture overlay**, **mouse click highlights**, and a
**keystroke overlay** for tutorial videos. Export to **MP4 (H.264 / HEVC)**,
**MOV (Apple ProRes 422 / 4444)**, or animated **GIF**.

Everything is local. The app never phones home, never inserts a watermark,
and never asks you to sign in.

---

## Table of contents

- [Why this exists](#why-this-exists)
- [Features](#features)
- [Comparison vs paid Mac screen recorders](#comparison-vs-paid-mac-screen-recorders)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Permissions](#permissions)
- [Output formats](#output-formats)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Architecture](#architecture)
- [Frequently asked questions](#frequently-asked-questions-faq)
- [Roadmap](#roadmap)
- [Articles & references](#articles--references)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Why this exists

Most "free" Mac screen recorders aren't actually free — they cap your
recording length, add a watermark, force a sign-in, or upload your video to
a cloud service before letting you download it. Paid alternatives are great
but cost \$8–\$30/month. The frameworks Apple ships in modern macOS are
fast, hardware-accelerated, and capable of everything those paid apps do.

This project is a clean-room implementation that makes those frameworks
directly available as a polished desktop app. It runs locally, has zero
dependencies on outside services, and is small enough that you can read the
entire source in an afternoon.

If you want a **screen recorder for Mac with no watermark**, with **system
audio**, with a **webcam overlay**, that runs **natively on Apple Silicon**
and is **fully open-source under MIT**, this is for you.

---

## Features

### Capture

- 📺 **Full display** capture (any number of monitors)
- 🪟 **Single window** capture — follows the window if it moves
- 🎯 **Specific application** capture (all on-screen windows of one app)
- ✂️ **Custom region** — drag-to-select a rectangle across any display
- 📐 **Custom output resolution** — downscale to 720p / 1080p / 1440p / 4K or any W×H
- 🖱️ Cursor visibility toggle
- 🎞️ Frame rates from **24 to 120 fps**

### Audio

- 🔊 **System audio** capture (native via ScreenCaptureKit on macOS 13+)
- 🎙️ **Microphone** input from any AV device — built-in, USB, AirPods, virtual
- 🔥 **Hot-swap** detection: plug in a USB mic mid-session and the picker updates
- 📊 Live **VU-style level meters** for both inputs while recording
- 📂 Mic and system audio are written as **separate tracks** for editing flexibility

### Overlays

- 📷 **Webcam picture-in-picture** — circular AVCaptureVideoPreviewLayer
  panel, four corners, three sizes, draggable, shadowed
- 💆 **Click highlights** — animated ripple at every left/right/middle click
- ⌨️ **Keystroke overlay** — chip near the bottom shows ⌘⇧K-style key prompts
  with auto-fade
- All overlays appear in display + region recordings

### Output

- 🎬 **MP4** with **H.264** (universally compatible)
- 🎬 **MP4** with **HEVC / H.265** (smaller files, same quality)
- 🎞️ **MOV** with **Apple ProRes 422** or **ProRes 4444** (editing pipelines)
- 🖼️ **Animated GIF** export from any recording (configurable fps + width)
- 🎚️ Auto bitrate or manual bits-per-second
- 🛠️ Hardware-accelerated encoding via VideoToolbox

### Workflow

- ⏯️ **Pause / resume** — paused intervals are excised from the output (no frozen frames)
- 🎭 **Named presets** — save the current configuration and recall it later
- 📚 **Recordings library** — browse past recordings with date, size, duration
- 🔄 **Rename**, **drag-out** to Finder/Slack/Mail, **delete to Trash**
- ⌨️ **Global hotkeys**: ⌘⇧R to start, ⌘⇧S to stop — works from any app
- 📍 **Menu bar status item** — quick toggle without opening the main window
- ⚙️ **Settings panel** — change output folder, default codec, default fps,
  cursor visibility, system audio default

### Privacy & footprint

- 🛡️ 100% local — no analytics, no error reporting, no auto-updates phoning home
- 🚫 No watermark, no time limit, no sign-in
- 📦 Tiny binary, written entirely in Swift, no JavaScript runtime, no Electron

---

## Comparison vs paid Mac screen recorders

|                              | Free Mac Screen Recorder | QuickTime | Loom | CleanShot X | ScreenFlow | Camtasia |
|------------------------------|:------------------------:|:---------:|:----:|:-----------:|:----------:|:--------:|
| Free                         | ✅ MIT                   | ✅        | ⚠️ Limited free tier | ❌ \$29 one-off | ❌ \$169 | ❌ \$300 |
| Open source                  | ✅                       | ❌        | ❌   | ❌          | ❌         | ❌       |
| No watermark                 | ✅                       | ✅        | ⚠️ Free tier limits  | ✅          | ✅         | ✅       |
| System audio (mic + speakers)| ✅                       | ⚠️ Mic only on stock | ✅ | ✅ | ✅ | ✅ |
| Display capture              | ✅                       | ✅        | ✅   | ✅          | ✅         | ✅       |
| Window capture               | ✅                       | ❌        | ❌   | ✅          | ✅         | ✅       |
| App capture                  | ✅                       | ❌        | ❌   | ⚠️          | ❌         | ❌       |
| Region capture               | ✅                       | ❌        | ❌   | ✅          | ✅         | ✅       |
| Webcam PiP                   | ✅                       | ❌        | ✅   | ✅          | ✅         | ✅       |
| Click highlights             | ✅                       | ❌        | ❌   | ✅          | ✅         | ✅       |
| Keystroke overlay            | ✅                       | ❌        | ❌   | ❌          | ✅         | ✅       |
| ProRes output                | ✅                       | ❌        | ❌   | ❌          | ✅         | ❌       |
| GIF export                   | ✅                       | ❌        | ✅   | ✅          | ❌         | ❌       |
| Apple Silicon native         | ✅                       | ✅        | ⚠️   | ✅          | ✅         | ⚠️       |
| Local only                   | ✅                       | ✅        | ❌   | ✅          | ✅         | ✅       |

(Comparison points are based on commonly-listed feature pages — verify each
vendor's current offering before switching.)

---

## Requirements

- **macOS 13.0 (Ventura) or later** — macOS 14 (Sonoma) or 15 (Sequoia) recommended
- **Apple Silicon (M-series)** — Intel Macs may work but are untested
- For development:
  - Xcode Command Line Tools (already installed if you have `git` working)
  - Optional: full Xcode for app signing / notarization (only needed if you
    want to distribute the app to other machines)

---

## Install

### Build from source (current path)

```bash
git clone https://github.com/penguinpecker/free-mac-screen-recorder.git
cd free-mac-screen-recorder
swift build                          # fast feedback loop
./Scripts/build-app.sh release       # build the runnable .app bundle
open "dist/Free Mac Screen Recorder.app"
```

The build script wraps the SwiftPM binary into a proper `.app` bundle with
the right `Info.plist` and ad-hoc code signing. It runs locally. To
distribute the app to other machines you'll need full Xcode plus an Apple
Developer ID certificate (out of scope for this README).

### Pre-built download

Pre-built `.app` releases will land on the
[Releases page](https://github.com/penguinpecker/free-mac-screen-recorder/releases)
once notarization is set up. For now, building from source takes ~30 seconds.

---

## Quick start

1. Launch the app.
2. **Pick a source** — Display, Window, App, or Region. For region, click
   *Select Region…* and drag a rectangle.
3. **Choose audio** — toggle *Capture system audio* and/or *Capture microphone*.
4. **(Optional) overlays** — flip on *Webcam picture-in-picture*, *Highlight
   mouse clicks*, or *Show keystrokes*.
5. **Pick a codec** — H.264 for compatibility, HEVC for smaller files,
   ProRes for editing pipelines.
6. Press ⌘⇧R or click *Start Recording*.
7. Press ⌘⇧S or click *Stop Recording* to finish.
8. The recording opens in the library; right-click for *Export as GIF*.

Recordings are saved to `~/Movies/Free Mac Screen Recorder/` by default —
change this in *Free Mac Screen Recorder → Settings*.

---

## Permissions

On first launch macOS will prompt for these. None are sent anywhere by the
app.

| Permission              | Why it's needed                                                                | Required for |
|-------------------------|--------------------------------------------------------------------------------|--------------|
| Screen Recording        | ScreenCaptureKit cannot capture pixels without it                              | All recording |
| Microphone              | AVCaptureSession routes mic audio to the encoder                               | Mic recording |
| Camera                  | AVCaptureSession reads webcam frames for the PiP overlay                       | Webcam PiP    |
| Input Monitoring        | NSEvent.addGlobalMonitor reads keystrokes typed in other apps                  | Keystroke overlay |

After granting any of these, **quit and relaunch** the app — macOS does not
re-evaluate TCC for an already-running process.

---

## Output formats

| Codec              | Container | Best for                                                  |
|--------------------|-----------|-----------------------------------------------------------|
| H.264              | MP4       | Universal compatibility, smallest learning curve          |
| HEVC (H.265)       | MP4       | ~50% smaller files at the same visual quality             |
| Apple ProRes 422   | MOV       | Editing in Final Cut Pro / DaVinci Resolve / Premiere     |
| Apple ProRes 4444  | MOV       | Editing with alpha; archival-grade quality                |
| Animated GIF       | GIF       | Slack / Twitter / GitHub issue attachments (post-export)  |

All video encoding happens on the GPU via Apple's VideoToolbox — there is no
CPU-encode fallback path because there's no need for one on Apple Silicon.

---

## Keyboard shortcuts

| Action               | Shortcut |
|----------------------|----------|
| Start recording      | ⌘⇧R (system-wide) |
| Stop recording       | ⌘⇧S (system-wide) |
| Quit app             | ⌘Q       |

The system-wide hotkeys are registered through the Carbon
`RegisterEventHotKey` API, which does **not** require Accessibility or Input
Monitoring permission.

---

## Architecture

The codebase is split into four small Swift packages:

```
FreeMacScreenRecorder (executable)
└── RecorderUI       — SwiftUI views, app entry point, overlays, settings
    ├── CaptureCore  — ScreenCaptureKit wrapper (SCStream, filters, audio)
    ├── DeviceKit    — AVCaptureDevice enumeration with hot-swap detection
    └── EncoderKit   — AVAssetWriter, VideoToolbox configs, GIF exporter
```

Highlights:

- **`CaptureCore.CaptureSession`** wires `SCStream` → `CMSampleBuffer`s →
  the encoder, with mic feed coming in from a parallel `AVCaptureSession`.
- **`EncoderKit.VideoEncoder`** wraps `AVAssetWriter` with three inputs
  (video, mic, system audio) and rewrites PTS via
  `CMSampleBufferCreateCopyWithNewTiming` to support pause / resume.
- **`RecorderUI.RegionSelector`** spawns a translucent `NSPanel` per
  display and resolves a rectangle in display-coordinate space (top-down,
  the system `SCStreamConfiguration.sourceRect` expects).
- **`RecorderUI.WebcamOverlayController`** + **`ClickHighlightController`** +
  **`KeystrokeOverlayController`** publish their `CGWindowID`s so
  `SCContentFilter` can except them from the recorder's exclusion list,
  letting the overlays appear in the recording.

---

## Frequently asked questions (FAQ)

### Does this record system audio on a Mac?

Yes. ScreenCaptureKit on macOS 13+ supports system audio capture natively
without any virtual audio driver. Earlier macOS versions required tools like
BlackHole; this app raises the minimum to Ventura specifically so that's not
needed.

### Can it record without a watermark?

Yes. The app is open source (MIT) and never overlays a watermark. There is
no commercial tier, no "free trial", and no upgrade prompt — the source code
proves there's nothing of the kind to upgrade to.

### Can I record a single application without recording the rest of the screen?

Yes — pick *App* as the source. SCK captures every on-screen window of that
process and follows them as they move or are reordered.

### Can I record a custom region of the screen?

Yes — pick *Region* and drag a rectangle. Multi-display setups are
supported; the rectangle is captured from whichever display you started the
drag on.

### How do I add a webcam picture-in-picture?

Toggle *Webcam picture-in-picture* in the Overlays section, pick a camera,
and choose a corner and size. The overlay is captured along with the screen
in display + region recordings.

### Can I export a recording as a GIF?

Yes — right-click any item in the Recordings library and choose *Export as
GIF*. Defaults are 12 fps and 600px wide; adjust in code or via a future
settings UI.

### Does it run on Intel Macs?

The Swift package builds on Intel as well, but the project is developed
exclusively against Apple Silicon. ScreenCaptureKit and VideoToolbox both
work on Intel macOS 13+ in principle.

### Is this an alternative to Loom?

Yes, for the recording-and-saving part. Loom's hosted sharing (auto-upload,
hosted video page, view counts) is intentionally not part of this app
because of the "100% local" goal. If you need shareable links, drop the
exported `.mp4` into any sharing tool.

### Is this an alternative to CleanShot X?

For the screen recording feature set, yes. CleanShot also offers screenshot
annotation, scrolling capture, and a built-in cloud — those are out of
scope here.

### Why does it ask for Input Monitoring permission?

Only if you turn on the *Show keystrokes* overlay. Reading keys typed in
other apps requires that permission on macOS. Recording itself does not.

### Where are recordings saved?

Default: `~/Movies/Free Mac Screen Recorder/`. Change via *Free Mac Screen
Recorder → Settings → Output*.

### How do I uninstall?

Quit the app, drag `Free Mac Screen Recorder.app` to the Trash. Cached
preferences live in `~/Library/Preferences/com.freemacscreenrecorder.app.plist`
and saved presets live alongside.

---

## Roadmap

Shipped:

- ✅ Phase 1 — Source picker, mic + system audio, MP4/HEVC/ProRes, custom resolution
- ✅ Phase 2 — Region drag-select, live timer, level meters, recordings library, presets
- ✅ Phase 3 — Webcam PiP, click highlights, global hotkeys, menu bar status
- ✅ Phase 4 — Pause/resume with PTS rewriting, keystroke overlay, GIF export, settings panel, library polish

Planned:

- 🟡 In-app trim before save (drag in/out points on a thumbnail timeline)
- 🟡 Rebindable hotkeys
- 🟡 Cursor click ripple style customization
- 🟡 Live captions / transcription via Apple's speech framework
- 🟡 Auto-zoom on cursor (Screen Studio-style)
- 🟡 Notarized signed release on the GitHub Releases page
- 🟡 Full Xcode project alongside SwiftPM for IDE-driven development

Want a feature on this list to move from 🟡 to ✅? Open an issue or a PR.

---

## Articles & references

If you're curious how the underlying APIs work, these are the sources used
to build this project — all from Apple or trusted open-source projects:

- [Apple — ScreenCaptureKit framework documentation](https://developer.apple.com/documentation/screencapturekit/)
- [Apple — Capturing screen content in macOS (sample code)](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)
- [Apple — AVAssetWriter documentation](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Apple — AVCaptureDevice.DiscoverySession](https://developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession)
- [Apple — VideoToolbox framework](https://developer.apple.com/documentation/videotoolbox)
- [WWDC 2022 — Meet ScreenCaptureKit (Session 10156)](https://developer.apple.com/videos/play/wwdc2022/10156/)
- [WWDC 2022 — Take ScreenCaptureKit to the next level (Session 10155)](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [Aperture by Sindre Sorhus (MIT)](https://github.com/wulkano/Aperture) — Swift recorder library
- [QuickRecorder by lihaoyun6 (GPL-3.0)](https://github.com/lihaoyun6/QuickRecorder) — referenced for feature scope only

---

## Contributing

Issues and pull requests are welcome. The codebase is small enough that a
new contributor can read it end-to-end in an afternoon. Some good first
contributions:

- New presets in the default set (e.g. *Tutorial 1080p60*, *Quick demo 720p30*)
- More click highlight styles
- Trim-before-save UI
- A Sparkle-free auto-update mechanism that just diffs against the latest
  GitHub release tag
- Documentation improvements

Before submitting:

```bash
swift build              # must pass with no warnings
./Scripts/build-app.sh   # must produce a runnable .app
```

No GPL code may be copied into this repository. Patterns from MIT-licensed
projects (notably Aperture) are referenced as patterns; original code is
written here.

---

## License

[MIT](LICENSE). Use it, fork it, ship it commercially. Attribution is
appreciated but not required.

---

## Acknowledgments

This project would not exist without:

- Apple's framework engineers for shipping **ScreenCaptureKit**, the
  modern, hardware-accelerated, no-permission-headache replacement for
  `CGDisplayStream`.
- **Sindre Sorhus** for [Aperture](https://github.com/wulkano/Aperture),
  the canonical Swift-language reference for combining ScreenCaptureKit
  with `AVAssetWriter`.
- The macOS open-source community — Azayaka, BetterCapture, Capso,
  EasyDemo, QuickRecorder, ScreenKite, Snapzy, SwiftCapture — for proving
  every feature on the roadmap is achievable.

---

**Keywords**: free mac screen recorder · open source mac screen recorder ·
mac screen recorder no watermark · mac screen recorder Apple Silicon ·
ScreenCaptureKit screen recorder · macOS Sonoma screen recorder ·
macOS Ventura screen recorder · macOS Sequoia screen recorder ·
free Loom alternative for Mac · open-source CleanShot X alternative ·
record screen with audio on Mac · screen recorder with webcam mac free ·
screen recorder Apple ProRes · best free screen recorder Mac · privacy
screen recorder Mac.
