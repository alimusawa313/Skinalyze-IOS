import Foundation
import Testing
@testable import SkinalyzeKit

/// The one place that answers "is this allowed?" — free limits, what Pro unlocks, and existing users.
@Suite("Access policy")
struct AccessPolicyTests {
    private let free = AccessPolicy(hasFullAccess: false)
    private let full = AccessPolicy(hasFullAccess: true)

    private func calendar(_ zone: String = "Asia/Jakarta") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Scan limit (M8)

    @Test("The first scan of the day is always free")
    func firstScanOfTheDayIsFree() {
        let cal = calendar()
        let now = date(2026, 11, 19, 9, in: cal)
        #expect(free.scanAllowance(savedScanDates: [], now: now, calendar: cal) == .allowed)
        let yesterday = date(2026, 11, 18, 23, 59, in: cal)
        #expect(free.scanAllowance(savedScanDates: [yesterday], now: now, calendar: cal) == .allowed)
    }

    @Test("After one saved scan today, the next free scan is at local midnight")
    func secondScanWaitsUntilMidnight() {
        let cal = calendar()
        let now = date(2026, 11, 19, 21, in: cal)
        let earlier = date(2026, 11, 19, 7, in: cal)
        let allowance = free.scanAllowance(savedScanDates: [earlier], now: now, calendar: cal)
        #expect(allowance == .limitReached(nextFreeScan: date(2026, 11, 20, 0, in: cal)))
    }

    @Test("The day is the user's local day, not UTC")
    func usesTheLocalDay() {
        let jakarta = calendar("Asia/Jakarta")
        // 00:30 in Jakarta on the 20th is still the 19th in UTC; a scan at 23:30 Jakarta on the 19th is a different local day.
        let now = date(2026, 11, 20, 0, 30, in: jakarta)
        let lastNight = date(2026, 11, 19, 23, 30, in: jakarta)
        #expect(free.scanAllowance(savedScanDates: [lastNight], now: now, calendar: jakarta) == .allowed)
    }

    @Test("A clock-change day still resets at the next local midnight")
    func handlesDaylightSaving() {
        let newYork = calendar("America/New_York")
        // 8 March 2026 is 23 hours long in New York.
        let now = date(2026, 3, 8, 12, in: newYork)
        let earlier = date(2026, 3, 8, 1, in: newYork)
        let allowance = free.scanAllowance(savedScanDates: [earlier], now: now, calendar: newYork)
        #expect(allowance == .limitReached(nextFreeScan: date(2026, 3, 9, 0, in: newYork)))
    }

    @Test("A scan dated on a later day (the clock was set back) never blocks today")
    func futureDatedScansDoNotBlock() {
        let cal = calendar()
        let now = date(2026, 11, 19, 9, in: cal)
        let tomorrow = date(2026, 11, 20, 9, in: cal)
        #expect(free.scanAllowance(savedScanDates: [tomorrow], now: now, calendar: cal) == .allowed)
    }

    @Test("Full access has no scan limit")
    func fullAccessScansFreely() {
        let cal = calendar()
        let now = date(2026, 11, 19, 21, in: cal)
        let scans = [date(2026, 11, 19, 7, in: cal), date(2026, 11, 19, 8, in: cal)]
        #expect(full.scanAllowance(savedScanDates: scans, now: now, calendar: cal) == .allowed)
    }

    @Test("The limit is one saved scan a day")
    func limitConstant() {
        #expect(FreeLimits.savedScansPerDay == 1)
    }

    // MARK: History

    @Test("Free history is the newest seven scans; full access opens all")
    func historyLimit() {
        #expect(FreeLimits.historyScans == 7)
        #expect(free.canOpenScan(atPosition: 0))
        #expect(free.canOpenScan(atPosition: 6))
        #expect(!free.canOpenScan(atPosition: 7))
        #expect(full.canOpenScan(atPosition: 500))
    }

    // MARK: Product checks

    @Test("Free users check three different products a month; re-opening one already checked is free")
    func productChecks() {
        let cal = calendar()
        let now = date(2026, 11, 19, 9, in: cal)
        let thisMonth = (1...3).map { date(2026, 11, $0, 10, in: cal) }
        let lastMonth = date(2026, 10, 30, 10, in: cal)
        #expect(free.canCheckProduct(checkDates: Array(thisMonth.prefix(2)) + [lastMonth], alreadyChecked: false, now: now, calendar: cal))
        #expect(!free.canCheckProduct(checkDates: thisMonth, alreadyChecked: false, now: now, calendar: cal))
        #expect(free.canCheckProduct(checkDates: thisMonth, alreadyChecked: true, now: now, calendar: cal))
        #expect(full.canCheckProduct(checkDates: thisMonth, alreadyChecked: false, now: now, calendar: cal))
    }

    // MARK: Pro features

    @Test("Pro features are locked for free and open with full access", arguments: ProFeature.allCases)
    func proFeatures(feature: ProFeature) {
        #expect(!free.allows(feature))
        #expect(full.allows(feature))
    }

    // MARK: Existing users keep everything

    @Test("Someone who got the app before the paywall launched keeps everything")
    func legacyByPurchaseDate() {
        let cal = calendar()
        let launch = date(2026, 12, 1, 0, in: cal)
        #expect(LegacyAccess.isLegacy(originalPurchase: date(2026, 6, 1, 0, in: cal), paywallLaunch: launch, hadScansBeforePaywall: false))
        #expect(!LegacyAccess.isLegacy(originalPurchase: date(2026, 12, 2, 0, in: cal), paywallLaunch: launch, hadScansBeforePaywall: false))
    }

    @Test("Someone whose phone already held scans when the paywall arrived keeps everything")
    func legacyByExistingScans() {
        #expect(LegacyAccess.isLegacy(originalPurchase: nil, paywallLaunch: nil, hadScansBeforePaywall: true))
    }

    @Test("With nothing known, a new install is not treated as an existing user")
    func unknownIsNotLegacy() {
        #expect(!LegacyAccess.isLegacy(originalPurchase: nil, paywallLaunch: nil, hadScansBeforePaywall: false))
        #expect(!LegacyAccess.isLegacy(originalPurchase: Date(), paywallLaunch: nil, hadScansBeforePaywall: false))
    }
}
