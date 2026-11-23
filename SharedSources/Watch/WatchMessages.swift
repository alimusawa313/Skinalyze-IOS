import Foundation

// P14: what the phone and the Apple Watch send each other. Compiled into both (the watch app doesn't use
// SkinalyzeKit), so it depends on Foundation only. Days are "yyyy-MM-dd" in the phone's calendar.

/// What the phone tells the watch: today's routine steps for both parts, and the streak.
struct WatchRoutineState: Codable, Equatable, Sendable {
    struct Step: Codable, Equatable, Sendable, Identifiable {
        /// The routine log's key without the date: "morning.Cleanser" or "evening.<extra step id>".
        let id: String
        let title: String
        let done: Bool
    }

    let day: String
    let morning: [Step]
    let evening: [Step]
    let streak: Int

    static let contextKey = "routineState"
}

/// A tick or untick from the watch.
struct WatchCheckOff: Codable, Equatable, Sendable {
    let day: String
    let stepID: String
    let done: Bool

    static let messageKey = "checkOff"

    /// Ignored when meant for another day (ticked before midnight, delivered after) or not a "part.step" id.
    func applies(today: String) -> Bool {
        let parts = stepID.split(separator: ".", maxSplits: 1)
        return day == today && parts.count == 2 && ["morning", "evening"].contains(String(parts[0]))
    }
}
