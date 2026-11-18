import CoreGraphics
import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Face crop")
struct FaceCropTests {
    @Test("Square crop around the face with margin, in top-left pixel coordinates")
    func squareCrop() {
        // Face occupies the middle of a 1000×2000 portrait image (Vision coords: origin bottom-left).
        let face = NormalizedRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2) // 400×400 px
        let crop = FaceCrop.squarePixelRect(face: face, imageSize: CGSize(width: 1000, height: 2000), margin: 0.25)
        #expect(crop.width == crop.height)
        #expect(crop.width == 600) // 400 * (1 + 2*0.25)
        #expect(crop.midX == 500)
        #expect(crop.midY == 1000) // centre y = (1 - 0.5) * 2000
    }

    @Test("Crop is clamped inside the image and stays square")
    func clamped() {
        let face = NormalizedRect(x: 0.0, y: 0.8, width: 0.5, height: 0.2)
        let size = CGSize(width: 800, height: 1000)
        let crop = FaceCrop.squarePixelRect(face: face, imageSize: size, margin: 0.3)
        #expect(crop.minX >= 0 && crop.minY >= 0)
        #expect(crop.maxX <= size.width && crop.maxY <= size.height)
        #expect(crop.width == crop.height)
    }
}

@Suite("Detection filtering")
struct DetectionFilterTests {
    private func box(_ x: Double, _ y: Double, _ s: Double = 0.1) -> NormalizedRect {
        NormalizedRect(x: x, y: y, width: s, height: s)
    }

    @Test("IoU of identical, disjoint and half-overlapping boxes")
    func iou() {
        #expect(DetectionFilter.iou(box(0, 0), box(0, 0)) == 1)
        #expect(DetectionFilter.iou(box(0, 0), box(0.5, 0.5)) == 0)
        #expect(abs(DetectionFilter.iou(box(0, 0), box(0.05, 0)) - (1.0 / 3.0)) < 0.0001)
    }

    @Test("Drops low-confidence detections")
    func confidence() {
        let kept = DetectionFilter.filter([
            RawDetection(type: .papule, confidence: 0.39, box: box(0, 0)),
            RawDetection(type: .papule, confidence: 0.41, box: box(0.5, 0.5)),
        ], minConfidence: 0.4)
        #expect(kept.map(\.confidence) == [0.41])
    }

    @Test("Cross-class NMS: one lesion labelled two ways is counted once, keeping the most confident label")
    func crossClass() {
        let kept = DetectionFilter.filter([
            RawDetection(type: .papule, confidence: 0.6, box: box(0.2, 0.2)),
            RawDetection(type: .pustule, confidence: 0.8, box: box(0.21, 0.2)),
            RawDetection(type: .whitehead, confidence: 0.7, box: box(0.7, 0.7)),
        ])
        #expect(kept.count == 2)
        #expect(kept.contains { $0.type == .pustule })
        #expect(!kept.contains { $0.type == .papule })
    }
}

@Suite("Face zones and once-only counting")
struct FaceZoneTests {
    private let face = NormalizedRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)

    /// Point given in face-relative coordinates (u from image left, v from top of face).
    private func point(u: Double, v: Double) -> NormalizedPoint {
        NormalizedPoint(x: face.x + u * face.width, y: face.y + (1 - v) * face.height)
    }

    @Test("Front capture maps forehead, nose, chin, cheeks and jaw",
          arguments: [
            (0.5, 0.1, FaceZone.forehead),
            (0.5, 0.5, .nose),
            (0.5, 0.9, .chin),
            (0.15, 0.5, .rightCheek), // image-left = subject's right (photos are stored unmirrored)
            (0.85, 0.5, .leftCheek),
            (0.1, 0.9, .rightJaw),
            (0.9, 0.9, .leftJaw),
          ])
    func frontZones(u: Double, v: Double, zone: FaceZone) {
        #expect(FaceZoneMapper.zone(of: point(u: u, v: v), face: face, angle: .front) == zone)
    }

    // CaptureAngle.right = head turned to the subject's right → the camera sees the LEFT cheek.
    @Test("Side captures put cheek/jaw lesions on the side the camera sees")
    func sideZones() {
        #expect(FaceZoneMapper.zone(of: point(u: 0.8, v: 0.5), face: face, angle: .right) == .leftCheek)
        #expect(FaceZoneMapper.zone(of: point(u: 0.2, v: 0.9), face: face, angle: .left) == .rightJaw)
        #expect(FaceZoneMapper.zone(of: point(u: 0.5, v: 0.1), face: face, angle: .left) == .forehead)
    }

    @Test("Points well outside the face are ignored")
    func outside() {
        #expect(FaceZoneMapper.zone(of: NormalizedPoint(x: 0.01, y: 0.99), face: face, angle: .front) == nil)
    }

    @Test("Each zone is owned by exactly one capture; side shots own the cheek and jaw they show")
    func ownership() {
        let all: Set<CaptureAngle> = [.front, .left, .right]
        #expect(ZoneOwnership.owner(of: .forehead, available: all) == .front)
        #expect(ZoneOwnership.owner(of: .leftCheek, available: all) == .right)
        #expect(ZoneOwnership.owner(of: .rightJaw, available: all) == .left)
        #expect(ZoneOwnership.owner(of: .rightCheek, available: [.front]) == .front)
    }

    @Test("The same cheek seen in front and side shots is counted once (side shot owns it)")
    func dedupe() {
        let lesion = RawDetection(type: .papule, confidence: 0.9, box: NormalizedRect(x: 0.3, y: 0.4, width: 0.02, height: 0.02))
        let zoned = [
            ZonedDetection(detection: lesion, angle: .front, zone: .rightCheek),
            ZonedDetection(detection: lesion, angle: .left, zone: .rightCheek),
            ZonedDetection(detection: lesion, angle: .front, zone: .forehead),
            ZonedDetection(detection: lesion, angle: .left, zone: .nose), // nose belongs to the front shot
        ]
        let counted = ScanAggregator.counted(zoned, available: [.front, .left, .right])
        #expect(counted.count == 2)
        #expect(ScanAggregator.counts(of: counted)[.papule] == 2)
    }
}

@Suite("Breakout index")
struct BreakoutIndexTests {
    @Test("Weights deeper lesions more and ignores dark spots (marks)")
    func weights() {
        let counts = LesionCounts([.nodule: 1, .pustule: 1, .papule: 1, .whitehead: 1, .blackhead: 1, .darkSpot: 10])
        #expect(BreakoutIndex.index(for: counts) == 4 + 3 + 2 + 1 + 1)
    }

    @Test("Bands", arguments: [(0, BreakoutBand.calm), (5, .mild), (15, .active), (40, .flared)])
    func bands(index: Int, band: BreakoutBand) {
        #expect(BreakoutBand.classify(index: index) == band)
    }
}

@Suite("Consistency metrics")
struct ConsistencyMetricsTests {
    @Test("Agreement is the share of runs matching the most common value")
    func agreement() {
        #expect(ConsistencyMetrics.agreement(["mild", "mild", "active", "mild"]) == 0.75)
        #expect(ConsistencyMetrics.agreement([String]()) == 0)
    }

    @Test("Coefficient of variation")
    func cv() {
        #expect(ConsistencyMetrics.coefficientOfVariation([10, 10, 10]) == 0)
        let cv = ConsistencyMetrics.coefficientOfVariation([8, 10, 12])
        #expect(abs((cv ?? 0) - 0.16330) < 0.0001)
        #expect(ConsistencyMetrics.coefficientOfVariation([0, 0]) == nil, "undefined when the mean is 0")
    }
}
