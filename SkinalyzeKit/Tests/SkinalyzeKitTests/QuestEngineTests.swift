import Foundation
import Testing
@testable import SkinalyzeKit

/// Daily quests, glow points, chests, outfits and badges. Rewards count effort only, never skin results.
@Suite("Quests and rewards")
struct QuestEngineTests {
    private let today = DayStamp(year: 2026, month: 11, day: 23)
    private let everything = QuestContext(canScan: true, hasRoutine: true, canCheckProduct: true, scanCount: 4)

    // MARK: Choosing quests

    @Test("Three quests a day, all different")
    func threeDifferentQuests() {
        let quests = QuestEngine.quests(for: today, context: everything)
        #expect(quests.count == QuestEngine.questsPerDay)
        #expect(Set(quests).count == quests.count)
    }

    @Test("The same day always gives the same quests")
    func stableWithinADay() {
        #expect(QuestEngine.quests(for: today, context: everything) == QuestEngine.quests(for: today, context: everything))
    }

    @Test("The quests change from day to day")
    func rotates() {
        let days = (1...7).map { DayStamp(year: 2026, month: 11, day: $0) }
        let sets = Set(days.map { QuestEngine.quests(for: $0, context: everything) })
        #expect(sets.count > 1)
    }

    @Test("Only quests the user can do today are chosen")
    func onlyPossibleQuests() {
        let limited = QuestContext(canScan: false, hasRoutine: false, canCheckProduct: false, scanCount: 0)
        let quests = QuestEngine.quests(for: today, context: limited)
        #expect(!quests.contains(.scan))
        #expect(!quests.contains(.routine))
        #expect(!quests.contains(.productCheck))
        #expect(!quests.contains(.lookBack)) // nothing to look back at
        #expect(!quests.isEmpty)
    }

    @Test("Looking back needs at least two scans")
    func lookBackNeedsHistory() {
        for day in 1...28 {
            let quests = QuestEngine.quests(for: DayStamp(year: 2026, month: 11, day: day),
                                            context: QuestContext(canScan: true, hasRoutine: true, canCheckProduct: true, scanCount: 1))
            #expect(!quests.contains(.lookBack))
        }
    }

    // MARK: Points and chests

    @Test("Doing one of today's quests earns its points once")
    func earnsOnce() {
        let quests = QuestEngine.quests(for: today, context: everything)
        let kind = quests[0]
        let (once, award) = RewardEngine.record(kind, day: today, todaysQuests: quests, ledger: .empty, isPro: false)
        #expect(award?.points == QuestEngine.points(for: kind))
        #expect(once.points == QuestEngine.points(for: kind))
        let (twice, again) = RewardEngine.record(kind, day: today, todaysQuests: quests, ledger: once, isPro: false)
        #expect(again == nil)
        #expect(twice == once)
    }

    @Test("Something that is not one of today's quests earns nothing")
    func onlyTodaysQuests() {
        let quests: [QuestKind] = [.routine, .scan, .share]
        let (ledger, award) = RewardEngine.record(.productCheck, day: today, todaysQuests: quests, ledger: .empty, isPro: false)
        #expect(award == nil)
        #expect(ledger == .empty)
    }

    @Test("Pro earns double points")
    func proDoubles() {
        let quests: [QuestKind] = [.routine, .scan, .share]
        let (_, award) = RewardEngine.record(.routine, day: today, todaysQuests: quests, ledger: .empty, isPro: true)
        #expect(award?.points == QuestEngine.points(for: .routine) * 2)
    }

    @Test("Finishing all of today's quests earns one chest")
    func allDoneEarnsChest() {
        let quests: [QuestKind] = [.routine, .scan, .share]
        var ledger = RewardLedger.empty
        var chests = 0
        for kind in quests {
            let result = RewardEngine.record(kind, day: today, todaysQuests: quests, ledger: ledger, isPro: false)
            ledger = result.0
            if result.1?.earnedChest == true { chests += 1 }
        }
        #expect(chests == 1)
        #expect(ledger.chestsWaiting == 1)
        #expect(RewardEngine.completed(on: today, ledger: ledger) == Set(quests))
    }

    // MARK: Clock tampering

    @Test("Setting the clock back to an earlier day earns nothing")
    func clockBackEarnsNothing() {
        let quests: [QuestKind] = [.routine, .scan, .share]
        let (seen, _) = RewardEngine.record(.routine, day: today, todaysQuests: quests, ledger: .empty, isPro: false)
        let yesterday = DayStamp(year: 2026, month: 11, day: 22)
        let (after, award) = RewardEngine.record(.scan, day: yesterday, todaysQuests: quests, ledger: seen, isPro: false)
        #expect(award == nil)
        #expect(after == seen)
    }

    @Test("Coming back from a day set in the future earns nothing until that day really comes")
    func forwardJumpCannotRepeat() {
        let quests: [QuestKind] = [.routine, .scan, .share]
        let future = DayStamp(year: 2026, month: 12, day: 20)
        let (jumped, _) = RewardEngine.record(.routine, day: future, todaysQuests: quests, ledger: .empty, isPro: false)
        let (back, award) = RewardEngine.record(.scan, day: today, todaysQuests: quests, ledger: jumped, isPro: false)
        #expect(award == nil)
        #expect(back == jumped)
    }

    // MARK: Chests and outfits

    @Test("Opening a chest gives an outfit not owned yet and uses up the chest")
    func chestGivesNewOutfit() throws {
        var ledger = RewardLedger.empty
        ledger.chestsWaiting = 2
        let (first, reward1) = RewardEngine.openChest(ledger, isPro: false)
        let (second, reward2) = RewardEngine.openChest(first, isPro: false)
        let outfit1 = try #require(reward1?.outfit)
        let outfit2 = try #require(reward2?.outfit)
        #expect(outfit1 != outfit2)
        #expect(second.unlocked == [outfit1, outfit2])
        #expect(second.chestsWaiting == 0)
    }

    @Test("No chest, nothing to open")
    func noChest() {
        let (ledger, reward) = RewardEngine.openChest(.empty, isPro: false)
        #expect(reward == nil)
        #expect(ledger == .empty)
    }

    @Test("Free chests only hold free outfits; Pro chests can hold Pro sets")
    func proOutfitsNeedPro() {
        var ledger = RewardLedger.empty
        ledger.chestsWaiting = PimpiOutfit.allCases.count
        var opened = ledger
        for _ in PimpiOutfit.allCases {
            opened = RewardEngine.openChest(opened, isPro: false).0
        }
        // The first-week scarf is never in a chest.
        #expect(opened.unlocked == Set(PimpiOutfit.allCases.filter { !$0.isPro && !$0.isFirstWeekReward }))
        var pro = ledger
        for _ in PimpiOutfit.allCases {
            pro = RewardEngine.openChest(pro, isPro: true).0
        }
        #expect(pro.unlocked == Set(PimpiOutfit.allCases.filter { !$0.isFirstWeekReward }))
    }

    @Test("When every outfit is owned, a chest gives bonus points instead")
    func bonusWhenAllOwned() {
        var ledger = RewardLedger.empty
        ledger.unlocked = Set(PimpiOutfit.allCases)
        ledger.chestsWaiting = 1
        let (opened, reward) = RewardEngine.openChest(ledger, isPro: true)
        #expect(reward?.outfit == nil)
        #expect(reward?.bonusPoints == RewardEngine.chestBonusPoints)
        #expect(opened.points == RewardEngine.chestBonusPoints)
    }

    @Test("An outfit can be worn only once it is owned")
    func wearOnlyOwned() {
        var ledger = RewardLedger.empty
        #expect(RewardEngine.wearing(.crown, ledger: ledger) == ledger)
        ledger.unlocked = [.partyHat]
        #expect(RewardEngine.wearing(.partyHat, ledger: ledger).worn == .partyHat)
        #expect(RewardEngine.wearing(nil, ledger: RewardEngine.wearing(.partyHat, ledger: ledger)).worn == nil)
    }

    // MARK: Badges (effort only)

    @Test("Badges come from things the user did, never from skin results")
    func badges() {
        let none = BadgeEngine.earned(BadgeFacts(scans: 0, has3DScan: false, bestRoutineStreak: 0,
                                                 productChecks: 0, shares: 0, questDays: 0))
        #expect(none.isEmpty)
        let some = BadgeEngine.earned(BadgeFacts(scans: 1, has3DScan: true, bestRoutineStreak: 7,
                                                 productChecks: 10, shares: 1, questDays: 7))
        #expect(some == Set(Badge.allCases))
    }

    @Test("Each badge has its own threshold", arguments: Badge.allCases)
    func thresholds(badge: Badge) {
        var facts = BadgeFacts(scans: 0, has3DScan: false, bestRoutineStreak: 0, productChecks: 0, shares: 0, questDays: 0)
        switch badge {
        case .firstScan: facts.scans = 1
        case .first3D: facts.has3DScan = true
        case .routineWeek: facts.bestRoutineStreak = 7
        case .tenChecks: facts.productChecks = 10
        case .firstShare: facts.shares = 1
        case .questWeek: facts.questDays = 7
        }
        #expect(BadgeEngine.earned(facts) == [badge])
    }

    // MARK: Monthly quest (E8)

    /// Finishes every quest on `day`.
    private func finishDay(_ day: DayStamp, _ ledger: RewardLedger) -> RewardLedger {
        let quests: [QuestKind] = [.routine, .scan, .share]
        return quests.reduce(ledger) { RewardEngine.record($1, day: day, todaysQuests: quests, ledger: $0, isPro: false).0 }
    }

    @Test("Only days with every quest done count toward the month")
    func monthCountsFullDays() {
        var ledger = finishDay(DayStamp(year: 2026, month: 11, day: 1), .empty)
        let quests: [QuestKind] = [.routine, .scan, .share]
        ledger = RewardEngine.record(.routine, day: DayStamp(year: 2026, month: 11, day: 2), todaysQuests: quests,
                                     ledger: ledger, isPro: false).0
        let progress = RewardEngine.monthlyProgress(ledger, year: 2026, month: 11)
        #expect(progress.days == 1)
        #expect(progress.goal == RewardEngine.monthlyGoalDays)
    }

    @Test("A day with fewer than three possible quests counts once all of its quests are done")
    func shortDaysCount() {
        let quests: [QuestKind] = [.share]
        let ledger = RewardEngine.record(.share, day: DayStamp(year: 2026, month: 11, day: 5), todaysQuests: quests,
                                         ledger: .empty, isPro: false).0
        #expect(RewardEngine.monthlyProgress(ledger, year: 2026, month: 11).days == 1)
        #expect(ledger.fullQuestDays == 1)
    }

    @Test("Reaching the goal earns that month's badge, once; other months start again")
    func monthlyBadge() {
        var ledger = RewardLedger.empty
        for day in 1...RewardEngine.monthlyGoalDays {
            ledger = finishDay(DayStamp(year: 2026, month: 11, day: day), ledger)
        }
        #expect(ledger.monthlyBadges == ["2026-11"])
        ledger = finishDay(DayStamp(year: 2026, month: 11, day: 25), ledger)
        #expect(ledger.monthlyBadges == ["2026-11"])
        #expect(RewardEngine.monthlyProgress(ledger, year: 2026, month: 12).days == 0)
    }

    @Test("Old ledgers without newer fields still load")
    func decodesTolerantly() throws {
        let ledger = try JSONDecoder().decode(RewardLedger.self, from: Data(#"{"points": 40}"#.utf8))
        #expect(ledger.points == 40)
        #expect(ledger.unlocked.isEmpty)
    }
}
