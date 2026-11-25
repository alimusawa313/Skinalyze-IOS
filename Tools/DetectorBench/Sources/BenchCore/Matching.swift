import CoreGraphics
import SkinalyzeKit

/// How one label or prediction ended up after matching (ML-PLAN M0.3).
public enum MatchOutcome: Sendable, Hashable {
    /// Same spot. The types may differ (a label confusion).
    case matched(truth: LabelBox, predicted: RawDetection)
    case missed(LabelBox)
    case spurious(RawDetection)
}

/// Greedy matching by confidence with the shared `DetectionMatching` rule: first same-class pairs, then the leftovers
/// across classes (so a papule called a pustule is a confusion, not a miss plus a false alarm).
public enum SpotMatcher {
    public static func match(predictions: [RawDetection], truth: [LabelBox], imageSize: CGSize) -> [MatchOutcome] {
        let byConfidence = predictions.sorted { $0.confidence > $1.confidence }
        let sameClass = greedy(byConfidence, truth: truth, imageSize: imageSize, sameClassOnly: true)
        let anyClass = greedy(sameClass.unmatchedPredictions, truth: sameClass.unmatchedTruth,
                              imageSize: imageSize, sameClassOnly: false)
        return (sameClass.pairs + anyClass.pairs).map { MatchOutcome.matched(truth: $0.truth, predicted: $0.predicted) }
            + anyClass.unmatchedTruth.map(MatchOutcome.missed)
            + anyClass.unmatchedPredictions.map(MatchOutcome.spurious)
    }

    private struct Pair {
        let truth: LabelBox
        let predicted: RawDetection
    }

    private struct Greedy {
        var pairs: [Pair] = []
        var unmatchedPredictions: [RawDetection] = []
        var unmatchedTruth: [LabelBox]
    }

    private static func greedy(
        _ predictions: [RawDetection], truth: [LabelBox], imageSize: CGSize, sameClassOnly: Bool
    ) -> Greedy {
        predictions.reduce(into: Greedy(unmatchedTruth: truth)) { state, prediction in
            let candidates = state.unmatchedTruth.indices.filter { index in
                let label = state.unmatchedTruth[index]
                return (!sameClassOnly || label.type == prediction.type)
                    && DetectionMatching.isSameSpot(prediction.box, as: label.box, imageSize: imageSize)
            }
            let closest = candidates.min { lhs, rhs in
                distance(prediction.box, state.unmatchedTruth[lhs].box, imageSize)
                    < distance(prediction.box, state.unmatchedTruth[rhs].box, imageSize)
            }
            guard let closest else {
                state.unmatchedPredictions.append(prediction)
                return
            }
            state.pairs.append(Pair(truth: state.unmatchedTruth.remove(at: closest), predicted: prediction))
        }
    }

    static func distance(_ a: ImageRect, _ b: ImageRect, _ imageSize: CGSize) -> Double {
        let dx = (a.center.x - b.center.x) * imageSize.width
        let dy = (a.center.y - b.center.y) * imageSize.height
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// True/false positives and false negatives, with the scores derived from them.
public struct Tally: Sendable, Hashable, Codable {
    public let truePositives: Int
    public let falsePositives: Int
    public let falseNegatives: Int

    public init(truePositives: Int, falsePositives: Int, falseNegatives: Int) {
        self.truePositives = truePositives
        self.falsePositives = falsePositives
        self.falseNegatives = falseNegatives
    }

    public static let zero = Tally(truePositives: 0, falsePositives: 0, falseNegatives: 0)

    public func adding(_ other: Tally) -> Tally {
        Tally(truePositives: truePositives + other.truePositives,
              falsePositives: falsePositives + other.falsePositives,
              falseNegatives: falseNegatives + other.falseNegatives)
    }

    public var precision: Double? {
        let predicted = truePositives + falsePositives
        return predicted > 0 ? Double(truePositives) / Double(predicted) : nil
    }

    public var recall: Double? {
        let labelled = truePositives + falseNegatives
        return labelled > 0 ? Double(truePositives) / Double(labelled) : nil
    }

    public var f1: Double? {
        guard let precision, let recall, precision + recall > 0 else { return nil }
        return 2 * precision * recall / (precision + recall)
    }
}

public enum ConfusionClass: Sendable, Hashable, Comparable {
    case lesion(LesionType)
    case background

    public static let all: [ConfusionClass] = LesionType.allCases.map(ConfusionClass.lesion) + [.background]

    public var name: String {
        switch self {
        case let .lesion(type): type.modelLabel
        case .background: "background"
        }
    }

    private var order: Int { Self.all.firstIndex(of: self) ?? Self.all.count }
    public static func < (lhs: ConfusionClass, rhs: ConfusionClass) -> Bool { lhs.order < rhs.order }
}

/// Rows are labels, columns are predictions; "background" means no label / no prediction.
public struct ConfusionMatrix: Sendable, Hashable {
    public let cells: [ConfusionClass: [ConfusionClass: Int]]

    public func count(truth: ConfusionClass, predicted: ConfusionClass) -> Int {
        cells[truth]?[predicted] ?? 0
    }

    /// Row-major counts in `ConfusionClass.all` order.
    public var rows: [[Int]] {
        ConfusionClass.all.map { truth in ConfusionClass.all.map { count(truth: truth, predicted: $0) } }
    }
}
