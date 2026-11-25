import CoreGraphics
import Foundation

/// A point in normalized image coordinates (Vision convention: origin bottom-left).
public struct ImagePoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public extension ImageRect {
    var center: ImagePoint { ImagePoint(x: x + width / 2, y: y + height / 2) }
    var area: Double { max(width, 0) * max(height, 0) }
}

// MARK: - Face crop

public enum FaceCrop {
    /// Square crop around the face with `margin` on every side, in **top-left-origin pixel** coordinates,
    /// clamped inside the image. Feeding the detector a consistent face-sized square removes the old
    /// device-dependent 224-px squash (PLAN.md §4.1 #5).
    public static func squarePixelRect(face: ImageRect, imageSize: CGSize, margin: Double = 0.2) -> CGRect {
        let faceWidth = face.width * imageSize.width
        let faceHeight = face.height * imageSize.height
        let maxSide = min(imageSize.width, imageSize.height)
        let side = min(max(faceWidth, faceHeight) * (1 + 2 * margin), maxSide)
        let centerX = (face.x + face.width / 2) * imageSize.width
        let centerY = (1 - (face.y + face.height / 2)) * imageSize.height
        let originX = min(max(centerX - side / 2, 0), imageSize.width - side)
        let originY = min(max(centerY - side / 2, 0), imageSize.height - side)
        return CGRect(x: originX, y: originY, width: side, height: side)
    }
}

// MARK: - Detection filtering

public struct RawDetection: Sendable, Hashable {
    public let type: LesionType
    public let confidence: Double
    public let box: ImageRect

    public init(type: LesionType, confidence: Double, box: ImageRect) {
        self.type = type
        self.confidence = confidence
        self.box = box
    }
}

public enum DetectionFilter {
    /// Starting point; tuned with the consistency benchmark (PLAN.md §11.1).
    public static let defaultMinConfidence = 0.4
    public static let defaultIoUThreshold = 0.45

    public static func iou(_ a: ImageRect, _ b: ImageRect) -> Double {
        let overlapWidth = min(a.x + a.width, b.x + b.width) - max(a.x, b.x)
        let overlapHeight = min(a.y + a.height, b.y + b.height) - max(a.y, b.y)
        guard overlapWidth > 0, overlapHeight > 0 else { return 0 }
        let intersection = overlapWidth * overlapHeight
        let union = a.area + b.area - intersection
        return union > 0 ? intersection / union : 0
    }

    /// One confidence threshold for every class + cross-class NMS (see `filter(_:thresholds:iouThreshold:)`).
    public static func filter(
        _ detections: [RawDetection],
        minConfidence: Double = defaultMinConfidence,
        iouThreshold: Double = defaultIoUThreshold
    ) -> [RawDetection] {
        filter(detections, thresholds: .uniform(minConfidence), iouThreshold: iouThreshold)
    }
}

// MARK: - Face zones

public enum FaceZone: String, CaseIterable, Sendable, Codable, Hashable {
    case forehead
    case nose
    case leftCheek
    case rightCheek
    case chin
    case leftJaw
    case rightJaw
}

/// Approximate face zones from the face box (2D path). The 3D path replaces this with mesh vertex sets (Phase 4).
/// Left/right are the **subject's** sides; stored photos are unmirrored, so image-left is the subject's right.
public enum FaceZoneMapper {
    static let outsideTolerance = 0.1
    static let foreheadBottom = 0.30
    static let jawTop = 0.78
    static let chinHalfWidth = 0.20
    static let noseHalfWidth = 0.13

    public static func zone(of point: ImagePoint, face: ImageRect, angle: CaptureAngle) -> FaceZone? {
        guard face.width > 0, face.height > 0 else { return nil }
        let u = (point.x - face.x) / face.width            // 0 = image left
        let v = 1 - (point.y - face.y) / face.height        // 0 = top of face
        let range = -outsideTolerance...(1 + outsideTolerance)
        guard range.contains(u), range.contains(v) else { return nil }

        if v < foreheadBottom { return .forehead }
        let distanceFromCenter = abs(u - 0.5)
        switch angle {
        case .front:
            let subjectRight = u < 0.5
            if v >= jawTop {
                return distanceFromCenter < chinHalfWidth ? .chin : (subjectRight ? .rightJaw : .leftJaw)
            }
            return distanceFromCenter < noseHalfWidth ? .nose : (subjectRight ? .rightCheek : .leftCheek)
        case .right, .left:
            // Head turned right shows the left side of the face, and vice versa.
            let showsLeft = angle == .right
            if v >= jawTop {
                return distanceFromCenter < chinHalfWidth / 2 ? .chin : (showsLeft ? .leftJaw : .rightJaw)
            }
            return distanceFromCenter < noseHalfWidth / 2 ? .nose : (showsLeft ? .leftCheek : .rightCheek)
        }
    }
}

/// Which capture "owns" each zone, so every lesion is counted exactly once across the three photos.
public enum ZoneOwnership {
    public static func owner(of zone: FaceZone, available: Set<CaptureAngle>) -> CaptureAngle {
        let preferred: CaptureAngle = switch zone {
        case .forehead, .nose, .chin: .front
        case .leftCheek, .leftJaw: .right   // the head-turned-right photo shows the left side
        case .rightCheek, .rightJaw: .left
        }
        return available.contains(preferred) ? preferred : .front
    }
}

public struct ZonedDetection: Sendable, Hashable {
    public let detection: RawDetection
    public let angle: CaptureAngle
    public let zone: FaceZone

    public init(detection: RawDetection, angle: CaptureAngle, zone: FaceZone) {
        self.detection = detection
        self.angle = angle
        self.zone = zone
    }
}

public enum ScanAggregator {
    /// Keeps only detections from the capture that owns their zone.
    public static func counted(_ detections: [ZonedDetection], available: Set<CaptureAngle>) -> [ZonedDetection] {
        detections.filter { ZoneOwnership.owner(of: $0.zone, available: available) == $0.angle }
    }

    public static func counts(of detections: [ZonedDetection]) -> LesionCounts {
        LesionCounts(Dictionary(detections.map { ($0.detection.type, 1) }, uniquingKeysWith: +))
    }
}

// MARK: - Scoring

/// Weighted breakout score (replaces the public "GEA" label). Dark spots are marks, not breakouts.
public enum BreakoutIndex {
    public static func weight(of type: LesionType) -> Int {
        switch type {
        case .nodule: 4
        case .pustule: 3
        case .papule: 2
        case .whitehead, .blackhead: 1
        case .darkSpot: 0
        }
    }

    public static func index(for counts: LesionCounts) -> Int {
        LesionType.allCases.reduce(0) { $0 + weight(of: $1) * counts[$1] }
    }
}

public enum BreakoutBand: String, CaseIterable, Sendable, Codable, Hashable {
    case calm
    case mild
    case active
    case flared

    static let mildMax = 8
    static let activeMax = 20

    public static func classify(index: Int) -> BreakoutBand {
        switch index {
        case ...0: .calm
        case ...mildMax: .mild
        case ...activeMax: .active
        default: .flared
        }
    }
}

// MARK: - Benchmark metrics

public enum ConsistencyMetrics {
    /// Share of runs that match the most common value (e.g. band agreement across repeat scans).
    public static func agreement<Value: Hashable>(_ values: [Value]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mostCommon = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +).values.max() ?? 0
        return Double(mostCommon) / Double(values.count)
    }

    /// Population standard deviation divided by the mean; `nil` when the mean is 0.
    public static func coefficientOfVariation(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean != 0 else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot() / mean
    }
}
