import Foundation
import Observation
import SwiftData

/// App-wide navigation state. Scans are a modal flow (never pushed on a tab stack) so folding, unfolding or rotating
/// the device can't pop them (PLAN.md §8.2).
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
    var isScanning = false
    var presentedScan: PresentedScan?
    var isShowingProfile = false

    func startScan() {
        isScanning = true
    }

    func scanFinished(_ id: PersistentIdentifier?) {
        isScanning = false
        presentedScan = id.map(PresentedScan.init(id:))
    }

    /// Handles `skinalyze://scan`, `skinalyze://timeline`, `skinalyze://products`, `skinalyze://search`.
    func open(_ url: URL) {
        guard url.scheme == "skinalyze" else { return }
        switch url.host() {
        case "scan": startScan()
        case "timeline": selectedTab = .timeline
        case "products": selectedTab = .products
        case "search": selectedTab = .search
        default: selectedTab = .today
        }
    }
}
