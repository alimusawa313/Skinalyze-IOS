import Foundation

/// The journey map (E11): stops along a path, reached with glow points from quests plus Skin School XP. Effort only —
/// nothing about skin moves you along, and nothing ever moves you back.
public enum Journey {
    /// Total XP needed to reach each stop (stop 1 is the start).
    public static let thresholds = [0, 50, 150, 300, 500, 800, 1200, 1700, 2300, 3000, 4000, 5200]

    public static var stops: Int { thresholds.count }

    public struct Position: Sendable, Equatable {
        /// 1-based stop reached.
        public let stop: Int
        public let xp: Int
        /// XP still needed for the next stop; nil at the last stop.
        public let toNext: Int?
        /// Share of the way from this stop to the next, 0…1 (1 at the last stop).
        public let progress: Double
    }

    public static func xp(points: Int, schoolXP: Int) -> Int { max(0, points) + max(0, schoolXP) }

    public static func position(xp: Int) -> Position {
        let xp = max(0, xp)
        let reached = thresholds.lastIndex { $0 <= xp } ?? 0
        guard reached + 1 < thresholds.count else {
            return Position(stop: thresholds.count, xp: xp, toNext: nil, progress: 1)
        }
        let floor = thresholds[reached], next = thresholds[reached + 1]
        return Position(stop: reached + 1, xp: xp, toNext: next - xp, progress: Double(xp - floor) / Double(next - floor))
    }
}
