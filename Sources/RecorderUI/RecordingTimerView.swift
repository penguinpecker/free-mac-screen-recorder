import SwiftUI

/// A view that ticks once per second to render an elapsed-time string.
/// SwiftUI's `TimelineView` is the cheapest way to do this without owning a
/// Timer or polluting the view model.
struct RecordingTimerView: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secs = Int(context.date.timeIntervalSince(startedAt))
            Text(String(format: "Recording — %02d:%02d:%02d",
                        secs / 3600, (secs / 60) % 60, secs % 60))
        }
    }
}
