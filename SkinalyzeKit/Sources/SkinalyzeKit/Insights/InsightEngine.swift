import Foundation

/// Deterministic insight rules (PLAN.md §11.3). Confidence language scales with data; no trend claims below 3 scans.
public enum InsightEngine {
    public struct Point: Sendable, Hashable {
        public let date: Date
        public let index: Int
        public let zoneIndices: [FaceZone: Int]

        public init(date: Date, index: Int, zoneIndices: [FaceZone: Int]) {
            self.date = date
            self.index = index
            self.zoneIndices = zoneIndices
        }
    }

    public static let minimumScans = 3
    static let gapDays = 7
    static let streakLength = 3

    /// One headline for Today. `points` may be in any order.
    public static func headline(for points: [Point], now: Date = .now) -> String {
        let sorted = points.sorted { $0.date > $1.date } // newest first
        guard let latest = sorted.first else {
            return String(localized: "Your first scan sets your baseline.")
        }
        guard sorted.count >= minimumScans else {
            let remaining = minimumScans - sorted.count
            return remaining == 1
                ? String(localized: "Scan 1 more time to unlock trends.")
                : String(localized: "Scan \(remaining) more times to unlock trends.")
        }
        let days = Calendar.current.dateComponents([.day], from: latest.date, to: now).day ?? 0
        if days >= gapDays {
            return String(localized: "It's been \(days) days since your last scan — a quick check keeps the trend honest.")
        }
        if let zone = risingZone(sorted) {
            return String(localized: "Your \(zone.displayName.lowercased()) has been more active three scans in a row.")
        }
        let recent = sorted.dropFirst().prefix(3).map(\.index).sorted()
        let baseline = recent[recent.count / 2]
        if latest.index < baseline {
            let best = sorted.dropFirst().allSatisfy { latest.index <= $0.index }
            return best
                ? String(localized: "Your calmest scan yet — whatever you're doing, it's showing.")
                : String(localized: "Skin looks calmer than your recent scans.")
        }
        if latest.index > baseline {
            return String(localized: "A little more active than usual. One scan isn't a trend — check again in a few days.")
        }
        return String(localized: "Holding steady compared with your recent scans.")
    }

    /// A zone whose index rose across the latest `streakLength` scans.
    static func risingZone(_ newestFirst: [Point]) -> FaceZone? {
        let window = Array(newestFirst.prefix(streakLength).reversed()) // oldest → newest
        guard window.count == streakLength else { return nil }
        return FaceZone.allCases.first { zone in
            let values = window.map { $0.zoneIndices[zone] ?? 0 }
            return zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
        }
    }
}

public extension FaceZone {
    var displayName: String {
        switch self {
        case .forehead: String(localized: "Forehead")
        case .nose: String(localized: "Nose")
        case .leftCheek: String(localized: "Left cheek")
        case .rightCheek: String(localized: "Right cheek")
        case .chin: String(localized: "Chin")
        case .leftJaw: String(localized: "Left jaw")
        case .rightJaw: String(localized: "Right jaw")
        }
    }
}

public extension InsightEngine.Point {
    init(_ session: ScanSession) {
        self.init(
            date: session.createdAt,
            index: session.breakoutIndex,
            zoneIndices: Dictionary(uniqueKeysWithValues: FaceZone.allCases.map { ($0, session.zoneIndex($0)) })
        )
    }
}

/// "Did this product help?" — a correlation with honest caveats, never a claim of cause (PLAN.md §11.4).
public struct ProductEffect: Sendable, Hashable {
    public let percentChange: Int
    public let scansBefore: Int
    public let scansAfter: Int

    static let minimumBefore = 2
    static let minimumAfter = 3
    static let minimumDays = 14

    public static func evaluate(points: [InsightEngine.Point], startedAt: Date, now: Date = .now) -> ProductEffect? {
        let days = Calendar.current.dateComponents([.day], from: startedAt, to: now).day ?? 0
        let before = points.filter { $0.date < startedAt }.map(\.index)
        let after = points.filter { $0.date >= startedAt }.map(\.index)
        guard days >= minimumDays, before.count >= minimumBefore, after.count >= minimumAfter else { return nil }
        let baseline = median(before)
        guard baseline > 0 else { return nil }
        let change = (median(after) - baseline) / baseline * 100
        return ProductEffect(percentChange: Int(change.rounded()), scansBefore: before.count, scansAfter: after.count)
    }

    static func median(_ values: [Int]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? Double(sorted[mid - 1] + sorted[mid]) / 2 : Double(sorted[mid])
    }

    public var summary: String {
        if percentChange < 0 {
            return String(localized: "Since starting, breakouts are down \(abs(percentChange))%. Other changes may also play a part.")
        }
        if percentChange > 0 {
            return String(localized: "Since starting, breakouts are up \(percentChange)%. Worth watching — many things affect skin.")
        }
        return String(localized: "No clear change since starting.")
    }
}
