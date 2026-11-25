/// A confidence threshold for each lesion class (ML-PLAN M1.3). Classes without an entry use the fallback.
public struct ClassThresholds: Sendable, Hashable {
    public let values: [LesionType: Double]

    public init(_ values: [LesionType: Double], fallback: Double = DetectionFilter.defaultMinConfidence) {
        self.values = Dictionary(uniqueKeysWithValues: LesionType.allCases.map { ($0, values[$0] ?? fallback) })
    }

    public static func uniform(_ threshold: Double) -> ClassThresholds {
        ClassThresholds([:], fallback: threshold)
    }

    public subscript(type: LesionType) -> Double {
        values[type] ?? DetectionFilter.defaultMinConfidence
    }

    /// Lowest threshold of any class — the floor the model itself must report down to.
    public var minimum: Double { values.values.min() ?? DetectionFilter.defaultMinConfidence }
}

public extension DetectionFilter {
    /// The one table of per-class thresholds the app uses. Every class is 0.4 (the old single threshold) until the
    /// benchmark picks better values (ML-PLAN M1.3); changing a value moves users' numbers, so bump
    /// `DetectionPipeline.shippingVersion` with it.
    static let classThresholdTable: [LesionType: Double] = [
        .blackhead: 0.4,
        .whitehead: 0.4,
        .papule: 0.4,
        .pustule: 0.4,
        .nodule: 0.4,
        .darkSpot: 0.4,
    ]

    static let classThresholds = ClassThresholds(classThresholdTable)

    /// Per-class confidence threshold + **cross-class** non-maximum suppression: one lesion is counted once,
    /// under its most confident label.
    static func filter(
        _ detections: [RawDetection],
        thresholds: ClassThresholds,
        iouThreshold: Double = defaultIoUThreshold
    ) -> [RawDetection] {
        let candidates = detections
            .filter { $0.confidence >= thresholds[$0.type] }
            .sorted { $0.confidence > $1.confidence }
        return candidates.reduce(into: [RawDetection]()) { kept, candidate in
            if kept.allSatisfy({ iou($0.box, candidate.box) < iouThreshold }) {
                kept.append(candidate)
            }
        }
    }
}
