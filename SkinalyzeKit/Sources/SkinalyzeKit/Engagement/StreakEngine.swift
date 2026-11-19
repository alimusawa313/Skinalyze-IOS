import Foundation

/// A calendar day (not an instant): streaks are about days, so travelling across time zones can't split or merge them.
public struct DayStamp: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// "yyyy-MM-dd" (the format the routine log already uses).
    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var string: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Noon of this day in `calendar` (noon keeps day arithmetic clear of daylight-saving edges).
    func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    func adding(days: Int, calendar: Calendar) -> DayStamp {
        DayStamp(calendar.date(byAdding: .day, value: days, to: date(in: calendar)) ?? date(in: calendar), calendar: calendar)
    }

    func isWeekend(in calendar: Calendar) -> Bool { calendar.isDateInWeekend(date(in: calendar)) }
}

/// Streak freezes: how many are in hand, which missed days they covered, and when the last repair/earn happened.
public struct FreezeLedger: Codable, Hashable, Sendable {
    /// Most freezes that can be held at once.
    public static let cap = 2
    /// A broken streak can be repaired at most once in this many days.
    public static let repairCooldownDays = 30

    public var available: Int
    public var usedDays: Set<DayStamp>
    public var lastRepairDay: DayStamp?
    public var lastEarnDay: DayStamp?

    public init(available: Int, usedDays: Set<DayStamp> = [], lastRepairDay: DayStamp? = nil, lastEarnDay: DayStamp? = nil) {
        self.available = available
        self.usedDays = usedDays
        self.lastRepairDay = lastRepairDay
        self.lastEarnDay = lastEarnDay
    }
}

public struct RoutineStreak: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case none
        case doneToday
        /// Not done yet today; the streak is still alive.
        case due
        /// Not done yet today and the day is nearly over.
        case atRisk
        case broken(previous: Int)
    }

    /// Days in the current streak. Frozen and skipped (weekend-off) days keep it alive without adding to it.
    public let count: Int
    public let status: Status
    /// Set on the day a milestone is reached.
    public let milestone: Int?

    public init(count: Int, status: Status, milestone: Int?) {
        self.count = count
        self.status = status
        self.milestone = milestone
    }

    /// No history yet.
    public static let empty = RoutineStreak(count: 0, status: .none, milestone: nil)
}

public struct ScanStreak: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case none
        case doneThisWeek
        case due(daysLeft: Int)
        /// Last day of the week and no scan yet.
        case atRisk
        case broken(previous: Int)
    }

    /// Consecutive weeks with at least one scan.
    public let weeks: Int
    public let status: Status
    public let milestone: Int?

    public init(weeks: Int, status: Status, milestone: Int?) {
        self.weeks = weeks
        self.status = status
        self.milestone = milestone
    }

    /// No scans yet.
    public static let empty = ScanStreak(weeks: 0, status: .none, milestone: nil)
}

/// Streaks derived from history, so they can never disagree with the data: the routine streak from the days a routine
/// step was checked off, the scan streak from scan dates (weekly rhythm). Effort only — skin results play no part.
public enum StreakEngine {
    public static let routineMilestones = [7, 30, 100]
    public static let scanMilestones = [4, 12, 26, 52]
    /// From this hour (local) an unfinished day counts as "at risk".
    public static let atRiskHour = 20
    /// A freeze is earned every this-many days of routine streak.
    public static let daysPerFreeze = 7

    // MARK: Routine (daily)

    public static func routine(doneDays: Set<DayStamp>, ledger: FreezeLedger, weekendOff: Bool,
                               now: Date, calendar: Calendar) -> RoutineStreak {
        let today = DayStamp(now, calendar: calendar)
        let chain = Chain(doneDays: doneDays, ledger: ledger, weekendOff: weekendOff, calendar: calendar)
        if doneDays.contains(today) {
            let count = chain.count(endingAt: today)
            return RoutineStreak(count: count, status: .doneToday, milestone: routineMilestones.contains(count) ? count : nil)
        }
        let count = chain.count(endingAt: today.adding(days: -1, calendar: calendar))
        if count > 0 {
            let late = calendar.component(.hour, from: now) >= atRiskHour && chain.isRequired(today)
            return RoutineStreak(count: count, status: late ? .atRisk : .due, milestone: nil)
        }
        guard let lastDone = doneDays.filter({ $0 < today }).max() else {
            return RoutineStreak(count: 0, status: .none, milestone: nil)
        }
        return RoutineStreak(count: 0, status: .broken(previous: chain.count(endingAt: lastDone)), milestone: nil)
    }

    /// Uses freezes in hand for the days missed since the last done day — only when they can bridge the whole gap
    /// (a freeze is never wasted on a streak that is lost anyway).
    public static func settle(doneDays: Set<DayStamp>, ledger: FreezeLedger, weekendOff: Bool,
                              now: Date, calendar: Calendar) -> FreezeLedger {
        let today = DayStamp(now, calendar: calendar)
        let chain = Chain(doneDays: doneDays, ledger: ledger, weekendOff: weekendOff, calendar: calendar)
        guard let lastDone = doneDays.filter({ $0 < today }).max() else { return ledger }
        var gap: [DayStamp] = []
        var cursor = lastDone.adding(days: 1, calendar: calendar)
        while cursor < today, gap.count <= FreezeLedger.cap {
            if chain.isRequired(cursor), !ledger.usedDays.contains(cursor) { gap.append(cursor) }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        guard !gap.isEmpty, gap.count <= ledger.available else { return ledger }
        var settled = ledger
        settled.available -= gap.count
        settled.usedDays.formUnion(gap)
        return settled
    }

    /// A streak that broke by missing exactly yesterday can be repaired once per cooldown period.
    public static func canRepair(doneDays: Set<DayStamp>, ledger: FreezeLedger, weekendOff: Bool,
                                 now: Date, calendar: Calendar) -> Bool {
        let today = DayStamp(now, calendar: calendar)
        let yesterday = today.adding(days: -1, calendar: calendar)
        let chain = Chain(doneDays: doneDays, ledger: ledger, weekendOff: weekendOff, calendar: calendar)
        guard chain.isRequired(yesterday), !doneDays.contains(yesterday), !ledger.usedDays.contains(yesterday),
              chain.count(endingAt: yesterday.adding(days: -1, calendar: calendar)) > 0 else { return false }
        if let last = ledger.lastRepairDay {
            let days = calendar.dateComponents([.day], from: last.date(in: calendar), to: today.date(in: calendar)).day ?? 0
            if days < FreezeLedger.repairCooldownDays { return false }
        }
        return true
    }

    public static func repairing(_ ledger: FreezeLedger, now: Date, calendar: Calendar) -> FreezeLedger {
        let today = DayStamp(now, calendar: calendar)
        var repaired = ledger
        repaired.usedDays.insert(today.adding(days: -1, calendar: calendar))
        repaired.lastRepairDay = today
        return repaired
    }

    /// Adds a freeze on the day the routine streak reaches a multiple of `daysPerFreeze` (once that day, up to the cap).
    public static func earning(_ ledger: FreezeLedger, streak: RoutineStreak, now: Date, calendar: Calendar) -> FreezeLedger {
        let today = DayStamp(now, calendar: calendar)
        guard streak.status == .doneToday, streak.count > 0, streak.count.isMultiple(of: daysPerFreeze),
              ledger.lastEarnDay != today else { return ledger }
        var earned = ledger
        earned.available = min(FreezeLedger.cap, ledger.available + 1)
        earned.lastEarnDay = today
        return earned
    }

    // MARK: Scan (weekly rhythm)

    public static func scan(scanDates: [Date], now: Date, calendar: Calendar) -> ScanStreak {
        func weekStart(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date }
        let weeks = Set(scanDates.map(weekStart))
        guard !weeks.isEmpty else { return ScanStreak(weeks: 0, status: .none, milestone: nil) }
        let current = weekStart(now)
        func previousWeek(_ start: Date) -> Date { weekStart(calendar.date(byAdding: .day, value: -1, to: start) ?? start) }
        func count(endingAt start: Date) -> Int {
            var cursor = start, total = 0
            while weeks.contains(cursor) {
                total += 1
                cursor = previousWeek(cursor)
            }
            return total
        }
        if weeks.contains(current) {
            let total = count(endingAt: current)
            return ScanStreak(weeks: total, status: .doneThisWeek, milestone: scanMilestones.contains(total) ? total : nil)
        }
        let total = count(endingAt: previousWeek(current))
        if total > 0 {
            let end = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            let lastDay = DayStamp(calendar.date(byAdding: .second, value: -1, to: end) ?? end, calendar: calendar)
            let today = DayStamp(now, calendar: calendar)
            let daysLeft = calendar.dateComponents([.day], from: today.date(in: calendar), to: lastDay.date(in: calendar)).day ?? 0
            return ScanStreak(weeks: total, status: daysLeft <= 0 ? .atRisk : .due(daysLeft: daysLeft), milestone: nil)
        }
        let lastWeek = weeks.filter { $0 < current }.max()
        return ScanStreak(weeks: 0, status: lastWeek.map { .broken(previous: count(endingAt: $0)) } ?? .none, milestone: nil)
    }

    // MARK: Shared

    private struct Chain {
        let doneDays: Set<DayStamp>
        let ledger: FreezeLedger
        let weekendOff: Bool
        let calendar: Calendar
        private static let limit = 4000 // ~11 years; a guard, not a rule

        func isRequired(_ day: DayStamp) -> Bool { !(weekendOff && day.isWeekend(in: calendar)) }

        /// Done days in the unbroken run ending at `end` (skipped weekends and frozen days keep the run alive).
        func count(endingAt end: DayStamp) -> Int {
            var cursor = end, total = 0
            for _ in 0..<Self.limit {
                if doneDays.contains(cursor) {
                    total += 1
                } else if isRequired(cursor), !ledger.usedDays.contains(cursor) {
                    break
                }
                cursor = cursor.adding(days: -1, calendar: calendar)
                // Nothing older than the first done day can extend the run.
                if total > 0 || doneDays.contains(where: { $0 <= cursor }) { continue }
                break
            }
            return total
        }
    }
}

/// Pimpi's moods (the mascot view maps these to its drawings).
public enum MascotMood: String, CaseIterable, Sendable {
    case happy, excited, curious, sleepy, worried, sad
}

/// Pimpi's mood from the streaks and the time of day. It never looks at skin results: a bad skin week must not
/// make the mascot sad.
public enum PimpiMoodEngine {
    /// Pimpi gets curious (magnifying glass out) when a scan is due within this many days.
    public static let scanDueSoonDays = 2
    public static let sleepyFromHour = 22
    public static let sleepyUntilHour = 6

    public static func mood(scan: ScanStreak, routine: RoutineStreak, justScanned: Bool, hour: Int) -> MascotMood {
        if justScanned || routine.milestone != nil || scan.milestone != nil { return .excited }
        if case .broken = routine.status { return .sad }
        if routine.status == .atRisk || scan.status == .atRisk { return .worried }
        switch scan.status {
        case .broken, .none: return .curious // invites a scan; a lapsed scan habit is not a reason for sadness
        case let .due(daysLeft) where daysLeft <= scanDueSoonDays: return .curious
        default: break
        }
        if hour >= sleepyFromHour || hour < sleepyUntilHour { return .sleepy }
        return .happy
    }
}
