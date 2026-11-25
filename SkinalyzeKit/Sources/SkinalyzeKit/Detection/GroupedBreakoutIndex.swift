/// Proposed steadier scoring (ML-PLAN M1.6). **Not used for users' numbers** until the owner decides (ML-PLAN §3 D2);
/// the benchmark reports it next to `BreakoutIndex` so the decision can be made with numbers.
///
/// The six labels stay for display, but the index is computed from groups the detector can tell apart more reliably:
/// comedones, inflamed spots, confident nodules, marks.
public enum LesionGroup: String, CaseIterable, Sendable, Codable, Hashable {
    case comedone
    case inflamed
    case nodule
    case mark
}

public enum GroupedBreakoutIndex {
    /// Below this confidence a "nodule" counts as an ordinary inflamed spot: one wrong nodule label moved the old
    /// index by 4.
    public static let noduleMinConfidence = 0.7

    public static func group(of type: LesionType, confidence: Double) -> LesionGroup {
        switch type {
        case .blackhead, .whitehead: .comedone
        case .papule, .pustule: .inflamed
        case .nodule: confidence >= noduleMinConfidence ? .nodule : .inflamed
        case .darkSpot: .mark
        }
    }

    public static func weight(of group: LesionGroup) -> Int {
        switch group {
        case .comedone: 1
        case .inflamed: 2
        case .nodule: 4
        case .mark: 0
        }
    }

    public static func index(for detections: [RawDetection]) -> Int {
        detections.reduce(0) { $0 + weight(of: group(of: $1.type, confidence: $1.confidence)) }
    }
}
