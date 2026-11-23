import Foundation
import StoreKit
import SkinalyzeKit

/// Access shared by the app and the share extension through the App Group: who has full access, and which products
/// a free account has checked this month (so both count toward the same limit).
enum SharedAccess {
    static let proProductIDs: Set<String> = [
        "com.Patani.Skinalyze.pro.annual", "com.Patani.Skinalyze.pro.monthly", "com.Patani.Skinalyze.pro.weekly",
    ]
    private static let legacyKey = "sharedLegacyAccess"

    static var groupDefaults: UserDefaults { UserDefaults(suiteName: SharedContext.appGroup) ?? .standard }

    /// Written by the app: this person was here before the paywall and keeps everything.
    static var isLegacy: Bool {
        get { groupDefaults.bool(forKey: legacyKey) }
        set { groupDefaults.set(newValue, forKey: legacyKey) }
    }

    /// Existing user, or an active Pro subscription (StoreKit works in extensions too).
    static func hasFullAccess() async -> Bool {
        if isLegacy { return true }
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, proProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil { return true }
        }
        return false
    }
}

/// Which products a free account has checked, and when, so re-opening a checked product never counts twice.
/// Kept in the App Group: product checks from the share extension use the same monthly allowance.
struct ProductCheckLedger {
    private static let key = "productCheckLedger"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedAccess.groupDefaults) {
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

    /// Returns whether this was a new check this month.
    @discardableResult
    func record(_ productKey: String, now: Date = .now, calendar: Calendar = .current) -> Bool {
        var updated = entries
        if let earlier = updated[productKey],
           calendar.isDate(Date(timeIntervalSince1970: earlier), equalTo: now, toGranularity: .month) { return false }
        updated[productKey] = now.timeIntervalSince1970
        defaults.set(updated, forKey: Self.key)
        return true
    }

    /// Moves checks recorded before the ledger lived in the App Group (one time, keeps the latest date per product).
    static func moveIntoAppGroup(from old: UserDefaults = .standard, to new: UserDefaults = SharedAccess.groupDefaults) {
        guard old !== new, let earlier = old.dictionary(forKey: key) as? [String: Double], !earlier.isEmpty else { return }
        let current = (new.dictionary(forKey: key) as? [String: Double]) ?? [:]
        new.set(current.merging(earlier) { max($0, $1) }, forKey: key)
        old.removeObject(forKey: key)
    }
}
