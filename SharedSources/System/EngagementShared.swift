import Foundation
import WidgetKit
import SkinalyzeKit

/// The engagement snapshot in the App Group, so widgets can work out streaks and Pimpi's mood on their own.
enum EngagementShared {
    static let key = "engagementSnapshot"

    static func load() -> EngagementSnapshot {
        guard let data = WidgetSummary.defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(EngagementSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    /// Stores the snapshot and refreshes widgets when it changed.
    static func publish(_ snapshot: EngagementSnapshot) {
        guard snapshot != load(), let data = try? JSONEncoder().encode(snapshot) else { return }
        WidgetSummary.defaults?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
