import Foundation
import Observation
import SkinalyzeKit

/// Today's quests and everything earned: glow points, chests, Pimpi's outfits, badge counters. The rules live in
/// SkinalyzeKit (`QuestEngine`, `RewardEngine`); this keeps them on the phone and reports what happened.
@Observable
@MainActor
final class QuestModel {
    private enum Key {
        static let ledger = "rewardLedger"
        static let assignment = "questAssignment"
        static let bestRoutineStreak = "bestRoutineStreak"
    }

    /// The day's quests are fixed when the day starts, so finishing one never swaps the list.
    private struct Assignment: Codable {
        let day: DayStamp
        let quests: [QuestKind]
    }

    private(set) var ledger: RewardLedger
    private(set) var todaysQuests: [QuestKind] = []
    private(set) var bestRoutineStreak: Int
    /// The latest quest finished, for a moment of celebration.
    private(set) var lastAward: RewardEngine.Award?

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var assignment: Assignment?
    private var lastContext = QuestContext(canScan: true, hasRoutine: false, canCheckProduct: true, scanCount: 0)

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        ledger = defaults.data(forKey: Key.ledger).flatMap { try? JSONDecoder().decode(RewardLedger.self, from: $0) } ?? .empty
        assignment = defaults.data(forKey: Key.assignment).flatMap { try? JSONDecoder().decode(Assignment.self, from: $0) }
        bestRoutineStreak = defaults.integer(forKey: Key.bestRoutineStreak)
        #if DEBUG
        // `-questDebugChests N`: chests waiting on a fresh install, to check the chest moment in the Simulator.
        let debugChests = defaults.integer(forKey: "questDebugChests")
        if debugChests > 0, ledger.chestsWaiting == 0 { ledger.chestsWaiting = debugChests }
        #endif
        if let assignment, assignment.day == DayStamp(.now, calendar: calendar) { todaysQuests = assignment.quests }
    }

    var completedToday: Set<QuestKind> {
        RewardEngine.completed(on: DayStamp(.now, calendar: calendar), ledger: ledger)
    }

    /// Picks today's quests the first time it is called on a new day.
    func prepare(context: QuestContext, now: Date = .now) {
        lastContext = context
        let today = DayStamp(now, calendar: calendar)
        if let assignment, assignment.day == today {
            todaysQuests = assignment.quests
            return
        }
        let fresh = Assignment(day: today, quests: QuestEngine.quests(for: today, context: context))
        assignment = fresh
        todaysQuests = fresh.quests
        defaults.set(try? JSONEncoder().encode(fresh), forKey: Key.assignment)
    }

    /// Something happened. Counts toward badges when `counts` is true, and earns if it is one of today's quests.
    func did(_ kind: QuestKind, isPro: Bool, counts: Bool = true, now: Date = .now) {
        prepare(context: lastContext, now: now)
        var updated = counts ? RewardEngine.counting(kind, ledger: ledger) : ledger
        let (earned, award) = RewardEngine.record(kind, day: DayStamp(now, calendar: calendar), todaysQuests: todaysQuests,
                                                  ledger: updated, isPro: isPro)
        updated = earned
        if let award { lastAward = award }
        save(updated)
    }

    func openChest(isPro: Bool) -> RewardEngine.ChestReward? {
        let (opened, reward) = RewardEngine.openChest(ledger, isPro: isPro)
        save(opened)
        return reward
    }

    func wear(_ outfit: PimpiOutfit?) {
        save(RewardEngine.wearing(outfit, ledger: ledger))
    }

    /// Takes rewards merged from the user's other devices (or from before a reinstall).
    func applySynced(_ merged: SyncedEngagement) {
        save(merged.rewards)
        noteRoutineStreak(merged.bestRoutineStreak)
    }

    func noteRoutineStreak(_ days: Int) {
        guard days > bestRoutineStreak else { return }
        bestRoutineStreak = days
        defaults.set(days, forKey: Key.bestRoutineStreak)
    }

    private func save(_ updated: RewardLedger) {
        guard updated != ledger else { return }
        if updated.worn != ledger.worn { EngagementShared.publishOutfit(updated.worn) }
        ledger = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Key.ledger)
    }
}
