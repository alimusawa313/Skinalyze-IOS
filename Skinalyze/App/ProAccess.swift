import StoreKit
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Who has full access: Pro subscribers and everyone who used the app before the paywall. Screens read `policy`
/// and never ask why. Prices and plans come from the App Store; nothing about them is written in the app.
@Observable
@MainActor
final class ProAccess {
    enum ProductID {
        static let weekly = "com.Patani.Skinalyze.pro.weekly"
        static let monthly = "com.Patani.Skinalyze.pro.monthly"
        static let annual = "com.Patani.Skinalyze.pro.annual"
        /// In the order the paywall lists them.
        static let all = [annual, monthly, weekly]
    }

    enum LoadState: Equatable {
        case idle, loading, loaded, unavailable
    }

    enum PurchaseOutcome: Equatable {
        case success, cancelled, pending, failed
    }

    /// The day the first build with a paywall goes live on the App Store. Anyone who first got the app before this
    /// keeps everything, even after reinstalling. **Set this when shipping**; while it is nil, only people whose
    /// phone already held scans are recognised as existing users.
    static let paywallLaunch: Date? = nil

    private enum Key {
        static let legacyResolved = "legacyAccessResolved"
        static let legacy = "legacyAccess"
        static let debugOverride = "proOverride"
    }

    /// DEBUG only: forces free (`false`) or full (`true`) access — `-proOverride free|pro`, or the Profile switch.
    private(set) var debugOverride: Bool?
    private(set) var products: [Product] = []
    private(set) var loadState = LoadState.idle
    private(set) var isSubscribed = false
    private(set) var isLegacy: Bool

    private let defaults: UserDefaults
    private var updates: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLegacy = defaults.bool(forKey: Key.legacy)
        #if DEBUG
        switch defaults.string(forKey: Key.debugOverride) {
        case "pro": debugOverride = true
        case "free": debugOverride = false
        default: debugOverride = nil
        }
        #endif
    }

    var policy: AccessPolicy {
        AccessPolicy(hasFullAccess: debugOverride ?? (isSubscribed || isLegacy))
    }

    #if DEBUG
    func setDebugOverride(_ value: Bool?) {
        debugOverride = value
        defaults.set(value.map { $0 ? "pro" : "free" }, forKey: Key.debugOverride)
    }
    #endif

    /// Call once at launch, after any data migration (so existing scans are already in the store).
    func start(container: ModelContainer, seedsDemoData: Bool = false) async {
        resolveLegacyFromScans(container: container, seedsDemoData: seedsDemoData)
        if updates == nil {
            updates = Task { [weak self] in
                for await update in Transaction.updates {
                    if case let .verified(transaction) = update { await transaction.finish() }
                    await self?.refreshEntitlement()
                }
            }
        }
        await refreshEntitlement()
        await loadProducts()
        await resolveLegacyFromPurchaseDate()
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let found = try await Product.products(for: ProductID.all)
            products = ProductID.all.compactMap { id in found.first { $0.id == id } }
            loadState = products.isEmpty ? .unavailable : .loaded
        } catch {
            loadState = .unavailable
        }
    }

    /// Active means: a verified, unrevoked transaction for one of our plans is among the current entitlements
    /// (StoreKit drops expired and refunded ones from that list).
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            switch try await product.purchase() {
            case let .success(verification):
                guard case let .verified(transaction) = verification else { return .failed }
                await transaction.finish()
                await refreshEntitlement()
                return .success
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Returns whether anything was restored.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlement()
        await resolveLegacyFromPurchaseDate()
        return policy.hasFullAccess
    }

    // MARK: Existing users keep everything

    /// The first time a paywall build runs: a phone that already holds scans belongs to an existing user.
    private func resolveLegacyFromScans(container: ModelContainer, seedsDemoData: Bool) {
        guard !defaults.bool(forKey: Key.legacyResolved) else { return }
        let count = (try? ModelContext(container).fetchCount(FetchDescriptor<ScanSession>())) ?? 0
        let hadScans = count > 0 && !seedsDemoData
        defaults.set(true, forKey: Key.legacyResolved)
        if LegacyAccess.isLegacy(originalPurchase: nil, paywallLaunch: nil, hadScansBeforePaywall: hadScans) { markLegacy() }
    }

    /// Covers reinstalls and new phones: the App Store knows when this person first got the app.
    private func resolveLegacyFromPurchaseDate() async {
        guard !isLegacy, let launch = Self.paywallLaunch,
              case let .verified(app)? = try? await AppTransaction.shared else { return }
        if LegacyAccess.isLegacy(originalPurchase: app.originalPurchaseDate, paywallLaunch: launch, hadScansBeforePaywall: false) {
            markLegacy()
        }
    }

    private func markLegacy() {
        isLegacy = true
        defaults.set(true, forKey: Key.legacy)
    }
}

/// Which products a free account has checked, and when, so re-opening a checked product never counts twice.
struct ProductCheckLedger {
    private static let key = "productCheckLedger"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var entries: [String: Double] {
        (defaults.dictionary(forKey: Self.key) as? [String: Double]) ?? [:]
    }

    /// Whether this product may be checked now; one checked earlier this month stays open.
    func canCheck(_ productKey: String, policy: AccessPolicy, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let checkedThisMonth = entries[productKey].map {
            calendar.isDate(Date(timeIntervalSince1970: $0), equalTo: now, toGranularity: .month)
        } ?? false
        return policy.canCheckProduct(checkDates: entries.values.map(Date.init(timeIntervalSince1970:)),
                                      alreadyChecked: checkedThisMonth, now: now, calendar: calendar)
    }

    func record(_ productKey: String, now: Date = .now, calendar: Calendar = .current) {
        var updated = entries
        if let earlier = updated[productKey],
           calendar.isDate(Date(timeIntervalSince1970: earlier), equalTo: now, toGranularity: .month) { return }
        updated[productKey] = now.timeIntervalSince1970
        defaults.set(updated, forKey: Self.key)
    }
}
