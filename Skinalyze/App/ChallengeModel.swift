import Foundation
import Observation
import SkinalyzeKit

/// 30-day challenges (E17): the running one and the finished ones. Rules live in `ChallengeEngine` (tested); this only
/// stores the book and hears about the day's routine.
@Observable
@MainActor
final class ChallengeModel {
    private static let bookKey = "challengeBook"

    private(set) var book: ChallengeBook
    /// Set when a challenge has just been finished, for the celebration.
    var justFinished: Challenge?
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        book = defaults.data(forKey: Self.bookKey).flatMap { try? JSONDecoder().decode(ChallengeBook.self, from: $0) } ?? .empty
    }

    private func today(_ now: Date) -> DayStamp { DayStamp(now, calendar: calendar) }

    func start(_ kind: ChallengeKind, now: Date = .now) {
        save(ChallengeEngine.starting(kind, in: book, today: today(now)))
    }

    func stop() {
        save(ChallengeEngine.stopping(book))
    }

    var isDoneToday: Bool { book.active?.doneDays.contains(today(.now)) ?? false }

    /// The routine checklist changed: sunscreen and morning-and-evening challenges follow it.
    func routineChanged(_ log: RoutineLog, now: Date = .now) {
        guard let kind = book.active?.kind else { return }
        switch kind {
        case .sunscreen:
            record(kind, done: log.isDone(part: RoutineChecklist.Part.morning.rawValue,
                                          slot: ProductCatalog.Slot.sunscreen.rawValue, on: now), now: now)
        case .morningAndEvening:
            record(kind, done: log.hasAnyStep(part: RoutineChecklist.Part.morning.rawValue, on: now)
                && log.hasAnyStep(part: RoutineChecklist.Part.evening.rawValue, on: now), now: now)
        case .handsOff:
            break
        }
    }

    /// "I kept my hands off my face today" — the user's own check-in.
    func toggleHandsOff(now: Date = .now) {
        record(.handsOff, done: !isDoneToday, now: now)
    }

    func applySynced(_ merged: ChallengeBook) {
        save(merged)
    }

    private func record(_ kind: ChallengeKind, done: Bool, now: Date) {
        let before = book.finished.count
        let updated = ChallengeEngine.recording(kind, done: done, in: book, today: today(now))
        save(updated)
        if updated.finished.count > before { justFinished = updated.finished.last }
    }

    private func save(_ updated: ChallengeBook) {
        guard updated != book else { return }
        book = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Self.bookKey)
    }
}
