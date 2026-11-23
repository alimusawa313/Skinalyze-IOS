import Foundation
import Testing
@testable import SkinalyzeKit

/// P3 trigger journal and P4 Health-derived tags: patterns only with enough data, worded as coincidence by the app.
@Suite("Trigger journal")
struct TriggerJournalTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()
    let start = DayStamp(year: 2026, month: 9, day: 1)

    func day(_ offset: Int) -> DayStamp { start.adding(days: offset, calendar: calendar) }
    func scan(_ offset: Int, index: Int) -> InsightEngine.Point {
        InsightEngine.Point(date: day(offset).date(in: calendar), index: index, zoneIndices: [:])
    }

    /// Eight weeks: stressed in odd weeks, with busier scans those weeks.
    func data() -> ([JournalEntry], [InsightEngine.Point]) {
        var entries: [JournalEntry] = []
        var scans: [InsightEngine.Point] = []
        for week in 0..<8 {
            let stressed = week % 2 == 1
            for d in 0..<7 {
                entries.append(JournalEntry(day: day(week * 7 + d), tags: stressed ? [.stressed] : [.workout]))
            }
            scans.append(scan(week * 7 + 6, index: stressed ? 20 : 10))
        }
        return (entries, scans)
    }

    @Test("A tag that coincides with busier scans shows as 'more', with both medians")
    func finds() {
        let (entries, scans) = data()
        let patterns = TriggerEngine.patterns(entries: entries, scans: scans, calendar: calendar)
        let stressed = patterns.first { $0.tag == .stressed }
        #expect(stressed?.direction == .more)
        #expect(stressed?.withTag == 20 && stressed?.withoutTag == 10)
        #expect(stressed?.scansWith == 4 && stressed?.scansWithout == 4)
        #expect(patterns.first { $0.tag == .workout }?.direction == .fewer)
    }

    @Test("Nothing shows before four weeks of journal days")
    func needsHistory() {
        let (entries, scans) = data()
        let early = Array(entries.prefix(20))
        #expect(TriggerEngine.patterns(entries: early, scans: scans, calendar: calendar).isEmpty)
        #expect(TriggerEngine.daysUntilReady(early, today: day(19), calendar: calendar) == 8)
        #expect(TriggerEngine.daysUntilReady(entries, today: day(55), calendar: calendar) == 0)
    }

    @Test("Small differences and thin data stay quiet")
    func quiet() {
        let (entries, _) = data()
        let flat = (0..<8).map { scan($0 * 7 + 6, index: $0 % 2 == 1 ? 11 : 10) }
        #expect(TriggerEngine.patterns(entries: entries, scans: flat, calendar: calendar).isEmpty)
        let few = (0..<4).map { scan($0 * 7 + 6, index: $0 % 2 == 1 ? 20 : 10) }
        #expect(TriggerEngine.patterns(entries: entries, scans: few, calendar: calendar).isEmpty)
    }

    @Test("Health nights under six hours become 'slept badly'; period days become 'period'")
    func health() {
        let entries = TriggerEngine.healthEntries(sleepHours: [day(0): 5.5, day(1): 7.5, day(2): 0], periodDays: [day(1)])
        #expect(entries == [JournalEntry(day: day(0), tags: [.sleptBadly]), JournalEntry(day: day(1), tags: [.period])])
    }
}
