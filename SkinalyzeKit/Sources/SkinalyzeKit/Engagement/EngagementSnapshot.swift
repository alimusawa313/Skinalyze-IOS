import Foundation

/// Everything needed to work out streaks and Pimpi's mood at any moment, small enough to share with widgets.
/// Widgets and reminders evaluate it at future times, so they stay right without the app being opened.
public struct EngagementSnapshot: Codable, Hashable, Sendable {
    public var doneDays: [DayStamp]
    public var ledger: FreezeLedger
    public var weekendOff: Bool
    public var scanDates: [Date]
    public var lastScanCelebration: Date?

    /// Pimpi stays excited this long after a scan.
    public static let scanCelebration: TimeInterval = 10 * 60

    public init(doneDays: [DayStamp], ledger: FreezeLedger, weekendOff: Bool, scanDates: [Date], lastScanCelebration: Date?) {
        self.doneDays = doneDays
        self.ledger = ledger
        self.weekendOff = weekendOff
        self.scanDates = scanDates
        self.lastScanCelebration = lastScanCelebration
    }

    public static let empty = EngagementSnapshot(doneDays: [], ledger: FreezeLedger(available: 0), weekendOff: false,
                                                 scanDates: [], lastScanCelebration: nil)

    // Every field is optional on disk so older snapshots keep decoding as fields are added.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        doneDays = try container.decodeIfPresent([DayStamp].self, forKey: .doneDays) ?? []
        ledger = try container.decodeIfPresent(FreezeLedger.self, forKey: .ledger) ?? FreezeLedger(available: 0)
        weekendOff = try container.decodeIfPresent(Bool.self, forKey: .weekendOff) ?? false
        scanDates = try container.decodeIfPresent([Date].self, forKey: .scanDates) ?? []
        lastScanCelebration = try container.decodeIfPresent(Date.self, forKey: .lastScanCelebration)
    }

    public struct State: Hashable, Sendable {
        public let routine: RoutineStreak
        public let scan: ScanStreak
        public let mood: MascotMood

        public init(routine: RoutineStreak, scan: ScanStreak, mood: MascotMood) {
            self.routine = routine
            self.scan = scan
            self.mood = mood
        }
    }

    public func state(at now: Date, calendar: Calendar) -> State {
        let routine = StreakEngine.routine(doneDays: Set(doneDays), ledger: ledger, weekendOff: weekendOff, now: now, calendar: calendar)
        let scan = StreakEngine.scan(scanDates: scanDates, now: now, calendar: calendar)
        let justScanned = lastScanCelebration.map { now >= $0 && now.timeIntervalSince($0) < Self.scanCelebration } ?? false
        let mood = PimpiMoodEngine.mood(scan: scan, routine: routine, justScanned: justScanned,
                                        hour: calendar.component(.hour, from: now))
        return State(routine: routine, scan: scan, mood: mood)
    }
}

public struct PlannedReminder: Hashable, Sendable {
    public enum Kind: String, Sendable {
        /// The routine streak is alive and today isn't checked off yet.
        case routine
        /// The week is ending without a scan.
        case scan
        /// No streak to protect: one friendly nudge.
        case comeBack
    }

    public let kind: Kind
    public let fireDate: Date
    /// 0, 1, 2 — position in the series; the wording softens and the last one says goodbye.
    public let step: Int
    /// Routine streak the reminder protects (for the wording).
    public let streakDays: Int
}

/// Plans Pimpi's reminders from the snapshot, assuming the user does nothing more: at most one a day, at most
/// `maximumSeries` days in a row, then silence. Opening the app re-plans from scratch, so the series only ever
/// runs out when the user really is away. Reminders are about showing up — never about skin condition.
public enum ReminderPlanner {
    public static let maximumSeries = 3
    /// Good light for a scan.
    public static let daylightHour = 10
    /// Late enough to matter, early enough to act.
    public static let eveningHour = 20
    /// Days ahead that are considered.
    static let horizonDays = 7

    public static func plan(snapshot: EngagementSnapshot, now: Date, calendar: Calendar, enabled: Bool) -> [PlannedReminder] {
        guard enabled else { return [] }
        var planned: [PlannedReminder] = []
        var nudgedComeBack = false
        let today = DayStamp(now, calendar: calendar)
        for offset in 0..<horizonDays where planned.count < maximumSeries {
            let day = today.adding(days: offset, calendar: calendar)
            func at(_ hour: Int) -> Date {
                calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour)) ?? now
            }
            let morning = snapshot.state(at: at(daylightHour), calendar: calendar)
            let evening = snapshot.state(at: at(eveningHour), calendar: calendar)
            var candidate: (PlannedReminder.Kind, Date, Int)?
            if evening.routine.status == .atRisk {
                candidate = (.routine, at(eveningHour), evening.routine.count)
            } else if isScanDue(morning.scan) {
                candidate = (.scan, at(daylightHour), morning.routine.count)
            } else if !nudgedComeBack, isLapsed(morning) {
                candidate = (.comeBack, at(daylightHour), 0)
            }
            guard let (kind, fireDate, streak) = candidate, fireDate > now else { continue }
            if kind == .comeBack { nudgedComeBack = true }
            planned.append(PlannedReminder(kind: kind, fireDate: fireDate, step: planned.count, streakDays: streak))
        }
        return planned
    }

    private static func isScanDue(_ scan: ScanStreak) -> Bool {
        switch scan.status {
        case .atRisk: true
        case let .due(daysLeft): daysLeft <= 1
        default: false
        }
    }

    /// Nothing to protect: no routine streak running and no scan this week.
    private static func isLapsed(_ state: EngagementSnapshot.State) -> Bool {
        let noRoutine: Bool = switch state.routine.status {
        case .none, .broken: true
        default: false
        }
        return noRoutine && state.scan.status != .doneThisWeek
    }
}
