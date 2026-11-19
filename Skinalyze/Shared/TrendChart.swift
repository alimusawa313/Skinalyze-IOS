import Charts
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Breakout index over time. Drag to scrub — each scan ticks with a selection haptic.
struct TrendChart: View {
    let scans: [ScanSession]
    @State private var selectedDate: Date?

    private var points: [ScanSession] { scans.sorted { $0.createdAt < $1.createdAt } }

    private var selected: ScanSession? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.createdAt.timeIntervalSince(selectedDate)) < abs($1.createdAt.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Breakout index").font(.ds.headline)
                Spacer()
                if let selected {
                    Text("\(selected.breakoutIndex) · \(selected.createdAt.formatted(.dateTime.day().month()))")
                        .font(.ds.callout.monospacedDigit())
                        .foregroundStyle(Color.ds.inkSecondary)
                }
            }
            Chart(points) { scan in
                LineMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.ds.signal)
                PointMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .foregroundStyle(Color.ds.band(scan.band))
                    .symbolSize(scan == selected ? 140 : 60)
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis { AxisMarks(position: .leading) }
            .accessibilityLabel("Breakout index over time")
            .sensoryFeedback(Haptic.scrub, trigger: selected?.id)
        }
        .padding(.vertical, Spacing.xs)
    }
}
