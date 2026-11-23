import Foundation
import Testing
@testable import SkinalyzeKit

/// Weekly / monthly recaps, Skin Wrapped, the journey map and 30-day challenges (Phase 9, local parts).
@Suite("Recaps, journey and challenges")
struct RecapTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    func day(_ y: Int, _ m: Int, _ d: Int) -> DayStamp { DayStamp(year: y, month: m, day: d) }
    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    // MARK: Recap numbers

    @Test("A week counts routine days, scans, quests, lessons and points inside it only")
    func weekNumbers() {
        // Mon 16 – Sun 22 Nov 2026.
        let week = RecapPeriod(kind: .week, first: day(2026, 11, 16), last: day(2026, 11, 22))
        let history = ActivityHistory(
            routineDays: [day(2026, 11, 15), day(2026, 11, 16), day(2026, 11, 17), day(2026, 11, 18), day(2026, 11, 21)],
            scanDates: [date(2026, 11, 17), date(2026, 11, 23)],
            quests: ["2026-11-17": [.routine, .scan], "2026-11-20": [.lesson], "2026-11-23": [.share]])
        let recap = RecapEngine.recap(week, history: history, calendar: calendar)
        #expect(recap.dayCount == 7)
        #expect(recap.routineDays == 4)
        #expect(recap.longestRun == 3)
        #expect(recap.scans == 1)
        #expect(recap.questsDone == 3)
        #expect(recap.lessons == 1)
        #expect(recap.points == 10 + 20 + 15)
        #expect(recap.activeDays == 5) // 16, 17, 18, 20, 21
        #expect(!recap.isEmpty)
    }

    @Test("Pimpi's cheer depends on effort only and is never negative")
    func cheer() {
        func recap(routine: Int, scans: Int = 0, lessons: Int = 0) -> Recap {
            Recap(period: .year(2026), dayCount: 7, routineDays: routine, longestRun: routine, scans: scans,
                  questsDone: 0, lessons: lessons, points: 0, activeDays: routine + scans)
        }
        #expect(RecapEngine.cheer(for: recap(routine: 7)) == .everyDay)
        #expect(RecapEngine.cheer(for: recap(routine: 4)) == .mostDays)
        #expect(RecapEngine.cheer(for: recap(routine: 1)) == .keptLooking)
        #expect(RecapEngine.cheer(for: recap(routine: 0, scans: 1)) == .keptLooking)
        #expect(RecapEngine.cheer(for: recap(routine: 0)) == .freshStart)
    }

    // MARK: When recaps are due

    @Test("The weekly recap shows Sunday (this week) and Monday (last week), Monday to Sunday")
    func weeklyDue() {
        let sunday = RecapEngine.dueWeek(now: date(2026, 11, 22), calendar: calendar)
        #expect(sunday == RecapPeriod(kind: .week, first: day(2026, 11, 16), last: day(2026, 11, 22)))
        let monday = RecapEngine.dueWeek(now: date(2026, 11, 23), calendar: calendar)
        #expect(monday == sunday)
        #expect(RecapEngine.dueWeek(now: date(2026, 11, 24), calendar: calendar) == nil)
        #expect(RecapEngine.dueWeek(now: date(2026, 11, 21), calendar: calendar) == nil)
    }

    @Test("Any day's week runs Monday to Sunday")
    func weekContaining() {
        let expected = RecapPeriod(kind: .week, first: day(2026, 11, 16), last: day(2026, 11, 22))
        for d in 16...22 { #expect(RecapEngine.week(containing: day(2026, 11, d), calendar: calendar) == expected) }
        #expect(RecapEngine.previousMonth(now: date(2026, 11, 23), calendar: calendar).first == day(2026, 10, 1))
    }

    @Test("The weekly recap is the same whichever day the region starts its week on")
    func weeklyIgnoresFirstWeekday() {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        #expect(RecapEngine.dueWeek(now: date(2026, 11, 22), calendar: mondayFirst)
                == RecapEngine.dueWeek(now: date(2026, 11, 22), calendar: calendar))
    }

    @Test("Last month's recap shows in the first three days, across a year boundary too")
    func monthlyDue() {
        let early = RecapEngine.dueMonth(now: date(2026, 3, 2), calendar: calendar)
        #expect(early == RecapPeriod(kind: .month, first: day(2026, 2, 1), last: day(2026, 2, 28)))
        #expect(RecapEngine.dueMonth(now: date(2026, 3, 4), calendar: calendar) == nil)
        #expect(RecapEngine.dueMonth(now: date(2027, 1, 1), calendar: calendar)?.first == day(2026, 12, 1))
    }

    @Test("Wrapped is the quarter that just ended, or the whole year in early January")
    func wrappedDue() {
        let april = RecapEngine.dueWrapped(now: date(2026, 4, 3), calendar: calendar)
        #expect(april == RecapPeriod(kind: .quarter, first: day(2026, 1, 1), last: day(2026, 3, 31)))
        #expect(RecapEngine.dueWrapped(now: date(2027, 1, 5), calendar: calendar) == .year(2026))
        #expect(RecapEngine.dueWrapped(now: date(2026, 4, 9), calendar: calendar) == nil)
        #expect(RecapEngine.dueWrapped(now: date(2026, 5, 2), calendar: calendar) == nil)
        #expect(RecapEngine.latestWrapped(now: date(2026, 11, 23), calendar: calendar).first == day(2026, 7, 1))
        #expect(RecapEngine.latestWrapped(now: date(2026, 2, 1), calendar: calendar).first == day(2025, 10, 1))
    }

    // MARK: Wrapped highlights

    func point(_ m: Int, _ d: Int, index: Int, chin: Int = 0) -> InsightEngine.Point {
        InsightEngine.Point(date: date(2026, m, d), index: index, zoneIndices: [.chin: chin])
    }

    @Test("The calmer zone is the biggest drop between the halves, and none when nothing dropped")
    func calmerZone() {
        let calming = [point(7, 1, index: 20, chin: 6), point(7, 10, index: 20, chin: 5),
                       point(8, 1, index: 10, chin: 2), point(9, 1, index: 10, chin: 1)]
        #expect(WrappedEngine.calmerZone(calming) == .chin)
        let rising = [point(7, 1, index: 1, chin: 1), point(7, 10, index: 1, chin: 1),
                      point(8, 1, index: 9, chin: 6), point(9, 1, index: 9, chin: 7)]
        #expect(WrappedEngine.calmerZone(rising) == nil)
        #expect(WrappedEngine.calmerZone(Array(calming.prefix(3))) == nil)
    }

    @Test("The calmest month needs two months with two scans each, and must beat another month")
    func calmestMonth() {
        let points = [point(7, 2, index: 30), point(7, 20, index: 26), point(8, 3, index: 12), point(8, 25, index: 14),
                      point(9, 9, index: 2)] // September has one scan, so it can't win.
        #expect(WrappedEngine.calmestMonth(points, calendar: calendar)?.first == day(2026, 8, 1))
        #expect(WrappedEngine.calmestMonth(Array(points.prefix(2)), calendar: calendar) == nil)
        let flat = [point(7, 2, index: 5), point(7, 20, index: 5), point(8, 3, index: 5), point(8, 25, index: 5)]
        #expect(WrappedEngine.calmestMonth(flat, calendar: calendar) == nil)
    }

    @Test("Products count for a month only when on the shelf for at least half of it")
    func productsThen() {
        let august = RecapPeriod.month(year: 2026, month: 8, calendar: calendar)
        let shelf = [ShelfStint(productID: 1, started: date(2026, 6, 1), stopped: nil),
                     ShelfStint(productID: 2, started: date(2026, 8, 25), stopped: nil),
                     ShelfStint(productID: 3, started: date(2026, 6, 1), stopped: date(2026, 8, 5)),
                     ShelfStint(productID: 4, started: date(2026, 8, 1), stopped: date(2026, 8, 17))]
        #expect(WrappedEngine.products(on: shelf, during: august, calendar: calendar) == [1, 4])
    }

    @Test("Highlights only use scans inside the period")
    func highlightsPeriod() {
        let points = [point(7, 2, index: 30), point(7, 20, index: 26), point(8, 3, index: 12), point(8, 25, index: 14)]
        let q4 = RecapPeriod.quarter(year: 2026, quarter: 4, calendar: calendar)
        let none = WrappedEngine.highlights(q4, points: points, shelf: [], calendar: calendar)
        #expect(none == WrappedHighlights(calmerZone: nil, calmestMonth: nil, productsThen: []))
    }

    // MARK: Journey

    @Test("Journey stops come from points and lessons, and the last stop is the end")
    func journey() {
        #expect(Journey.xp(points: 120, schoolXP: 30) == 150)
        #expect(Journey.position(xp: 0) == Journey.Position(stop: 1, xp: 0, toNext: 50, progress: 0))
        let mid = Journey.position(xp: 100)
        #expect(mid.stop == 2 && mid.toNext == 50 && mid.progress == 0.5)
        #expect(Journey.position(xp: 150).stop == 3)
        let end = Journey.position(xp: 99_999)
        #expect(end.stop == Journey.stops && end.toNext == nil && end.progress == 1)
        #expect(Journey.position(xp: -5).stop == 1)
        #expect(zip(Journey.thresholds, Journey.thresholds.dropFirst()).allSatisfy { $0 < $1 })
    }

    // MARK: Challenges

    @Test("Thirty days done finishes a challenge; missed days cost nothing")
    func challengeFinishes() {
        let start = day(2026, 11, 1)
        var book = ChallengeEngine.starting(.sunscreen, in: .empty, today: start)
        for index in 0..<45 where index % 4 != 3 { // skip every fourth day
            book = ChallengeEngine.recording(.sunscreen, done: true, in: book, today: start.adding(days: index, calendar: calendar))
        }
        #expect(book.active == nil)
        #expect(book.finished.count == 1)
        #expect(book.finished[0].progress == ChallengeEngine.goalDays)
        #expect(book.finished[0].finished != nil)
    }

    @Test("Only the running challenge's kind counts, untick removes today, and days before the start are ignored")
    func challengeRecording() {
        let today = day(2026, 11, 10)
        var book = ChallengeEngine.starting(.morningAndEvening, in: .empty, today: today)
        book = ChallengeEngine.recording(.sunscreen, done: true, in: book, today: today)
        #expect(book.active?.progress == 0)
        book = ChallengeEngine.recording(.morningAndEvening, done: true, in: book, today: today)
        #expect(book.active?.progress == 1)
        book = ChallengeEngine.recording(.morningAndEvening, done: false, in: book, today: today)
        #expect(book.active?.progress == 0)
        book = ChallengeEngine.recording(.morningAndEvening, done: true, in: book, today: day(2026, 11, 9))
        #expect(book.active?.progress == 0)
        #expect(ChallengeEngine.stopping(book).active == nil)
    }

    @Test("Merging two devices combines days and never revives a finished challenge")
    func challengeMerge() {
        let start = day(2026, 11, 1)
        var a = ChallengeEngine.starting(.handsOff, in: .empty, today: start)
        var b = a
        a = ChallengeEngine.recording(.handsOff, done: true, in: a, today: start)
        b = ChallengeEngine.recording(.handsOff, done: true, in: b, today: day(2026, 11, 2))
        #expect(ChallengeBook.merged(a, b).active?.progress == 2)
        #expect(ChallengeBook.merged(a, b) == ChallengeBook.merged(b, a))

        var done = a.active!
        done.finished = day(2026, 12, 1)
        let finishedCopy = ChallengeBook(active: nil, finished: [done])
        let merged = ChallengeBook.merged(finishedCopy, b)
        #expect(merged.active == nil)
        #expect(merged.finished.count == 1)
    }

    @Test("Synced copies from before challenges existed still load")
    func syncedTolerant() throws {
        let old = #"{"doneDays":[],"weekendOff":false,"celebrated":[],"bestRoutineStreak":3}"#
        let decoded = try JSONDecoder().decode(SyncedEngagement.self, from: Data(old.utf8))
        #expect(decoded.challenges == .empty)
        #expect(decoded.bestRoutineStreak == 3)
    }
}
