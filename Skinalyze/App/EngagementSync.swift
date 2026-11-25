import Foundation
import OSLog
import SwiftData
import SkinalyzeKit

/// Keeps streak inputs and rewards in the user's own iCloud (through SwiftData's CloudKit sync), so they survive a
/// reinstall and follow the user to their other devices. The merge rules live in `SyncedEngagement` (tested).
@MainActor
struct EngagementSync {
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "EngagementSync")
    private static let lastSyncedKey = "engagementLastSynced"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var store: EngagementStore { EngagementStore(defaults: defaults) }

    /// This device's copy. A device that has never synced is dated `distantPast`, so it never overrides iCloud.
    func local(rewards: RewardLedger, bestRoutineStreak: Int, school: SchoolProgress = .empty,
               challenges: ChallengeBook = .empty, social: SocialState = .empty, tutorial: TutorialState = TutorialState(),
               now: Date = .now) -> SyncedEngagement {
        var copy = SyncedEngagement(doneDays: store.doneDays, freezes: store.ledger, weekendOff: store.weekendOff,
                                    celebrated: store.celebrated, rewards: rewards, bestRoutineStreak: bestRoutineStreak,
                                    school: school, challenges: challenges, social: social, tutorial: tutorial,
                                    updatedAt: .distantPast)
        guard let last = lastSynced else { return copy }
        var unchanged = copy
        unchanged.updatedAt = last.updatedAt
        copy.updatedAt = unchanged == last ? last.updatedAt : now
        return copy
    }

    private var lastSynced: SyncedEngagement? {
        defaults.data(forKey: Self.lastSyncedKey).flatMap { try? JSONDecoder().decode(SyncedEngagement.self, from: $0) }
    }

    /// Merges this device with every synced copy, keeps one record, and returns the result when it differs from what
    /// this device had (the caller then applies it).
    @discardableResult
    func sync(local: SyncedEngagement, context: ModelContext) -> SyncedEngagement? {
        let records: [EngagementRecord]
        do {
            records = try context.fetch(FetchDescriptor<EngagementRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        } catch {
            Self.logger.error("Could not read synced engagement: \(error.localizedDescription)")
            return nil
        }
        let remote = records.compactMap { $0.payload.flatMap { try? JSONDecoder().decode(SyncedEngagement.self, from: $0) } }
        let merged = remote.reduce(local, SyncedEngagement.merged)
        guard let payload = try? JSONEncoder().encode(merged) else { return nil }

        // One record is enough: keep the newest, update it, remove copies made by other devices.
        if let keep = records.first {
            // Only the time changed: leave the record alone. Writing it would fire this sync again, so a value that
            // can't be applied locally would otherwise loop forever.
            var kept = keep.payload.flatMap { try? JSONDecoder().decode(SyncedEngagement.self, from: $0) }
            kept?.updatedAt = merged.updatedAt
            if keep.payload != payload, kept != merged {
                keep.payload = payload
                keep.updatedAt = merged.updatedAt
            }
            records.dropFirst().forEach(context.delete)
        } else {
            context.insert(EngagementRecord(payload: payload, updatedAt: merged.updatedAt))
        }
        do {
            if context.hasChanges { try context.save() }
        } catch {
            Self.logger.error("Could not save synced engagement: \(error.localizedDescription)")
        }
        defaults.set(payload, forKey: Self.lastSyncedKey)

        var comparable = merged
        comparable.updatedAt = local.updatedAt
        return comparable == local ? nil : merged
    }

    /// Writes a merged copy into this device's streak store (rewards are applied by `QuestModel`).
    func applyStreaks(_ merged: SyncedEngagement) {
        let store = self.store
        merged.doneDays.subtracting(store.doneDays).forEach { store.setDone(true, on: $0) }
        store.ledger = merged.freezes
        store.weekendOff = merged.weekendOff
        store.celebrated = merged.celebrated
    }
}
