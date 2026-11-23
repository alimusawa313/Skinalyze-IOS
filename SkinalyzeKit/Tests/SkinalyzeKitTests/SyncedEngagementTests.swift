import Foundation
import Testing
@testable import SkinalyzeKit

/// Streaks and rewards from two devices (or a reinstall) combine without losing anything.
@Suite("Synced streaks and rewards")
struct SyncedEngagementTests {
    private let early = Date(timeIntervalSince1970: 1_000)
    private let late = Date(timeIntervalSince1970: 2_000)

    private func day(_ d: Int) -> DayStamp { DayStamp(year: 2026, month: 11, day: d) }

    private var phone: SyncedEngagement {
        var rewards = RewardLedger.empty
        rewards.points = 120
        rewards.completed = [day(20).string: [.routine, .scan]]
        rewards.fullDays = [day(19).string]
        rewards.unlocked = [.partyHat]
        rewards.worn = .partyHat
        rewards.chestsOpened = 1
        rewards.chestsWaiting = 1
        rewards.shares = 3
        rewards.latestDay = day(20)
        return SyncedEngagement(doneDays: [day(18), day(19), day(20)],
                                freezes: FreezeLedger(available: 2, usedDays: [day(10)], lastRepairDay: day(5), lastEarnDay: day(17)),
                                weekendOff: true, celebrated: ["routine-7"], rewards: rewards, bestRoutineStreak: 9,
                                updatedAt: late)
    }

    private var tablet: SyncedEngagement {
        var rewards = RewardLedger.empty
        rewards.points = 80
        rewards.completed = [day(20).string: [.share], day(21).string: [.routine]]
        rewards.fullDays = [day(15).string]
        rewards.unlocked = [.beanie]
        rewards.worn = .beanie
        rewards.chestsOpened = 2
        rewards.chestsWaiting = 0
        rewards.productChecks = 4
        rewards.monthlyBadges = ["2026-10"]
        rewards.latestDay = day(21)
        return SyncedEngagement(doneDays: [day(21)],
                                freezes: FreezeLedger(available: 0, usedDays: [day(12)], lastRepairDay: nil, lastEarnDay: day(14)),
                                weekendOff: false, celebrated: ["scan-4"], rewards: rewards, bestRoutineStreak: 4,
                                updatedAt: early)
    }

    @Test("Days, outfits, badges and finished quests from both are kept")
    func keepsEverything() {
        let merged = SyncedEngagement.merged(phone, tablet)
        #expect(merged.doneDays == [day(18), day(19), day(20), day(21)])
        #expect(merged.freezes.usedDays == [day(10), day(12)])
        #expect(merged.celebrated == ["routine-7", "scan-4"])
        #expect(merged.rewards.unlocked == [.partyHat, .beanie])
        #expect(merged.rewards.completed[day(20).string] == [.routine, .scan, .share])
        #expect(merged.rewards.completed[day(21).string] == [.routine])
        #expect(merged.rewards.fullDays == [day(15).string, day(19).string])
        #expect(merged.rewards.monthlyBadges == ["2026-10"])
    }

    @Test("Counts take the higher value; settings come from the newer copy")
    func countsAndSettings() {
        let merged = SyncedEngagement.merged(phone, tablet)
        #expect(merged.rewards.points == 120)
        #expect(merged.rewards.shares == 3)
        #expect(merged.rewards.productChecks == 4)
        #expect(merged.bestRoutineStreak == 9)
        #expect(merged.rewards.latestDay == day(21))
        #expect(merged.weekendOff == true)        // phone is newer
        #expect(merged.rewards.worn == .partyHat)  // phone is newer
        #expect(merged.freezes.available == 2)
        #expect(merged.freezes.lastRepairDay == day(5))
        #expect(merged.freezes.lastEarnDay == day(17))
        #expect(merged.updatedAt == late)
    }

    @Test("Chests: no chest is earned twice and none is lost")
    func chestsAreCountedOnce() {
        let merged = SyncedEngagement.merged(phone, tablet)
        // Phone earned 2 in total (1 opened + 1 waiting), tablet 2 (2 opened): 2 earned, 2 opened.
        #expect(merged.rewards.chestsOpened == 2)
        #expect(merged.rewards.chestsWaiting == 0)
    }

    @Test("Merging is the same in either order, and merging twice changes nothing")
    func orderAndRepeat() {
        let ab = SyncedEngagement.merged(phone, tablet)
        #expect(ab == SyncedEngagement.merged(tablet, phone))
        #expect(SyncedEngagement.merged(ab, tablet) == ab)
        #expect(SyncedEngagement.merged(phone, phone) == phone)
    }

    @Test("A fresh install (empty, never synced) never overrides what is in iCloud")
    func freshInstallLoses() {
        let fresh = SyncedEngagement.empty
        let merged = SyncedEngagement.merged(fresh, phone)
        #expect(merged == phone)
    }

    @Test("An outfit is only worn if it is owned after the merge")
    func wornMustBeOwned() {
        var newer = tablet
        newer.updatedAt = Date(timeIntervalSince1970: 3_000)
        newer.rewards.worn = .crown // not owned on either device
        let merged = SyncedEngagement.merged(phone, newer)
        #expect(merged.rewards.worn == nil || merged.rewards.unlocked.contains(merged.rewards.worn!))
    }

    @Test("It round-trips through its stored form")
    func codes() throws {
        let data = try JSONEncoder().encode(phone)
        #expect(try JSONDecoder().decode(SyncedEngagement.self, from: data) == phone)
    }
}
