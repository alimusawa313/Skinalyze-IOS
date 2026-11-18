import AppIntents
import Charts
import SwiftUI
import WidgetKit
import SkinalyzeKit

@main
struct SkinalyzeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkinTrendWidget()
        StartScanControl()
    }
}

struct SkinEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SkinProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkinEntry {
        SkinEntry(date: .now, snapshot: WidgetSnapshot(lastScanDate: .now, breakoutIndex: 6, bandRaw: "mild", delta: -2, trend: [12, 10, 9, 8, 6]))
    }

    func getSnapshot(in context: Context, completion: @escaping (SkinEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SkinEntry(date: .now, snapshot: WidgetSummary.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkinEntry>) -> Void) {
        // Refresh daily so "days since last scan" stays right; the app reloads timelines after every scan.
        let next = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [SkinEntry(date: .now, snapshot: WidgetSummary.load())], policy: .after(next)))
    }
}

struct SkinTrendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SkinTrend", provider: SkinProvider()) { entry in
            SkinTrendView(entry: entry)
                .containerBackground(Color.ds.canvas, for: .widget)
                .widgetURL(URL(string: entry.snapshot.breakoutIndex == nil ? "skinalyze://scan" : "skinalyze://timeline"))
        }
        .configurationDisplayName("Skin trend")
        .description("Your latest breakout index, its change, and days since your last scan.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct SkinTrendView: View {
    let entry: SkinEntry
    @Environment(\.widgetFamily) private var family

    private var band: BreakoutBand? { entry.snapshot.bandRaw.flatMap(BreakoutBand.init(rawValue:)) }

    private var daysSince: Int? {
        entry.snapshot.lastScanDate.map { Calendar.current.dateComponents([.day], from: $0, to: entry.date).day ?? 0 }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(min(entry.snapshot.breakoutIndex ?? 0, 30)), in: 0...30) {
                Image(systemName: "face.dashed")
            } currentValueLabel: {
                Text(entry.snapshot.breakoutIndex.map(String.init) ?? "–")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Skin").font(.headline)
                Text(summaryLine).font(.caption)
                Text(daysLine).font(.caption2)
            }
        default:
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.snapshot.breakoutIndex.map(String.init) ?? "–")
                        .font(.ds.numeral)
                        .foregroundStyle(Color.ds.ink)
                        .contentTransition(.numericText())
                    if let band { BandPill(band) }
                    Spacer(minLength: 0)
                    Text(daysLine).font(.caption2).foregroundStyle(Color.ds.inkSecondary)
                }
                if family == .systemMedium, entry.snapshot.trend.count >= 2 {
                    Chart(Array(entry.snapshot.trend.enumerated()), id: \.offset) { point in
                        LineMark(x: .value("Scan", point.offset), y: .value("Index", point.element))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.ds.signal)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
        }
    }

    private var summaryLine: String {
        guard let index = entry.snapshot.breakoutIndex else { return String(localized: "No scans yet") }
        let delta = entry.snapshot.delta.map { $0 < 0 ? " ↓\(abs($0))" : ($0 > 0 ? " ↑\($0)" : "") } ?? ""
        return String(localized: "Index \(index)\(delta)")
    }

    private var daysLine: String {
        guard let daysSince else { return String(localized: "Tap to scan") }
        return daysSince == 0 ? String(localized: "Scanned today") : String(localized: "\(daysSince)d since last scan")
    }
}

struct StartScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "StartScan") {
            ControlWidgetButton(action: StartScanIntent()) {
                Label("Scan skin", systemImage: "viewfinder")
            }
        }
        .displayName("Scan skin")
        .description("Start a Skinalyze face scan.")
    }
}
