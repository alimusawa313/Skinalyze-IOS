import Foundation
import Testing
@testable import SkinalyzeKit

/// Pimpi's reminders: at most one a day, three in a row at most, then silence until the user comes back.
@Suite("Engagement snapshot and reminders")
struct ReminderPlannerTests {
    static let calendar = StreakEngineTests.calendar
    static func date(_ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func snapshot(done: ClosedRange<Int>?, scans: [Date] = [date(17)], freezes: Int = 0) -> EngagementSnapshot {
        EngagementSnapshot(doneDays: done.map { Array(StreakEngineTests.days($0)) } ?? [], ledger: FreezeLedger(available: freezes),
                           weekendOff: false, scanDates: scans, lastScanCelebration: nil)
    }

    private func plan(_ snapshot: EngagementSnapshot, now: Date, enabled: Bool = true) -> [PlannedReminder] {
        ReminderPlanner.plan(snapshot: snapshot, now: now, calendar: Self.calendar, enabled: enabled)
    }

    @Test("The snapshot gives the same streaks and mood as the engines, at any moment (widgets use this)")
    func snapshotState() {
        let state = snapshot(done: 15...19).state(at: Self.date(19), calendar: Self.calendar)
        #expect(state.routine.count == 5 && state.routine.status == .doneToday)
        #expect(state.scan.status == .doneThisWeek)
        #expect(state.mood == .happy)
        // The same snapshot later: tomorrow evening the streak is at risk and Pimpi worries — no app launch needed.
        #expect(snapshot(done: 15...19).state(at: Self.date(20, hour: 21), calendar: Self.calendar).mood == .worried)
    }

    @Test("Old stored snapshots without the newer fields still decode")
    func decodesSparseJSON() throws {
        let decoded = try JSONDecoder().decode(EngagementSnapshot.self, from: Data("{}".utf8))
        #expect(decoded.doneDays.isEmpty && decoded.scanDates.isEmpty && !decoded.weekendOff)
    }

    @Test("Routine not done yet today: one reminder this evening")
    func eveningReminderToday() {
        let reminders = plan(snapshot(done: 15...18), now: Self.date(19, hour: 9))
        #expect(reminders.first?.kind == .routine)
        #expect(reminders.first?.fireDate == Self.date(19, hour: ReminderPlanner.eveningHour))
        #expect(reminders.first?.streakDays == 4)
    }

    @Test("Done for today: nothing more today; tomorrow evening instead")
    func nothingAfterDone() {
        let reminders = plan(snapshot(done: 15...19), now: Self.date(19, hour: 9))
        #expect(reminders.first?.fireDate == Self.date(20, hour: ReminderPlanner.eveningHour))
        #expect(!reminders.contains { Self.calendar.isDate($0.fireDate, inSameDayAs: Self.date(19)) })
    }

    @Test("Never more than one a day, never more than three in a row, never in the past, steps escalate 0-1-2")
    func capsAndOrder() {
        for now in [Self.date(19, hour: 9), Self.date(19, hour: 21), Self.date(22, hour: 7)] {
            for snap in [snapshot(done: 15...18), snapshot(done: nil, scans: []), snapshot(done: 10...12, scans: [Self.date(4)])] {
                let reminders = plan(snap, now: now)
                #expect(reminders.count <= ReminderPlanner.maximumSeries)
                #expect(reminders.allSatisfy { $0.fireDate > now })
                #expect(Set(reminders.map { DayStamp($0.fireDate, calendar: Self.calendar) }).count == reminders.count)
                #expect(reminders.map(\.step) == Array(0..<reminders.count))
                #expect(reminders.allSatisfy { (8...21).contains(Self.calendar.component(.hour, from: $0.fireDate)) })
            }
        }
    }

    @Test("Scan reminder comes in daylight on the last days of the week, only if this week has no scan")
    func scanReminder() {
        // Scans in previous weeks only; Saturday 21st → 1 day left.
        let due = snapshot(done: 15...21, scans: [Self.date(4), Self.date(11)])
        let reminders = plan(due, now: Self.date(21, hour: 7))
        #expect(reminders.first?.kind == .scan)
        #expect(reminders.first?.fireDate == Self.date(21, hour: ReminderPlanner.daylightHour))
        // Already scanned this week → no scan reminder.
        #expect(!plan(snapshot(done: 15...21, scans: [Self.date(17)]), now: Self.date(21, hour: 7)).contains { $0.kind == .scan })
    }

    @Test("A lapsed user gets a single come-back nudge, not a daily one")
    func comeBackOnce() {
        let reminders = plan(snapshot(done: 10...12, scans: [Self.date(4)]), now: Self.date(19, hour: 9))
        #expect(reminders.filter { $0.kind == .comeBack }.count == 1)
    }

    @Test("Turned off: nothing is planned")
    func disabled() {
        #expect(plan(snapshot(done: 15...18), now: Self.date(19, hour: 9), enabled: false).isEmpty)
    }
}
