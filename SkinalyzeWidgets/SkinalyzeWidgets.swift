import AppIntents
import Charts
import SwiftUI
import WidgetKit
import SkinalyzeKit

@main
struct SkinalyzeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkinTrendWidget()
        PimpiWidget()
        SkinCardWidget()
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
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Skin")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(Metrics.labelTracking)
                        .foregroundStyle(Color.ds.inkSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(entry.snapshot.breakoutIndex.map(String.init) ?? "–")
                            .font(.ds.numeral)
                            .foregroundStyle(Color.ds.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(Metrics.numeralScale)
                            .contentTransition(.numericText())
                        if family == .systemMedium, let delta = entry.snapshot.delta { DeltaBadge(delta: delta) }
                    }
                    if let band { BandPill(band) }
                    Spacer(minLength: 0)
                    Text(daysLine)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                }
                if family == .systemMedium, entry.snapshot.trend.count >= 2 {
                    trendChart
                }
            }
        }
    }

    private enum Metrics {
        static let labelTracking: CGFloat = 1.2
        static let numeralScale: CGFloat = 0.5
        static let line: CGFloat = 4
        static let point: CGFloat = 14
        static let pointRing: CGFloat = 3
    }

    /// The trend as a hill: pink area, a heavy ink line, the latest scan as a dot in its band's colour.
    private var trendChart: some View {
        let points = Array(entry.snapshot.trend.enumerated())
        return Chart {
            ForEach(points, id: \.offset) { point in
                AreaMark(x: .value("Scan", point.offset), y: .value("Index", point.element))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.ds.hill)
                LineMark(x: .value("Scan", point.offset), y: .value("Index", point.element))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.ds.ink)
                    .lineStyle(StrokeStyle(lineWidth: Metrics.line, lineCap: .round, lineJoin: .round))
            }
            if let last = points.last {
                PointMark(x: .value("Scan", last.offset), y: .value("Index", last.element))
                    .symbol {
                        Circle()
                            .fill(band.map { Color.ds.band($0) } ?? Color.ds.surface)
                            .overlay(Circle().strokeBorder(Color.ds.ink, lineWidth: Metrics.pointRing))
                            .frame(width: Metrics.point, height: Metrics.point)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
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

// MARK: - Skin card (looks like the card; no photo)

struct SkinCardEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let mood: MascotMood
}

struct SkinCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkinCardEntry {
        SkinCardEntry(date: .now, snapshot: WidgetSnapshot(lastScanDate: .now, breakoutIndex: 6, bandRaw: "mild", delta: -2, trend: []),
                      mood: .happy)
    }

    func getSnapshot(in context: Context, completion: @escaping (SkinCardEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkinCardEntry>) -> Void) {
        // The app reloads timelines after every scan; the daily refresh keeps Pimpi's mood current.
        let next = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(at: .now)], policy: .after(next)))
    }

    private func entry(at date: Date) -> SkinCardEntry {
        SkinCardEntry(date: date, snapshot: WidgetSummary.load(),
                      mood: EngagementShared.load().state(at: date, calendar: .current).mood)
    }
}

struct SkinCardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SkinCard", provider: SkinCardProvider()) { entry in
            SkinCardWidgetView(snapshot: entry.snapshot, mood: entry.mood)
                .environment(\.pimpiOutfit, EngagementShared.loadOutfit())
                .containerBackground(for: .widget) { SkinCardWidgetView.background(for: entry.snapshot) }
                .widgetURL(URL(string: entry.snapshot.breakoutIndex == nil ? "skinalyze://scan" : "skinalyze://timeline"))
        }
        .configurationDisplayName("Skin card")
        .description("Your latest scan as a card. No photo.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Pimpi (streak + mood)

struct PimpiEntry: TimelineEntry {
    let date: Date
    let state: EngagementSnapshot.State
}

/// Works the streaks and Pimpi's mood out from the shared snapshot at each entry's time, so the widget changes
/// through the day (worried in the evening, a fresh day after midnight) without the app being opened.
struct PimpiProvider: TimelineProvider {
    private static let sample = EngagementSnapshot.State(
        routine: RoutineStreak(count: 5, status: .doneToday, milestone: nil),
        scan: ScanStreak(weeks: 3, status: .doneThisWeek, milestone: nil), mood: .happy)

    func placeholder(in context: Context) -> PimpiEntry { PimpiEntry(date: .now, state: Self.sample) }

    func getSnapshot(in context: Context, completion: @escaping (PimpiEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PimpiEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date.now
        let startOfTomorrow = calendar.startOfDay(for: now.addingTimeInterval(86_400))
        // Moments today when the state can change by itself.
        let hours = [StreakEngine.atRiskHour, PimpiMoodEngine.sleepyFromHour]
        let moments = hours.compactMap { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now) }.filter { $0 > now }
        let dates = [now] + moments + [startOfTomorrow.addingTimeInterval(60)]
        completion(Timeline(entries: dates.map(entry(at:)), policy: .after(startOfTomorrow.addingTimeInterval(3600 * 6))))
    }

    private func entry(at date: Date) -> PimpiEntry {
        PimpiEntry(date: date, state: EngagementShared.load().state(at: date, calendar: .current))
    }
}

struct PimpiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Pimpi", provider: PimpiProvider()) { entry in
            PimpiWidgetEntryView(entry: entry)
                .environment(\.pimpiOutfit, EngagementShared.loadOutfit())
                .containerBackground(for: .widget) { PimpiWidgetView.background }
                .widgetURL(URL(string: "skinalyze://today"))
        }
        .configurationDisplayName("Pimpi")
        .description("Pimpi and your streak.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

/// Reads the family the system asked for and hands it to the shared view.
private struct PimpiWidgetEntryView: View {
    let entry: PimpiEntry
    @Environment(\.widgetFamily) private var family

    var body: some View { PimpiWidgetView(state: entry.state, family: family) }
}
