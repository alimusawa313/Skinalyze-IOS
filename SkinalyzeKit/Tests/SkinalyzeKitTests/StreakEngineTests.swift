import Foundation
import Testing
@testable import SkinalyzeKit

/// Streaks are derived from history (routine done-days, scan dates) plus a freeze ledger — effort only, never skin.
@Suite("Streaks")
struct StreakEngineTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// 2026-11-19 is a Thursday.
    static func date(_ day: Int, hour: Int = 12, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    static func days(_ range: ClosedRange<Int>, month: Int = 11) -> Set<DayStamp> {
        Set(range.map { DayStamp(year: 2026, month: month, day: $0) })
    }

    private func routine(done: Set<DayStamp>, ledger: FreezeLedger = .init(available: 0), weekendOff: Bool = false,
                         now: Date) -> RoutineStreak {
        StreakEngine.routine(doneDays: done, ledger: ledger, weekendOff: weekendOff, now: now, calendar: Self.calendar)
    }

    // MARK: Routine (daily)

    @Test("Consecutive done days count, including today")
    func countsConsecutiveDays() {
        let streak = routine(done: Self.days(15...19), now: Self.date(19))
        #expect(streak.count == 5)
        #expect(streak.status == .doneToday)
    }

    @Test("Today not done yet doesn't break the streak — it is due, and at risk late in the evening")
    func todayPending() {
        #expect(routine(done: Self.days(15...18), now: Self.date(19, hour: 9)).status == .due)
        #expect(routine(done: Self.days(15...18), now: Self.date(19, hour: 9)).count == 4)
        #expect(routine(done: Self.days(15...18), now: Self.date(19, hour: 21)).status == .atRisk)
    }

    @Test("A missed day breaks the streak; the day changes at local midnight")
    func missedDayBreaks() {
        let broken = routine(done: Self.days(14...17), now: Self.date(19, hour: 0))
        #expect(broken.count == 0)
        #expect(broken.status == .broken(previous: 4))
        // One minute before midnight on the 18th it was still only "at risk".
        let before = routine(done: Self.days(14...17), now: Self.calendar.date(byAdding: .minute, value: -1, to: Self.date(19, hour: 0))!)
        #expect(before.status == .atRisk)
        #expect(before.count == 4)
    }

    @Test("No history: no streak")
    func noHistory() {
        #expect(routine(done: [], now: Self.date(19)).status == .none)
    }

    @Test("Weekend-off: Saturday and Sunday neither count nor break")
    func weekendOff() {
        // Done Mon 9 – Fri 13, weekend skipped, done Mon 16 – Thu 19.
        let done = Self.days(9...13).union(Self.days(16...19))
        #expect(routine(done: done, weekendOff: true, now: Self.date(19)).count == 9)
        #expect(routine(done: done, weekendOff: false, now: Self.date(19)).count == 4)
    }

    @Test("A freeze covers a missed day: the streak survives but the frozen day doesn't add to it")
    func freezeCoversMissedDay() {
        let done = Self.days(14...16).union(Self.days(18...19)) // missed the 17th
        let ledger = FreezeLedger(available: 1, usedDays: [DayStamp(year: 2026, month: 11, day: 17)])
        #expect(routine(done: done, ledger: ledger, now: Self.date(19)).count == 5)
    }

    @Test("Settling uses available freezes automatically for missed days, oldest first, and stops when they run out")
    func settleConsumesFreezes() {
        let done = Self.days(10...15) // missed 16, 17, 18; today is the 19th
        let settled = StreakEngine.settle(doneDays: done, ledger: FreezeLedger(available: 2), weekendOff: false,
                                          now: Self.date(19), calendar: Self.calendar)
        // Two freezes can't bridge a three-day gap, so none are wasted.
        #expect(settled.available == 2 && settled.usedDays.isEmpty)
        let oneMissed = StreakEngine.settle(doneDays: Self.days(10...17), ledger: FreezeLedger(available: 2), weekendOff: false,
                                            now: Self.date(19), calendar: Self.calendar)
        #expect(oneMissed.available == 1)
        #expect(oneMissed.usedDays == [DayStamp(year: 2026, month: 11, day: 18)])
        #expect(routine(done: Self.days(10...17), ledger: oneMissed, now: Self.date(19)).count == 8)
    }

    @Test("Repair: allowed only for a single missed day, yesterday, and not more than once in 30 days")
    func repair() {
        let done = Self.days(10...17) // missed the 18th, today the 19th, no freezes
        var ledger = FreezeLedger(available: 0)
        #expect(StreakEngine.canRepair(doneDays: done, ledger: ledger, weekendOff: false, now: Self.date(19), calendar: Self.calendar))
        ledger = StreakEngine.repairing(ledger, now: Self.date(19), calendar: Self.calendar)
        #expect(routine(done: done, ledger: ledger, now: Self.date(19)).count == 8)
        // Not again within 30 days.
        let later = Self.days(10...17).union(Self.days(19...24)) // missed the 25th, today the 26th
        #expect(!StreakEngine.canRepair(doneDays: later, ledger: ledger, weekendOff: false, now: Self.date(26), calendar: Self.calendar))
        // Two days missed: too late.
        #expect(!StreakEngine.canRepair(doneDays: Self.days(10...16), ledger: FreezeLedger(available: 0), weekendOff: false,
                                        now: Self.date(19), calendar: Self.calendar))
    }

    @Test("Milestones fire on the day they are reached; a freeze is earned every 7 days up to the cap")
    func milestonesAndEarning() {
        #expect(routine(done: Self.days(13...19), now: Self.date(19)).milestone == 7)
        #expect(routine(done: Self.days(12...19), now: Self.date(19)).milestone == nil)
        var ledger = FreezeLedger(available: 0)
        ledger = StreakEngine.earning(ledger, streak: routine(done: Self.days(13...19), now: Self.date(19)), now: Self.date(19), calendar: Self.calendar)
        #expect(ledger.available == 1)
        // The same day doesn't pay twice.
        ledger = StreakEngine.earning(ledger, streak: routine(done: Self.days(13...19), now: Self.date(19)), now: Self.date(19), calendar: Self.calendar)
        #expect(ledger.available == 1)
        #expect(StreakEngine.earning(FreezeLedger(available: FreezeLedger.cap), streak: routine(done: Self.days(13...19), now: Self.date(19)),
                                     now: Self.date(19), calendar: Self.calendar).available == FreezeLedger.cap)
    }

    @Test("Travelling across time zones keeps a day a day (done-days are calendar days, not instants)")
    func timeZoneTravel() {
        var tokyo = Self.calendar
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let streak = StreakEngine.routine(doneDays: Self.days(15...19), ledger: .init(available: 0), weekendOff: false,
                                          now: Self.date(19, hour: 23), calendar: tokyo) // already the 20th, 01:00 in Tokyo
        #expect(streak.count == 5)
        #expect(streak.status == .due)
    }

    // MARK: Scan (weekly rhythm)

    private func scan(_ dates: [Date], now: Date) -> ScanStreak {
        StreakEngine.scan(scanDates: dates, now: now, calendar: Self.calendar)
    }

    @Test("One scan in each consecutive week keeps the weekly streak")
    func weeklyStreak() {
        // Weeks (Mon–Sun): 2–8, 9–15, 16–22 Nov.
        let streak = scan([Self.date(4), Self.date(11), Self.date(12), Self.date(17)], now: Self.date(19))
        #expect(streak.weeks == 3)
        #expect(streak.status == .doneThisWeek)
    }

    @Test("This week not scanned yet: due with days left; at risk on the last day; broken after a skipped week")
    func weeklyDueAndBroken() {
        let due = scan([Self.date(4), Self.date(11)], now: Self.date(19)) // Thu, week ends Sun 22
        #expect(due.weeks == 2)
        #expect(due.status == .due(daysLeft: 3))
        #expect(scan([Self.date(4), Self.date(11)], now: Self.date(22)).status == .atRisk)
        let broken = scan([Self.date(4)], now: Self.date(19)) // skipped the week of 9–15
        #expect(broken.weeks == 0)
        #expect(broken.status == .broken(previous: 1))
        #expect(scan([], now: Self.date(19)).status == .none)
    }

    // MARK: Pimpi's mood (effort only)

    @Test("Pimpi's mood follows the streaks — never skin results")
    func mood() {
        let fine = routine(done: Self.days(15...19), now: Self.date(19))
        let scanned = scan([Self.date(11), Self.date(17)], now: Self.date(19))
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: fine, justScanned: false, hour: 12) == .happy)
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: fine, justScanned: true, hour: 12) == .excited)
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: routine(done: Self.days(13...19), now: Self.date(19)), justScanned: false, hour: 12) == .excited) // milestone
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: routine(done: Self.days(15...18), now: Self.date(19, hour: 21)), justScanned: false, hour: 21) == .worried)
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: routine(done: Self.days(14...17), now: Self.date(19)), justScanned: false, hour: 12) == .sad)
        let dueSoon = scan([Self.date(4), Self.date(11)], now: Self.date(21)) // Saturday, 1 day left
        #expect(PimpiMoodEngine.mood(scan: dueSoon, routine: fine, justScanned: false, hour: 12) == .curious)
        #expect(PimpiMoodEngine.mood(scan: scanned, routine: fine, justScanned: false, hour: 23) == .sleepy)
    }
}
