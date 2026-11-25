import Charts
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Breakout index over time: a thin ink line with each scan as a band-coloured dot. Drag to scrub — each scan ticks
/// with a selection haptic.
struct TrendChart: View {
    let scans: [ScanSession]
    @State private var selectedDate: Date?

    private enum Metrics {
        static let line: CGFloat = 3
        static let dot: CGFloat = 10
        static let dotSelected: CGFloat = 18
        static let dotRing: CGFloat = 2.5
    }

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
                Text("Breakout index").font(.system(.headline, design: .rounded).weight(.heavy))
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
                    .lineStyle(StrokeStyle(lineWidth: Metrics.line, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.ds.ink)
                PointMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .symbol {
                        let side = scan == selected ? Metrics.dotSelected : Metrics.dot
                        Circle()
                            .fill(Color.ds.band(scan.band))
                            .stroke(Color.ds.ink, lineWidth: Metrics.dotRing)
                            .frame(width: side, height: side)
                    }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis { AxisMarks(position: .leading) }
            .accessibilityLabel("Breakout index over time")
            .sensoryFeedback(Haptic.scrub, trigger: selected?.id)
        }
        .foregroundStyle(Color.ds.ink)
        .padding(.vertical, Spacing.xs)
    }
}
