import CaptureCore
import SwiftUI

/// A simple horizontal VU-style level bar driven by an `AudioLevelMonitor`.
struct LevelMeterView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    let kind: Kind

    enum Kind { case mic, system }

    var body: some View {
        let level = (kind == .mic ? monitor.microphoneLevel : monitor.systemAudioLevel)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: kind == .mic ? "mic.fill" : "speaker.wave.2.fill")
                    .font(.caption)
                Text(kind == .mic ? "Microphone" : "System")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.0f dB", 20 * log10(max(level, 0.0001))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(min(level, 1)))
                        .animation(.linear(duration: 0.05), value: level)
                }
            }
            .frame(height: 6)
        }
    }
}
