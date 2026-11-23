import Foundation

/// What a free account gets. Tunable in one place.
public enum FreeLimits {
    /// Only a scan that was analysed and saved counts; cancelled, retaken or failed scans do not exist as saved scans.
    public static let savedScansPerDay = 1
    /// The newest scans a free account can open.
    public static let historyScans = 7
    /// Different products a free account can check in a calendar month.
    public static let productChecksPerMonth = 3
    /// Skin School units open to everyone; the rest come with Pro.
    public static let freeSchoolUnits = 1
}

/// Things only full access unlocks (beyond the limits above).
public enum ProFeature: String, CaseIterable, Sendable {
    /// Turning the 3D head.
    case turn3D
    /// The 3D turntable video.
    case turntableExport
    /// Exports without the Skinalyze mark.
    case noWatermark
    /// Skin School beyond the free units.
    case allSkinSchool
    /// "This area over time" from a tapped spot.
    case areaHistory
    /// The zone map on the head over time.
    case zoneMap
    /// Products with a similar formula (P9).
    case dupes
    /// The dermatologist visit PDF (P11).
    case dermPack
    /// Sleep and cycle from Apple Health next to scans (P4).
    case healthPatterns
}

/// The one place that answers "is this allowed?". Full access means a Pro subscription or an existing user from
/// before the paywall — the rest of the app never asks which.
public struct AccessPolicy: Sendable, Equatable {
    public let hasFullAccess: Bool

    public init(hasFullAccess: Bool) {
        self.hasFullAccess = hasFullAccess
    }

    public enum ScanAllowance: Sendable, Equatable {
        case allowed
        /// Today's free scan is used; the next one opens at this moment (local midnight).
        case limitReached(nextFreeScan: Date)
    }

    /// Whether a new scan may start now, given when the saved scans were taken.
    public func scanAllowance(savedScanDates: [Date], now: Date, calendar: Calendar) -> ScanAllowance {
        guard !hasFullAccess else { return .allowed }
        let today = savedScanDates.filter { calendar.isDate($0, inSameDayAs: now) }
        guard today.count >= FreeLimits.savedScansPerDay else { return .allowed }
        let startOfToday = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
        return .limitReached(nextFreeScan: tomorrow)
    }

    /// Position 0 is the newest scan.
    public func canOpenScan(atPosition newestFirst: Int) -> Bool {
        hasFullAccess || newestFirst < FreeLimits.historyScans
    }

    /// `checkDates` holds when each different product was first checked. A product already checked stays open.
    public func canCheckProduct(checkDates: [Date], alreadyChecked: Bool, now: Date, calendar: Calendar) -> Bool {
        if hasFullAccess || alreadyChecked { return true }
        let thisMonth = checkDates.filter { calendar.isDate($0, equalTo: now, toGranularity: .month) }
        return thisMonth.count < FreeLimits.productChecksPerMonth
    }

    public func allows(_ feature: ProFeature) -> Bool {
        hasFullAccess
    }
}

/// Existing users keep everything (owner decision, 2026-11-19). Someone counts as existing when they first got the
/// app before the paywall launched, or when their phone already held scans the first time a paywall build ran.
public enum LegacyAccess {
    public static func isLegacy(originalPurchase: Date?, paywallLaunch: Date?, hadScansBeforePaywall: Bool) -> Bool {
        if hadScansBeforePaywall { return true }
        guard let originalPurchase, let paywallLaunch else { return false }
        return originalPurchase < paywallLaunch
    }
}
