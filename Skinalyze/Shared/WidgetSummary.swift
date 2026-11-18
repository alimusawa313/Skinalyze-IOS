import Foundation
import SwiftData
import WidgetKit
import SkinalyzeKit

/// A tiny snapshot shared with widgets via the App Group (widgets never open the SwiftData store).
struct WidgetSnapshot: Codable, Equatable {
    var lastScanDate: Date?
    var breakoutIndex: Int?
    var bandRaw: String?
    var delta: Int?
    var trend: [Int]

    static let empty = WidgetSnapshot(lastScanDate: nil, breakoutIndex: nil, bandRaw: nil, delta: nil, trend: [])
}

enum WidgetSummary {
    static let appGroup = "group.com.Patani.Skinalyze"
    static let key = "widgetSnapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    @MainActor
    static func refresh(from container: ModelContainer) async {
        var descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 8
        guard let scans = try? container.mainContext.fetch(descriptor) else { return }
        let latest = scans.first
        let snapshot = WidgetSnapshot(
            lastScanDate: latest?.createdAt,
            breakoutIndex: latest?.breakoutIndex,
            bandRaw: latest?.band.rawValue,
            delta: scans.count >= 2 ? scans[0].breakoutIndex - scans[1].breakoutIndex : nil,
            trend: scans.reversed().map(\.breakoutIndex)
        )
        guard snapshot != load(), let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
