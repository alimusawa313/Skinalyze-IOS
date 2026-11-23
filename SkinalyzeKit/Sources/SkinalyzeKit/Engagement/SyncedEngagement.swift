import Foundation
import SwiftData

/// Streak inputs and rewards as they travel through the user's own iCloud (never anywhere else), so they survive a
/// reinstall and appear on the user's other devices. Merging never loses anything: collections are combined, counts
/// take the higher value, settings come from the newer copy.
public struct SyncedEngagement: Codable, Equatable, Sendable {
    public var doneDays: Set<DayStamp>
    public var freezes: FreezeLedger
    public var weekendOff: Bool
    public var celebrated: Set<String>
    public var rewards: RewardLedger
    public var bestRoutineStreak: Int
    /// When this copy last changed. `distantPast` for a copy that has never been synced (a fresh install).
    public var updatedAt: Date

    public static let empty = SyncedEngagement(doneDays: [], freezes: FreezeLedger(available: 1), weekendOff: false,
                                               celebrated: [], rewards: .empty, bestRoutineStreak: 0, updatedAt: .distantPast)

    public init(doneDays: Set<DayStamp>, freezes: FreezeLedger, weekendOff: Bool, celebrated: Set<String>,
                rewards: RewardLedger, bestRoutineStreak: Int, updatedAt: Date) {
        self.doneDays = doneDays
        self.freezes = freezes
        self.weekendOff = weekendOff
        self.celebrated = celebrated
        self.rewards = rewards
        self.bestRoutineStreak = bestRoutineStreak
        self.updatedAt = updatedAt
    }

    public static func merged(_ a: SyncedEngagement, _ b: SyncedEngagement) -> SyncedEngagement {
        // The newer copy decides settings; equal times fall back to a fixed order so merging is symmetric.
        let (newer, older) = a.updatedAt != b.updatedAt
            ? (a.updatedAt > b.updatedAt ? (a, b) : (b, a))
            : (a.orderKey >= b.orderKey ? (a, b) : (b, a))
        var freezes = newer.freezes
        freezes.usedDays = a.freezes.usedDays.union(b.freezes.usedDays)
        freezes.lastRepairDay = [a.freezes.lastRepairDay, b.freezes.lastRepairDay].compactMap { $0 }.max()
        freezes.lastEarnDay = [a.freezes.lastEarnDay, b.freezes.lastEarnDay].compactMap { $0 }.max()
        return SyncedEngagement(doneDays: a.doneDays.union(b.doneDays), freezes: freezes, weekendOff: newer.weekendOff,
                                celebrated: a.celebrated.union(b.celebrated),
                                rewards: RewardLedger.merged(newer: newer.rewards, older: older.rewards),
                                bestRoutineStreak: max(a.bestRoutineStreak, b.bestRoutineStreak),
                                updatedAt: max(a.updatedAt, b.updatedAt))
    }

    /// A stable tie-breaker for copies with the same time.
    private var orderKey: String {
        (try? JSONEncoder.sorted.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}

extension RewardLedger {
    static func merged(newer: RewardLedger, older: RewardLedger) -> RewardLedger {
        var result = newer
        var completed = older.completed
        for (day, kinds) in newer.completed { completed[day, default: []].formUnion(kinds) }
        result.completed = completed
        result.fullDays = newer.fullDays.union(older.fullDays)
        result.monthlyBadges = newer.monthlyBadges.union(older.monthlyBadges)
        result.unlocked = newer.unlocked.union(older.unlocked)
        result.points = max(newer.points, older.points)
        result.shares = max(newer.shares, older.shares)
        result.productChecks = max(newer.productChecks, older.productChecks)
        result.latestDay = [newer.latestDay, older.latestDay].compactMap { $0 }.max()
        // Chests: the most ever earned on either copy, minus the most opened.
        let earned = max(newer.chestsWaiting + newer.chestsOpened, older.chestsWaiting + older.chestsOpened)
        result.chestsOpened = max(newer.chestsOpened, older.chestsOpened)
        result.chestsWaiting = max(0, earned - result.chestsOpened)
        if let worn = result.worn, !result.unlocked.contains(worn) { result.worn = nil }
        return result
    }
}

/// The synced copy in SwiftData (and so in the user's own iCloud). Added in Phase 6; every property is optional or
/// defaulted and there are no relationships, so the CloudKit schema change is additive only.
@Model
public final class EngagementRecord {
    public var payload: Data? = nil
    public var updatedAt: Date = Date.distantPast

    public init(payload: Data?, updatedAt: Date) {
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
