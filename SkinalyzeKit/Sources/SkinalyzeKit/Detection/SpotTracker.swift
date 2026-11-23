import Foundation

/// One detection placed in the eye-aligned frame (pixels of the aligned photo, top-left origin).
public struct SpotObservation: Sendable, Hashable {
    /// The stored detection's id.
    public let id: String
    public let type: LesionType
    public let point: SIMD2<Double>
    public let confidence: Double

    public init(id: String, type: LesionType, point: SIMD2<Double>, confidence: Double) {
        self.id = id
        self.type = type
        self.point = point
        self.confidence = confidence
    }
}

/// One scan's front-photo detections. `isAligned` is false when no face could be found to line the photo up.
public struct ScanSpots: Sendable {
    public let date: Date
    public let spots: [SpotObservation]
    public let isAligned: Bool

    public init(date: Date, spots: [SpotObservation], isAligned: Bool) {
        self.date = date
        self.spots = spots
        self.isAligned = isAligned
    }
}

/// The same spot followed across scans. Wording is deliberately modest: "seen in the same place".
public struct SpotTrail: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case firstSeen
        case samePlace
        /// Seen in the same place, now as a dark mark.
        case nowAMark
        /// Not seen in the next scan.
        case notSeen
    }

    public struct Entry: Sendable, Equatable {
        public let date: Date
        public let status: Status
        /// Nil for `notSeen`.
        public let observation: SpotObservation?
    }

    public var entries: [Entry]
}

public enum SpotTracker {
    /// Detections below this are not followed (a wrong trail is worse than none).
    public static let minimumConfidence = 0.5
    /// A spot counts as the same when it is this close, as a share of the distance between the eyes.
    public static let radiusShareOfEyeDistance = 0.15

    /// Match radius in aligned-frame pixels.
    public static func radius(alignedWidth: Double) -> Double {
        (1 - 2 * Double(FaceAlignment.eyeInset)) * alignedWidth * radiusShareOfEyeDistance
    }

    /// Scans oldest first. Matching is greedy, nearest pairs first; each spot joins at most one trail.
    public static func track(_ scans: [ScanSpots], radius: Double) -> [SpotTrail] {
        var trails: [SpotTrail] = []
        var open: [Int] = [] // indices of trails still being followed

        for scan in scans where scan.isAligned {
            let candidates = scan.spots.filter { $0.confidence >= minimumConfidence }
            var pairs: [(trail: Int, spot: Int, distance: Double)] = []
            for trail in open {
                guard let last = trails[trail].entries.last?.observation else { continue }
                for (index, spot) in candidates.enumerated() {
                    let d = distance(last.point, spot.point)
                    if d <= radius { pairs.append((trail, index, d)) }
                }
            }
            pairs.sort { $0.distance < $1.distance }

            var matchedTrails = Set<Int>(), matchedSpots = Set<Int>()
            for pair in pairs where !matchedTrails.contains(pair.trail) && !matchedSpots.contains(pair.spot) {
                matchedTrails.insert(pair.trail)
                matchedSpots.insert(pair.spot)
                let spot = candidates[pair.spot]
                let wasMark = trails[pair.trail].entries.last?.observation?.type.isMark ?? false
                let status: SpotTrail.Status = spot.type.isMark && !wasMark ? .nowAMark : .samePlace
                trails[pair.trail].entries.append(.init(date: scan.date, status: status, observation: spot))
            }
            for trail in open where !matchedTrails.contains(trail) {
                trails[trail].entries.append(.init(date: scan.date, status: .notSeen, observation: nil))
            }
            open = open.filter { matchedTrails.contains($0) }
            for (index, spot) in candidates.enumerated() where !matchedSpots.contains(index) {
                trails.append(SpotTrail(entries: [.init(date: scan.date, status: .firstSeen, observation: spot)]))
                open.append(trails.count - 1)
            }
        }
        return trails
    }

    public static func trail(containing detectionID: String, in trails: [SpotTrail]) -> SpotTrail? {
        trails.first { trail in trail.entries.contains { $0.observation?.id == detectionID } }
    }

    private static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }
}
