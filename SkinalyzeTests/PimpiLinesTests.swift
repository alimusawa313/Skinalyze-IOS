import Foundation
import Testing
@testable import Skinalyze
import SkinalyzeKit

/// Pimpi's poke lines (PimpiLines.json): the pool is complete and safe to say, and the picker is fresh but predictable.
@Suite("Pimpi lines")
struct PimpiLinesTests {
    private static let maxLength = 70
    private static let minimumPerContext = 8
    /// PLAN.md §15.1 — matched anywhere in the text, so "treatment" or "cured" are caught too.
    private static let bannedEnglish = ["diagnos", "treat", "cure", "disease", "prescri", "clinically proven", "medical", "severe"]
    private static let bannedIndonesian = ["diagnos", "obat", "sembuh", "penyakit", "resep", "medis", "parah", "klinis"]

    private let pool: PimpiLines

    init() throws {
        pool = try PimpiLines.decode(PimpiLines.bundledData())
    }

    @Test("The bundled pool decodes and has around eighty lines")
    func decodes() {
        #expect(pool.lines.count >= 80)
        #expect(!pool.lines.contains { $0.id == PimpiLine.fallback.id })
    }

    @Test("Every id is unique")
    func uniqueIDs() {
        let ids = pool.lines.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every line has English and Indonesian that fit a speech bubble")
    func textFits() {
        for line in pool.lines {
            for text in [line.text.en, line.text.id] {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(!trimmed.isEmpty, "\(line.id) is empty")
                #expect(text.count <= Self.maxLength, "\(line.id) is \(text.count) characters: \(text)")
            }
            #expect(line.text.en != line.text.id, "\(line.id) is not translated")
        }
    }

    @Test("Every line says where it can be said")
    func everyLineHasAPlace() {
        for line in pool.lines {
            #expect(!line.contexts.isDisjoint(with: PimpiLine.Tag.places), "\(line.id) has no place")
        }
    }

    @Test("Every context has at least eight lines", arguments: PimpiLine.Tag.allCases)
    func contextCoverage(tag: PimpiLine.Tag) {
        let count = pool.lines.filter { $0.contexts.contains(tag) }.count
        #expect(count >= Self.minimumPerContext, "\(tag) has \(count)")
    }

    @Test("Every place has at least eight lines at every time of day, streak or not")
    func eligibleCoverage() {
        for place in PimpiPlace.allCases {
            for time in PimpiTimeOfDay.allCases {
                for hasStreak in [false, true] {
                    let count = pool.eligible(place: place, time: time, hasStreak: hasStreak).count
                    #expect(count >= Self.minimumPerContext, "\(place) \(time) streak \(hasStreak): \(count)")
                }
            }
        }
    }

    @Test("No medical or diagnosis wording, in either language")
    func bannedWords() {
        for line in pool.lines {
            let english = line.text.en.lowercased()
            let indonesian = line.text.id.lowercased()
            for word in Self.bannedEnglish {
                #expect(!english.contains(word), "\(line.id) (en) contains \(word)")
                #expect(!indonesian.contains(word), "\(line.id) (id) contains \(word)")
            }
            for word in Self.bannedIndonesian {
                #expect(!indonesian.contains(word), "\(line.id) (id) contains \(word)")
            }
        }
    }

    @Test("A line with an unknown mood fails to decode")
    func unknownMood() {
        let json = #"{"lines":[{"id":"x","text":{"en":"Hi","id":"Hai"},"mood":"grumpy","contexts":["any"]}]}"#
        #expect(throws: DecodingError.self) { try PimpiLines.decode(Data(json.utf8)) }
    }

    // MARK: Fitting

    @Test("Time-of-day lines only show at their time, streak lines only with a streak")
    func fitting() throws {
        let morning = try #require(pool.lines.first { $0.contexts == [.any, .morning] })
        #expect(morning.fits(place: .home, time: .morning, hasStreak: false))
        #expect(!morning.fits(place: .home, time: .afternoon, hasStreak: false))
        #expect(!morning.fits(place: .home, time: .night, hasStreak: false))

        let streak = try #require(pool.lines.first { $0.contexts.contains(.streak) })
        #expect(streak.fits(place: .result, time: .afternoon, hasStreak: true))
        #expect(!streak.fits(place: .result, time: .afternoon, hasStreak: false))
        #expect(!streak.fits(place: .shelf, time: .afternoon, hasStreak: true))

        let shelfOnly = try #require(pool.lines.first { $0.contexts == [.shelf] })
        #expect(!shelfOnly.fits(place: .home, time: .afternoon, hasStreak: true))
    }

    @Test("Hours map to parts of the day", arguments: [
        (4, PimpiTimeOfDay.night), (5, .morning), (11, .morning), (12, .afternoon), (16, .afternoon),
        (17, .evening), (21, .evening), (22, .night), (0, .night),
    ])
    func timeOfDay(hour: Int, expected: PimpiTimeOfDay) {
        #expect(PimpiTimeOfDay(hour: hour) == expected)
    }

    // MARK: Picker

    @Test("Pimpi never says the same line twice in a row", arguments: PimpiPlace.allCases)
    func noBackToBackRepeats(place: PimpiPlace) {
        let lines = pool.eligible(place: place, time: .afternoon, hasStreak: true)
        for day in 0..<5 {
            let seed = PimpiLinePicker.seed(day: day, place: place)
            let said = (1...(lines.count * 3 + 1)).compactMap { PimpiLinePicker.pick(poke: $0, from: lines, seed: seed)?.id }
            for (previous, next) in zip(said, said.dropFirst()) {
                #expect(previous != next)
            }
        }
    }

    @Test("Two lines alternate, and one line just repeats")
    func tinyPools() throws {
        let two = Array(pool.lines.prefix(2))
        let said = (1...10).compactMap { PimpiLinePicker.pick(poke: $0, from: two, seed: 7)?.id }
        for (previous, next) in zip(said, said.dropFirst()) {
            #expect(previous != next)
        }
        let one = Array(pool.lines.prefix(1))
        #expect(PimpiLinePicker.pick(poke: 3, from: one, seed: 7)?.id == one[0].id)
        #expect(PimpiLinePicker.pick(poke: 1, from: [], seed: 7) == nil)
    }

    @Test("Every line comes up once per round")
    func fullRound() {
        let lines = pool.eligible(place: .home, time: .morning, hasStreak: false)
        let seed = PimpiLinePicker.seed(day: 42, place: .home)
        let round = (1...lines.count).compactMap { PimpiLinePicker.pick(poke: $0, from: lines, seed: seed)?.id }
        #expect(Set(round) == Set(lines.map(\.id)))
    }

    @Test("The same seed gives the same lines; another day gives another order")
    func deterministic() {
        let lines = pool.eligible(place: .shelf, time: .afternoon, hasStreak: false)
        let today = PimpiLinePicker.seed(day: 100, place: .shelf)
        let tomorrow = PimpiLinePicker.seed(day: 101, place: .shelf)
        let first = (1...30).compactMap { PimpiLinePicker.pick(poke: $0, from: lines, seed: today)?.id }
        let again = (1...30).compactMap { PimpiLinePicker.pick(poke: $0, from: lines.reversed(), seed: today)?.id }
        let next = (1...30).compactMap { PimpiLinePicker.pick(poke: $0, from: lines, seed: tomorrow)?.id }
        #expect(first == again)
        #expect(first != next)
    }

    @Test("A poke at a place and time picks a line that fits there")
    func lineForPlace() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let night = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 23)))
        for poke in 1...40 {
            let line = pool.line(poke: poke, place: .shelf, date: night, calendar: calendar)
            #expect(line.fits(place: .shelf, time: .night, hasStreak: false))
            #expect(line == pool.line(poke: poke, place: .shelf, date: night, calendar: calendar))
        }
    }

    @Test("An empty pool falls back to the showing-up line")
    func emptyPool() {
        #expect(PimpiLines(lines: []).line(poke: 1, place: .home) == PimpiLine.fallback)
    }

    @Test("Indonesian is used only when the app runs in Indonesian")
    func language() throws {
        let line = try #require(pool.lines.first)
        #expect(line.text.text(for: "id") == line.text.id)
        #expect(line.text.text(for: "en") == line.text.en)
        #expect(line.text.text(for: nil) == line.text.en)
    }
}
