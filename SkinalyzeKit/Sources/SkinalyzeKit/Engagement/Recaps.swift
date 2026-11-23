import Foundation

// Weekly and monthly recaps (E12, E14) and Skin Wrapped (G6). Recaps count effort — routine days, scans taken,
// quests and lessons done — never a skin result (FEATURES.md §0 rule 1). Wrapped adds two gentle highlights about
// skin, worded "coincided with", and only ever says something good (a zone that calmed, the calmest month).

/// What the user did, as stored by the app.
public struct ActivityHistory: Sendable, Equatable {
    /// Days with at least one routine step checked.
    public var routineDays: Set<DayStamp>
    public var scanDates: [Date]
    /// Quests done per day ("yyyy-MM-dd"), from the reward ledger.
    public var quests: [String: Set<QuestKind>]

    public init(routineDays: Set<DayStamp>, scanDates: [Date], quests: [String: Set<QuestKind>]) {
        self.routineDays = routineDays
        self.scanDates = scanDates
        self.quests = quests
    }
}

/// A stretch of calendar days a recap covers (both ends included).
public struct RecapPeriod: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable { case week, month, quarter, year }

    public let kind: Kind
    public let first: DayStamp
    public let last: DayStamp

    public init(kind: Kind, first: DayStamp, last: DayStamp) {
        self.kind = kind
        self.first = first
        self.last = last
    }

    /// Stable id, e.g. "week-2026-11-16" — used to remember which recaps were seen.
    public var id: String { "\(kind.rawValue)-\(first.string)" }

    public func contains(_ day: DayStamp) -> Bool { first <= day && day <= last }

    public func days(calendar: Calendar) -> [DayStamp] {
        var days: [DayStamp] = []
        var cursor = first
        while cursor <= last {
            days.append(cursor)
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return days
    }

    public static func month(year: Int, month: Int, calendar: Calendar) -> RecapPeriod {
        let first = DayStamp(year: year, month: month, day: 1)
        let range = calendar.range(of: .day, in: .month, for: first.date(in: calendar)) ?? 1..<29
        return RecapPeriod(kind: .month, first: first, last: DayStamp(year: year, month: month, day: range.count))
    }

    public static func quarter(year: Int, quarter: Int, calendar: Calendar) -> RecapPeriod {
        let firstMonth = (quarter - 1) * 3 + 1
        let end = month(year: year, month: firstMonth + 2, calendar: calendar).last
        return RecapPeriod(kind: .quarter, first: DayStamp(year: year, month: firstMonth, day: 1), last: end)
    }

    public static func year(_ year: Int) -> RecapPeriod {
        RecapPeriod(kind: .year, first: DayStamp(year: year, month: 1, day: 1), last: DayStamp(year: year, month: 12, day: 31))
    }
}

public struct Recap: Sendable, Equatable {
    public let period: RecapPeriod
    public let dayCount: Int
    public let routineDays: Int
    /// Longest run of routine days in a row inside the period.
    public let longestRun: Int
    public let scans: Int
    public let questsDone: Int
    public let lessons: Int
    public let points: Int
    /// Days with anything at all done.
    public let activeDays: Int

    public var isEmpty: Bool { activeDays == 0 }
}

/// Something good Pimpi can say about the period. Effort only.
public enum RecapCheer: String, Sendable, Equatable {
    /// Routine done every day of the period.
    case everyDay
    /// Routine done on most days.
    case mostDays
    /// Fewer routine days, but scans or lessons were done.
    case keptLooking
    /// Very little happened — a warm welcome back, never guilt.
    case freshStart
}

public enum RecapEngine {
    /// Monthly recaps show in the first days of the next month.
    public static let monthlyShowDays = 3
    /// Wrapped shows in the first days after a quarter (or the year) ends.
    public static let wrappedShowDays = 7
    /// Sunday, in `Calendar.component(.weekday)` numbering.
    static let sunday = 1

    public static func recap(_ period: RecapPeriod, history: ActivityHistory, calendar: Calendar) -> Recap {
        let days = period.days(calendar: calendar)
        let routine = days.filter(history.routineDays.contains)
        let scanDays = history.scanDates.map { DayStamp($0, calendar: calendar) }.filter(period.contains)
        var questsDone = 0, lessons = 0, points = 0
        var questDays = Set<DayStamp>()
        for (key, kinds) in history.quests {
            guard let day = DayStamp(string: key), period.contains(day), !kinds.isEmpty else { continue }
            questDays.insert(day)
            questsDone += kinds.count
            if kinds.contains(.lesson) { lessons += 1 }
            points += kinds.reduce(0) { $0 + QuestEngine.points(for: $1) }
        }
        var run = 0, longest = 0
        for day in days {
            run = history.routineDays.contains(day) ? run + 1 : 0
            longest = max(longest, run)
        }
        let active = Set(routine).union(scanDays).union(questDays)
        return Recap(period: period, dayCount: days.count, routineDays: routine.count, longestRun: longest,
                     scans: scanDays.count, questsDone: questsDone, lessons: lessons, points: points,
                     activeDays: active.count)
    }

    public static func cheer(for recap: Recap) -> RecapCheer {
        if recap.routineDays == recap.dayCount, recap.dayCount > 0 { return .everyDay }
        if recap.routineDays * 2 > recap.dayCount { return .mostDays }
        if recap.scans > 0 || recap.lessons > 0 || recap.routineDays > 0 { return .keptLooking }
        return .freshStart
    }

    // MARK: When each recap is due

    /// The Monday-to-Sunday week holding `day`. Weeks run Monday to Sunday everywhere, so "every Sunday" means the
    /// same thing in every region.
    public static func week(containing day: DayStamp, calendar: Calendar) -> RecapPeriod {
        let weekday = calendar.component(.weekday, from: day.date(in: calendar)) // 1 = Sunday
        let monday = day.adding(days: -((weekday + 5) % 7), calendar: calendar)
        return RecapPeriod(kind: .week, first: monday, last: monday.adding(days: 6, calendar: calendar))
    }

    /// Pimpi's weekly recap: on Sunday it covers the week ending today; on Monday, the week that just ended.
    public static func dueWeek(now: Date, calendar: Calendar) -> RecapPeriod? {
        let today = DayStamp(now, calendar: calendar)
        switch calendar.component(.weekday, from: today.date(in: calendar)) {
        case sunday: return week(containing: today, calendar: calendar)
        case sunday + 1: return week(containing: today.adding(days: -1, calendar: calendar), calendar: calendar)
        default: return nil
        }
    }

    /// The calendar month before the one holding `now`.
    public static func previousMonth(now: Date, calendar: Calendar) -> RecapPeriod {
        let today = DayStamp(now, calendar: calendar)
        return today.month == 1 ? .month(year: today.year - 1, month: 12, calendar: calendar)
            : .month(year: today.year, month: today.month - 1, calendar: calendar)
    }

    /// Last month's recap, in the first `monthlyShowDays` days of a month.
    public static func dueMonth(now: Date, calendar: Calendar) -> RecapPeriod? {
        DayStamp(now, calendar: calendar).day <= monthlyShowDays ? previousMonth(now: now, calendar: calendar) : nil
    }

    /// Skin Wrapped: the quarter that just ended, or the whole year in early January.
    public static func dueWrapped(now: Date, calendar: Calendar) -> RecapPeriod? {
        let today = DayStamp(now, calendar: calendar)
        guard today.day <= wrappedShowDays, [1, 4, 7, 10].contains(today.month) else { return nil }
        if today.month == 1 { return .year(today.year - 1) }
        return .quarter(year: today.year, quarter: (today.month - 1) / 3, calendar: calendar)
    }

    /// The latest Wrapped that can be opened any time: the last finished quarter.
    public static func latestWrapped(now: Date, calendar: Calendar) -> RecapPeriod {
        let today = DayStamp(now, calendar: calendar)
        let quarter = (today.month - 1) / 3 + 1
        return quarter == 1 ? .quarter(year: today.year - 1, quarter: 4, calendar: calendar)
            : .quarter(year: today.year, quarter: quarter - 1, calendar: calendar)
    }
}

// MARK: - Skin Wrapped highlights

/// A product on the shelf, with when it was added and (if so) removed.
public struct ShelfStint: Sendable, Equatable {
    public let productID: Int
    public let started: Date
    public let stopped: Date?

    public init(productID: Int, started: Date, stopped: Date?) {
        self.productID = productID
        self.started = started
        self.stopped = stopped
    }
}

public struct WrappedHighlights: Sendable, Equatable {
    /// The area whose marked count dropped most from the first half of the period to the second.
    public let calmerZone: FaceZone?
    /// The month (inside the period) with the calmest scans.
    public let calmestMonth: RecapPeriod?
    /// Products on the shelf for most of that month — they coincided with it, nothing more.
    public let productsThen: [Int]
}

public enum WrappedEngine {
    /// Scans needed in each half before a zone can be called calmer.
    public static let minimumScansPerHalf = 2
    /// Scans needed in a month for it to count, and months needed to compare.
    public static let minimumScansPerMonth = 2
    public static let minimumMonths = 2

    public static func highlights(_ period: RecapPeriod, points: [InsightEngine.Point], shelf: [ShelfStint],
                                  calendar: Calendar) -> WrappedHighlights {
        let inside = points.filter { period.contains(DayStamp($0.date, calendar: calendar)) }.sorted { $0.date < $1.date }
        let month = calmestMonth(inside, calendar: calendar)
        return WrappedHighlights(calmerZone: calmerZone(inside),
                                 calmestMonth: month,
                                 productsThen: month.map { products(on: shelf, during: $0, calendar: calendar) } ?? [])
    }

    /// Oldest-first points. The zone with the biggest drop in median marked count, if any zone dropped.
    static func calmerZone(_ points: [InsightEngine.Point]) -> FaceZone? {
        guard points.count >= minimumScansPerHalf * 2 else { return nil }
        let half = points.count / 2
        let early = points.prefix(half), late = points.suffix(points.count - half)
        let drops = FaceZone.allCases.map { zone in
            (zone, ProductEffect.median(early.map { $0.zoneIndices[zone] ?? 0 })
                - ProductEffect.median(late.map { $0.zoneIndices[zone] ?? 0 }))
        }
        guard let best = drops.max(by: { $0.1 < $1.1 }), best.1 >= 1 else { return nil }
        return best.0
    }

    static func calmestMonth(_ points: [InsightEngine.Point], calendar: Calendar) -> RecapPeriod? {
        let byMonth = Dictionary(grouping: points) { point -> Int in
            let day = DayStamp(point.date, calendar: calendar)
            return day.year * 100 + day.month
        }.filter { $0.value.count >= minimumScansPerMonth }
        guard byMonth.count >= minimumMonths else { return nil }
        let medians = byMonth.map { ($0.key, ProductEffect.median($0.value.map(\.index))) }
        // Lowest median; a tie goes to the later month.
        guard let best = medians.min(by: { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 > $1.0 }) else { return nil }
        // The calmest month must actually be calmer than another one.
        guard medians.contains(where: { $0.1 > best.1 }) else { return nil }
        return .month(year: best.0 / 100, month: best.0 % 100, calendar: calendar)
    }

    /// Products on the shelf for at least half of the month's days.
    static func products(on shelf: [ShelfStint], during month: RecapPeriod, calendar: Calendar) -> [Int] {
        let days = month.days(calendar: calendar)
        return shelf.filter { stint in
            let start = DayStamp(stint.started, calendar: calendar)
            let stop = stint.stopped.map { DayStamp($0, calendar: calendar) }
            let onShelf = days.filter { day in day >= start && (stop.map { day < $0 } ?? true) }
            return onShelf.count * 2 >= days.count
        }.map(\.productID).sorted()
    }
}
