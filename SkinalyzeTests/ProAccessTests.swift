import Foundation
import StoreKit
import StoreKitTest
import SwiftData
import Testing
import SkinalyzeKit
@testable import Skinalyze

private func freshDefaults() -> UserDefaults {
    let name = "pro-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Free product checks: three different products a month; opening one already checked never counts again.
@Suite("Product check ledger")
struct ProductCheckLedgerTests {
    private let free = AccessPolicy(hasFullAccess: false)

    @Test("A fourth different product this month is refused; the first three stay open")
    func limitsDifferentProducts() {
        let ledger = ProductCheckLedger(defaults: freshDefaults())
        for key in ["a", "b", "c"] {
            #expect(ledger.canCheck(key, policy: free))
            ledger.record(key)
        }
        #expect(!ledger.canCheck("d", policy: free))
        #expect(ledger.canCheck("b", policy: free))
    }

    @Test("Opening the same product again does not use another check")
    func sameProductCountsOnce() {
        let ledger = ProductCheckLedger(defaults: freshDefaults())
        for _ in 0..<5 { ledger.record("a") }
        #expect(ledger.canCheck("b", policy: free))
        ledger.record("b")
        #expect(ledger.canCheck("c", policy: free))
    }

    @Test("Checks from an earlier month do not count")
    func monthResets() {
        let ledger = ProductCheckLedger(defaults: freshDefaults())
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        for key in ["a", "b", "c"] { ledger.record(key, now: lastMonth) }
        #expect(ledger.canCheck("d", policy: free))
    }

    @Test("Full access checks anything")
    func fullAccess() {
        let ledger = ProductCheckLedger(defaults: freshDefaults())
        for key in ["a", "b", "c"] { ledger.record(key) }
        #expect(ledger.canCheck("d", policy: AccessPolicy(hasFullAccess: true)))
    }
}

/// The subscription walked through StoreKit's local test environment (Config/SkinalyzePro.storekit).
@MainActor
@Suite("Pro subscription", .serialized)
struct ProSubscriptionTests {
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "SkinalyzePro")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test("Three plans load in paywall order — annual, monthly, weekly — and there is no lifetime plan")
    func loadsPlans() async throws {
        _ = try makeSession()
        let access = ProAccess(defaults: freshDefaults())
        await access.loadProducts()
        #expect(access.loadState == .loaded)
        #expect(access.products.map(\.id) == ProAccess.ProductID.all)
        #expect(access.products.allSatisfy { $0.type == .autoRenewable })
    }

    @Test("Only the annual plan has the free trial, and a new customer is eligible for it")
    func annualTrial() async throws {
        _ = try makeSession()
        let access = ProAccess(defaults: freshDefaults())
        await access.loadProducts()
        let annual = try #require(access.products.first { $0.id == ProAccess.ProductID.annual })
        #expect(annual.subscription?.introductoryOffer?.paymentMode == .freeTrial)
        #expect(await annual.subscription?.isEligibleForIntroOffer == true)
        let others = access.products.filter { $0.id != ProAccess.ProductID.annual }
        #expect(others.allSatisfy { $0.subscription?.introductoryOffer == nil })
    }

    /// Expiry and refunds reach the app asynchronously; give StoreKit a few seconds.
    private func waitUntilLocked(_ access: ProAccess) async {
        for _ in 0..<50 where access.isSubscribed {
            await access.refreshEntitlement()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Buys through the app's own purchase path (the paywall's Continue button).
    private func buy(_ id: String, with access: ProAccess) async throws {
        await access.loadProducts()
        let product = try #require(access.products.first { $0.id == id })
        #expect(await access.purchase(product) == .success)
    }

    @Test("Buying a plan gives full access")
    func purchaseUnlocks() async throws {
        _ = try makeSession()
        let access = ProAccess(defaults: freshDefaults())
        await access.refreshEntitlement()
        #expect(!access.policy.hasFullAccess)
        try await buy(ProAccess.ProductID.monthly, with: access)
        #expect(access.isSubscribed)
        #expect(access.policy.hasFullAccess)
    }

    @Test("An expired subscription takes full access away")
    func expiryLocks() async throws {
        let session = try makeSession()
        let access = ProAccess(defaults: freshDefaults())
        try await buy(ProAccess.ProductID.weekly, with: access)
        #expect(access.isSubscribed)
        // The user cancels (auto-renew off), then the period runs out.
        let latest = try #require(await Transaction.latest(for: ProAccess.ProductID.weekly))
        guard case let .verified(transaction) = latest else { Issue.record("Unverified transaction"); return }
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        try session.expireSubscription(productIdentifier: ProAccess.ProductID.weekly)
        await waitUntilLocked(access)
        #expect(!access.isSubscribed)
    }

    @Test("A refunded purchase takes full access away")
    func refundLocks() async throws {
        let session = try makeSession()
        let access = ProAccess(defaults: freshDefaults())
        try await buy(ProAccess.ProductID.monthly, with: access)
        #expect(access.isSubscribed)
        let latest = try #require(await Transaction.latest(for: ProAccess.ProductID.monthly))
        guard case let .verified(transaction) = latest else { Issue.record("Unverified transaction"); return }
        try session.refundTransaction(identifier: UInt(transaction.id))
        await waitUntilLocked(access)
        #expect(!access.isSubscribed)
    }
}

/// Streaks and rewards survive a reinstall and reach the user's other devices through their iCloud.
@MainActor
@Suite("Engagement sync", .serialized)
struct EngagementSyncTests {
    private func container() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: AppPersistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: AppPersistence.schema, configurations: configuration)
    }

    @Test("A reinstall (empty phone, same iCloud) gets its streak days, freezes, outfits and points back")
    func reinstallRestores() throws {
        let shared = try container()
        let day = DayStamp(year: 2026, month: 11, day: 20)

        // The phone before the reinstall.
        let before = freshDefaults()
        let oldStore = EngagementStore(defaults: before)
        oldStore.setDone(true, on: day)
        oldStore.weekendOff = true
        var rewards = RewardLedger.empty
        rewards.points = 90
        rewards.unlocked = [.partyHat]
        rewards.worn = .partyHat
        let oldSync = EngagementSync(defaults: before)
        oldSync.sync(local: oldSync.local(rewards: rewards, bestRoutineStreak: 8), context: ModelContext(shared))

        // After the reinstall: nothing on the phone.
        let after = freshDefaults()
        let newSync = EngagementSync(defaults: after)
        let fresh = newSync.local(rewards: .empty, bestRoutineStreak: 0)
        let merged = try #require(newSync.sync(local: fresh, context: ModelContext(shared)))
        newSync.applyStreaks(merged)
        let restored = EngagementStore(defaults: after)
        #expect(restored.doneDays == [day])
        #expect(restored.weekendOff)
        #expect(merged.rewards.points == 90)
        #expect(merged.rewards.worn == .partyHat)
        #expect(merged.bestRoutineStreak == 8)

        // Syncing again with nothing new changes nothing, and only one synced copy is kept.
        let again = newSync.local(rewards: merged.rewards, bestRoutineStreak: merged.bestRoutineStreak)
        #expect(newSync.sync(local: again, context: ModelContext(shared)) == nil)
        #expect(try ModelContext(shared).fetchCount(FetchDescriptor<EngagementRecord>()) == 1)
    }

    @Test("A change on this device is newer than the synced copy, so its settings win")
    func localChangeWins() throws {
        let shared = try container()
        let defaults = freshDefaults()
        let sync = EngagementSync(defaults: defaults)
        sync.sync(local: sync.local(rewards: .empty, bestRoutineStreak: 0), context: ModelContext(shared))
        EngagementStore(defaults: defaults).weekendOff = true
        let changed = sync.local(rewards: .empty, bestRoutineStreak: 0)
        #expect(changed.updatedAt > .distantPast)
        sync.sync(local: changed, context: ModelContext(shared))
        let other = EngagementSync(defaults: freshDefaults())
        let merged = try #require(other.sync(local: other.local(rewards: .empty, bestRoutineStreak: 0), context: ModelContext(shared)))
        #expect(merged.weekendOff)
    }

    @Test("When the merged copy can't be applied here, syncing again leaves the record alone (no endless re-sync)")
    func unappliedMergeDoesNotLoop() throws {
        let shared = try container()
        let otherPhone = freshDefaults()
        EngagementStore(defaults: otherPhone).setDone(true, on: DayStamp(year: 2026, month: 11, day: 1))
        let other = EngagementSync(defaults: otherPhone)
        other.sync(local: other.local(rewards: .empty, bestRoutineStreak: 0), context: ModelContext(shared))

        // This phone never applies what it gets back (as when launch arguments pin its stored values).
        let sync = EngagementSync(defaults: freshDefaults())
        let local = sync.local(rewards: .empty, bestRoutineStreak: 0, challenges: ChallengeBook(active: nil, finished: []))
        sync.sync(local: local, context: ModelContext(shared))
        let stamp = try #require(try ModelContext(shared).fetch(FetchDescriptor<EngagementRecord>()).first?.updatedAt)
        for _ in 0..<3 {
            sync.sync(local: sync.local(rewards: .empty, bestRoutineStreak: 0), context: ModelContext(shared))
        }
        #expect(try ModelContext(shared).fetch(FetchDescriptor<EngagementRecord>()).first?.updatedAt == stamp)
    }

    @Test("A running challenge comes back after a reinstall")
    func challengesRestore() throws {
        let shared = try container()
        let start = DayStamp(year: 2026, month: 11, day: 10)
        let book = ChallengeEngine.recording(.sunscreen, done: true,
                                             in: ChallengeEngine.starting(.sunscreen, in: .empty, today: start), today: start)
        let before = EngagementSync(defaults: freshDefaults())
        before.sync(local: before.local(rewards: .empty, bestRoutineStreak: 0, challenges: book), context: ModelContext(shared))
        let after = EngagementSync(defaults: freshDefaults())
        let merged = try #require(after.sync(local: after.local(rewards: .empty, bestRoutineStreak: 0), context: ModelContext(shared)))
        #expect(merged.challenges.active?.progress == 1)
    }
}

/// The lessons shipped in the app are complete and well formed.
@MainActor
@Suite("Skin School lessons")
struct SkinSchoolContentTests {
    private let course = SchoolModel.loadBundledCourse()

    @Test("The lesson file loads with at least ten lessons in two or more units")
    func loads() {
        #expect(course.units.count >= 2)
        #expect(course.units.flatMap(\.lessons).count >= 10)
    }

    @Test("Every lesson has 3–5 cards, two answerable questions, English and Indonesian, and https sources")
    func wellFormed() {
        let problems = course.units.flatMap(\.lessons).flatMap(SkinSchoolEngine.problems(in:))
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test("Lesson ids are unique")
    func uniqueIDs() {
        let ids = course.units.flatMap(\.lessons).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Release builds show only signed-off lessons (none are signed off yet)")
    func draftsStayHidden() {
        let released = SkinSchoolEngine.visibleLessons(in: course, includeDrafts: false)
        #expect(released.allSatisfy { $0.reviewed })
    }
}

/// The app and the share extension name the same plans.
@Suite("Shared access")
struct SharedAccessTests {
    @Test("The app's plans and the extension's plans are the same set")
    @MainActor
    func sameProducts() {
        #expect(Set(ProAccess.ProductID.all) == SharedAccess.proProductIDs)
    }

    @Test("Checks recorded before the App Group move are kept, once")
    func movesIntoAppGroup() {
        let old = UserDefaults(suiteName: "old-\(UUID().uuidString)")!
        let new = UserDefaults(suiteName: "new-\(UUID().uuidString)")!
        ProductCheckLedger(defaults: old).record("a")
        ProductCheckLedger(defaults: new).record("b")
        ProductCheckLedger.moveIntoAppGroup(from: old, to: new)
        let ledger = ProductCheckLedger(defaults: new)
        let free = AccessPolicy(hasFullAccess: false)
        #expect(ledger.canCheck("c", policy: free))
        ledger.record("c")
        #expect(!ledger.canCheck("d", policy: free)) // a, b and c this month
        #expect(old.dictionary(forKey: "productCheckLedger") == nil)
    }
}

/// Existing users keep everything.
@MainActor
@Suite("Existing users", .serialized)
struct ExistingUserTests {
    private func container(scans: Int) throws -> ModelContainer {
        // Same as the app's schema, in memory and with iCloud off (as LegacyMigrationRunnerTests does).
        let configuration = ModelConfiguration(schema: AppPersistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: AppPersistence.schema, configurations: configuration)
        let context = ModelContext(container)
        for _ in 0..<scans { context.insert(ScanSession()) }
        try context.save()
        return container
    }

    @Test("A phone that already holds scans when the paywall build first runs keeps everything, for good")
    func scansMeanExistingUser() async throws {
        let defaults = freshDefaults()
        let access = ProAccess(defaults: defaults)
        await access.start(container: try container(scans: 2))
        #expect(access.isLegacy)
        #expect(access.policy.hasFullAccess)
        // Later launches remember it, even after the scans are gone.
        let later = ProAccess(defaults: defaults)
        await later.start(container: try container(scans: 0))
        #expect(later.policy.hasFullAccess)
    }

    @Test("A new install with no scans is a free account")
    func emptyPhoneIsNew() async throws {
        let access = ProAccess(defaults: freshDefaults())
        await access.start(container: try container(scans: 0))
        #expect(!access.isLegacy)
        #expect(!access.policy.hasFullAccess)
    }

    @Test("Scans that come in after the first paywall launch do not make someone an existing user")
    func onlyTheFirstLaunchCounts() async throws {
        let defaults = freshDefaults()
        await ProAccess(defaults: defaults).start(container: try container(scans: 0))
        let later = ProAccess(defaults: defaults)
        await later.start(container: try container(scans: 3))
        #expect(!later.isLegacy)
    }

    @Test("Demo data seeded for testing does not count as an existing user")
    func demoDataIsNotHistory() async throws {
        let access = ProAccess(defaults: freshDefaults())
        await access.start(container: try container(scans: 6), seedsDemoData: true)
        #expect(!access.isLegacy)
    }
}
