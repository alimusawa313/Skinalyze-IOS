import SkinalyzeKit
import Foundation
import Observation
import SwiftData

/// App-wide navigation state. Scans run in place on the Mirror (never pushed on a stack) so folding, unfolding or
/// rotating the device can't pop them (PLAN.md §8.2).
@Observable
@MainActor
final class AppModel {
    enum Tab: Hashable {
        case today
        case timeline
        case products
        case search
    }

    /// A finished scan to present. Wraps the persistent ID so it can drive `.sheet(item:)`.
    struct PresentedScan: Identifiable, Hashable {
        let id: PersistentIdentifier
    }

    var selectedTab: Tab = .today
    /// Set by deep links / intents; the Mirror starts an in-place scan and clears it.
    var pendingScan = false
    /// Mirrors the in-place scan so the shell can hide the dock while capturing.
    var isScanning = false
    var presentedScan: PresentedScan?
    var isShowingProfile = false
    /// Set by an invite link (`skinalyze://friend/<code>`).
    var pendingInvite: FriendCode?
    /// Set by a shelf link (`skinalyze://shelf?p=1,2,3`).
    var sharedShelf: SharedShelf?
    /// Set by `skinalyze://wrapped` (the Wrapped in-app event): the Wrapped to open.
    var pendingRecap: RecapPeriod?
    /// Set by `skinalyze://challenge/<kind>` (the challenge in-app event): the challenge to offer.
    var pendingChallenge: ChallengeInvite?

    struct ChallengeInvite: Identifiable, Hashable {
        let kind: ChallengeKind
        var id: ChallengeKind { kind }
    }

    func startScan() {
        selectedTab = .today
        pendingScan = true
    }

    func scanFinished(_ id: PersistentIdentifier?) {
        isScanning = false
        pendingScan = false
        if id != nil { FirstScanCoaching.scanSaved() }
        presentedScan = id.map(PresentedScan.init(id:))
    }

    /// Handles `skinalyze://scan`, `skinalyze://timeline`, `skinalyze://products`, `skinalyze://search`,
    /// `skinalyze://friend/<code>` (invites; an invalid code is ignored), and the in-app event links
    /// `skinalyze://wrapped` and `skinalyze://challenge/<kind>` (an unknown kind goes to Today).
    func open(_ url: URL, now: Date = .now, calendar: Calendar = .current) {
        guard url.scheme == "skinalyze" else { return }
        switch url.host() {
        case "scan": startScan()
        case "timeline": selectedTab = .timeline
        case "products": selectedTab = .products
        case "search": selectedTab = .search
        case "shelf":
            let ids = RoutineLink.productIDs(from: url)
            if !ids.isEmpty { sharedShelf = SharedShelf(productIDs: ids) }
        case "friend": pendingInvite = url.pathComponents.dropFirst().first.flatMap { FriendCode($0) }
        case "wrapped":
            // Last year's Wrapped in its first week of January, otherwise the last finished quarter.
            pendingRecap = RecapEngine.dueWrapped(now: now, calendar: calendar)
                ?? RecapEngine.latestWrapped(now: now, calendar: calendar)
        case "challenge":
            if let kind = url.pathComponents.dropFirst().first.flatMap(ChallengeKind.init(rawValue:)) {
                pendingChallenge = ChallengeInvite(kind: kind)
            } else {
                selectedTab = .today
            }
        default: selectedTab = .today
        }
    }
}
