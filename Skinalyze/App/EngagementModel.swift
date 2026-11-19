import Foundation
import Observation
import SkinalyzeKit

/// Where streak inputs live: the days a routine step was checked off, the freeze ledger and the weekend-off setting.
/// Kept apart from the routine log (which only holds ~2 months) so long streaks stay countable.
struct EngagementStore {
    static let startingFreezes = 1

    private enum Key {
        static let doneDays = "routineDoneDays"
        static let ledger = "streakFreezeLedger"
        static let weekendOff = "streakWeekendOff"
        static let imported = "routineDoneDaysImported"
        static let celebrated = "streakCelebratedMilestones"
        static let lastScanCelebration = "streakLastScanCelebration"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var doneDays: Set<DayStamp> {
        Set((defaults.string(forKey: Key.doneDays) ?? "").split(separator: ",").compactMap { DayStamp(string: String($0)) })
    }

    func setDone(_ done: Bool, on day: DayStamp) {
        var days = doneDays
        if done { days.insert(day) } else { days.remove(day) }
        defaults.set(days.sorted().map(\.string).joined(separator: ","), forKey: Key.doneDays)
    }

    /// One-time import of the days already checked off in the old routine log ("yyyy-MM-dd:part.Slot|…").
    func importRoutineLogIfNeeded(raw: String) {
        guard !defaults.bool(forKey: Key.imported) else { return }
        let days = raw.split(separator: "|").compactMap { $0.split(separator: ":").first.flatMap { DayStamp(string: String($0)) } }
        defaults.set(doneDays.union(days).sorted().map(\.string).joined(separator: ","), forKey: Key.doneDays)
        defaults.set(true, forKey: Key.imported)
    }

    var ledger: FreezeLedger {
        get {
            defaults.data(forKey: Key.ledger).flatMap { try? JSONDecoder().decode(FreezeLedger.self, from: $0) }
                ?? FreezeLedger(available: Self.startingFreezes)
        }
        nonmutating set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.ledger) }
    }

    var weekendOff: Bool {
        get { defaults.bool(forKey: Key.weekendOff) }
        nonmutating set { defaults.set(newValue, forKey: Key.weekendOff) }
    }

    /// Milestones already celebrated ("routine-7", "scan-4"), so each is celebrated once.
    var celebrated: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.celebrated) ?? []) }
        nonmutating set { defaults.set(newValue.sorted(), forKey: Key.celebrated) }
    }

    var lastScanCelebration: Date? {
        get { defaults.object(forKey: Key.lastScanCelebration) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastScanCelebration) }
    }
}

/// Streaks, freezes and Pimpi's mood for the UI. All rules live in SkinalyzeKit (`StreakEngine`, `PimpiMoodEngine`);
/// this only feeds them the stored history and keeps the results observable.
@Observable
@MainActor
final class EngagementModel {
    struct Milestone: Identifiable, Hashable {
        enum Kind: String { case routine, scan }
        let kind: Kind
        let value: Int
        var id: String { "\(kind.rawValue)-\(value)" }
    }

    /// Pimpi stays excited this long after a scan.
    private static let scanCelebration: TimeInterval = 10 * 60

    private(set) var routine = RoutineStreak.empty
    private(set) var scan = ScanStreak.empty
    private(set) var ledger: FreezeLedger
    private(set) var mood: MascotMood = .happy
    private(set) var canRepair = false
    /// A milestone reached and not yet celebrated; the Mirror presents it once.
    var milestone: Milestone?
    var weekendOff: Bool {
        didSet {
            store.weekendOff = weekendOff
            recompute()
        }
    }

    private let store: EngagementStore
    private let calendar: Calendar
    private var scanDates: [Date] = []

    init(store: EngagementStore = EngagementStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        ledger = store.ledger
        weekendOff = store.weekendOff
    }

    /// Call when the app becomes active and when scans change: settles freezes for missed days, then recomputes.
    func refresh(scanDates: [Date], routineLogRaw: String, now: Date = .now) {
        self.scanDates = scanDates
        store.importRoutineLogIfNeeded(raw: routineLogRaw)
        let settled = StreakEngine.settle(doneDays: store.doneDays, ledger: store.ledger, weekendOff: weekendOff,
                                          now: now, calendar: calendar)
        if settled != store.ledger { store.ledger = settled }
        recompute(now: now)
    }

    /// Call after a routine step is checked or unchecked.
    func routineChanged(anyStepDoneToday: Bool, now: Date = .now) {
        store.setDone(anyStepDoneToday, on: DayStamp(now, calendar: calendar))
        recompute(now: now)
        let earned = StreakEngine.earning(store.ledger, streak: routine, now: now, calendar: calendar)
        if earned != store.ledger {
            store.ledger = earned
            ledger = earned
        }
    }

    func scanCompleted(at date: Date = .now) {
        store.lastScanCelebration = date
        scanDates.append(date)
        recompute(now: date)
    }

    func repair(now: Date = .now) {
        guard canRepair else { return }
        store.ledger = StreakEngine.repairing(store.ledger, now: now, calendar: calendar)
        recompute(now: now)
    }

    func markCelebrated(_ milestone: Milestone) {
        store.celebrated.insert(milestone.id)
        if self.milestone == milestone { self.milestone = nil }
    }

    private func recompute(now: Date = .now) {
        let doneDays = store.doneDays
        ledger = store.ledger
        routine = StreakEngine.routine(doneDays: doneDays, ledger: ledger, weekendOff: weekendOff, now: now, calendar: calendar)
        scan = StreakEngine.scan(scanDates: scanDates, now: now, calendar: calendar)
        canRepair = StreakEngine.canRepair(doneDays: doneDays, ledger: ledger, weekendOff: weekendOff, now: now, calendar: calendar)
        let justScanned = store.lastScanCelebration.map { now.timeIntervalSince($0) < Self.scanCelebration && now >= $0 } ?? false
        mood = PimpiMoodEngine.mood(scan: scan, routine: routine, justScanned: justScanned,
                                    hour: calendar.component(.hour, from: now))
        let reached = routine.milestone.map { Milestone(kind: .routine, value: $0) }
            ?? scan.milestone.map { Milestone(kind: .scan, value: $0) }
        if let reached, !store.celebrated.contains(reached.id) { milestone = reached }
    }
}
