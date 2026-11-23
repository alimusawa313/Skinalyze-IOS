import Foundation

// P3 trigger journal and P4 Apple Health patterns. Patterns describe what coincided in the user's own data —
// never a cause, never advice (FEATURES.md §0 rule 2). Shown only after four weeks of journal days, and only when
// both sides have enough scans.

public enum JournalTag: String, CaseIterable, Codable, Sendable {
    case sleptBadly, stressed, sweets, dairy, friedFood, alcohol, workout, period, travel, newProduct, touchedFace
}

public struct JournalEntry: Codable, Equatable, Sendable {
    public let day: DayStamp
    public var tags: Set<JournalTag>

    public init(day: DayStamp, tags: Set<JournalTag>) {
        self.day = day
        self.tags = tags
    }
}

public struct TriggerPattern: Sendable, Equatable {
    public enum Direction: Sendable, Equatable { case more, fewer }

    public let tag: JournalTag
    public let direction: Direction
    /// Median breakout index of scans after days with / without the tag.
    public let withTag: Double
    public let withoutTag: Double
    public let scansWith: Int
    public let scansWithout: Int
}

public enum TriggerEngine {
    /// A tag counts for a scan when it was logged on the scan day or the days before it.
    public static let windowDays = 3
    /// Journal days needed (spread over at least this many days) before any pattern shows.
    public static let minimumSpanDays = 28
    public static let minimumScansEachSide = 3
    /// The two medians must differ by at least this share (and by at least `minimumDifference` points).
    public static let minimumRelativeDifference = 0.2
    public static let minimumDifference = 2.0

    /// Whether there is enough journal history yet.
    public static func hasEnoughHistory(_ entries: [JournalEntry], calendar: Calendar) -> Bool {
        let days = entries.filter { !$0.tags.isEmpty }.map(\.day)
        guard let first = days.min(), let last = days.max() else { return false }
        let span = calendar.dateComponents([.day], from: first.date(in: calendar), to: last.date(in: calendar)).day ?? 0
        return span + 1 >= minimumSpanDays
    }

    /// Days until patterns can show (0 when ready).
    public static func daysUntilReady(_ entries: [JournalEntry], today: DayStamp, calendar: Calendar) -> Int {
        guard let first = entries.filter({ !$0.tags.isEmpty }).map(\.day).min() else { return minimumSpanDays }
        let span = (calendar.dateComponents([.day], from: first.date(in: calendar), to: today.date(in: calendar)).day ?? 0) + 1
        return max(0, minimumSpanDays - span)
    }

    public static func patterns(entries: [JournalEntry], scans: [InsightEngine.Point], calendar: Calendar) -> [TriggerPattern] {
        guard hasEnoughHistory(entries, calendar: calendar) else { return [] }
        let byDay = Dictionary(entries.map { ($0.day, $0.tags) }, uniquingKeysWith: { $0.union($1) })
        let firstJournalDay = entries.map(\.day).min()
        // Only scans the journal could have covered.
        let covered = scans.filter { point in
            guard let firstJournalDay else { return false }
            return DayStamp(point.date, calendar: calendar) >= firstJournalDay
        }
        func tags(before point: InsightEngine.Point) -> Set<JournalTag> {
            let day = DayStamp(point.date, calendar: calendar)
            return (0...windowDays).reduce(into: Set<JournalTag>()) { result, offset in
                result.formUnion(byDay[day.adding(days: -offset, calendar: calendar)] ?? [])
            }
        }
        let tagged = covered.map { ($0, tags(before: $0)) }
        return JournalTag.allCases.compactMap { tag in
            let with = tagged.filter { $0.1.contains(tag) }.map(\.0.index)
            let without = tagged.filter { !$0.1.contains(tag) }.map(\.0.index)
            guard with.count >= minimumScansEachSide, without.count >= minimumScansEachSide else { return nil }
            let a = ProductEffect.median(with), b = ProductEffect.median(without)
            let difference = abs(a - b)
            guard difference >= minimumDifference, difference >= minimumRelativeDifference * max(a, b) else { return nil }
            return TriggerPattern(tag: tag, direction: a > b ? .more : .fewer, withTag: a, withoutTag: b,
                                  scansWith: with.count, scansWithout: without.count)
        }
        .sorted { abs($0.withTag - $0.withoutTag) > abs($1.withTag - $1.withoutTag) }
    }

    /// Apple Health nights and period days turned into journal tags (computed on demand, never stored).
    /// Short sleep is a night under `shortSleepHours`; the night is credited to the morning it ended.
    public static let shortSleepHours = 6.0

    public static func healthEntries(sleepHours: [DayStamp: Double], periodDays: Set<DayStamp>) -> [JournalEntry] {
        var tags: [DayStamp: Set<JournalTag>] = [:]
        for (day, hours) in sleepHours where hours > 0 && hours < shortSleepHours { tags[day, default: []].insert(.sleptBadly) }
        for day in periodDays { tags[day, default: []].insert(.period) }
        return tags.map { JournalEntry(day: $0.key, tags: $0.value) }.sorted { $0.day < $1.day }
    }
}
