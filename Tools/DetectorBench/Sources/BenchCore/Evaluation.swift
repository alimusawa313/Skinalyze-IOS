import CoreGraphics
import Foundation
import SkinalyzeKit

/// One photo after the pipeline ran on it.
public struct PhotoResult: Sendable {
    public let meta: SampleMeta
    public let imageSize: CGSize
    public let face: ImageRect?
    /// Final detections from `DetectionPipeline` (full-image, Vision coordinates).
    public let predictions: [RawDetection]
    /// `nil` when the photo is unlabelled.
    public let truth: [LabelBox]?
    public let seconds: Double

    public init(meta: SampleMeta, imageSize: CGSize, face: ImageRect?, predictions: [RawDetection],
                truth: [LabelBox]?, seconds: Double) {
        self.meta = meta
        self.imageSize = imageSize
        self.face = face
        self.predictions = predictions
        self.truth = truth
        self.seconds = seconds
    }

    var outcomes: [MatchOutcome]? {
        truth.map { SpotMatcher.match(predictions: predictions, truth: $0, imageSize: imageSize) }
    }
}

/// The metrics of ML-PLAN M0.3. Every function is pure so the numbers are reproducible and tested.
public enum Evaluation {
    // MARK: Matching scores

    public static func classTallies(_ outcomes: [MatchOutcome]) -> [LesionType: Tally] {
        let empty = Dictionary(uniqueKeysWithValues: LesionType.allCases.map { ($0, Tally.zero) })
        return outcomes.reduce(into: empty) { tallies, outcome in
            func add(_ type: LesionType, _ tally: Tally) { tallies[type] = (tallies[type] ?? .zero).adding(tally) }
            switch outcome {
            case let .matched(truth, predicted) where truth.type == predicted.type:
                add(truth.type, Tally(truePositives: 1, falsePositives: 0, falseNegatives: 0))
            case let .matched(truth, predicted):
                add(truth.type, Tally(truePositives: 0, falsePositives: 0, falseNegatives: 1))
                add(predicted.type, Tally(truePositives: 0, falsePositives: 1, falseNegatives: 0))
            case let .missed(truth):
                add(truth.type, Tally(truePositives: 0, falsePositives: 0, falseNegatives: 1))
            case let .spurious(predicted):
                add(predicted.type, Tally(truePositives: 0, falsePositives: 1, falseNegatives: 0))
            }
        }
    }

    /// Spot finding with the label ignored: was there a spot where the model said so?
    public static func spotTally(_ outcomes: [MatchOutcome]) -> Tally {
        outcomes.reduce(Tally.zero) { total, outcome in
            switch outcome {
            case .matched: total.adding(Tally(truePositives: 1, falsePositives: 0, falseNegatives: 0))
            case .missed: total.adding(Tally(truePositives: 0, falsePositives: 0, falseNegatives: 1))
            case .spurious: total.adding(Tally(truePositives: 0, falsePositives: 1, falseNegatives: 0))
            }
        }
    }

    public static func confusion(_ outcomes: [MatchOutcome]) -> ConfusionMatrix {
        let cells = outcomes.reduce(into: [ConfusionClass: [ConfusionClass: Int]]()) { cells, outcome in
            let (truth, predicted): (ConfusionClass, ConfusionClass) = switch outcome {
            case let .matched(label, prediction): (.lesion(label.type), .lesion(prediction.type))
            case let .missed(label): (.lesion(label.type), .background)
            case let .spurious(prediction): (.background, .lesion(prediction.type))
            }
            cells[truth, default: [:]][predicted, default: 0] += 1
        }
        return ConfusionMatrix(cells: cells)
    }

    // MARK: Small spots

    /// Labels whose larger side is below this share of the face-crop side count as small.
    public static let smallObjectFraction = 0.01

    public struct SmallObjects: Sendable, Hashable, Codable {
        public let fractionOfCrop: Double
        public let labels: Int
        public let foundSameClass: Int
        public let foundAnyClass: Int

        public var recall: Double? { labels > 0 ? Double(foundSameClass) / Double(labels) : nil }
        public var recallAnyClass: Double? { labels > 0 ? Double(foundAnyClass) / Double(labels) : nil }
    }

    public static func smallObjects(_ results: [PhotoResult]) -> SmallObjects {
        let perPhoto = results.compactMap { result -> (labels: Int, same: Int, any: Int)? in
            guard let outcomes = result.outcomes else { return nil }
            let cropSide = result.face.map { FaceCrop.squarePixelRect(face: $0, imageSize: result.imageSize).width }
                ?? result.imageSize.width
            let limit = cropSide * smallObjectFraction
            func isSmall(_ label: LabelBox) -> Bool {
                max(label.box.width * result.imageSize.width, label.box.height * result.imageSize.height) < limit
            }
            return outcomes.reduce(into: (labels: 0, same: 0, any: 0)) { counts, outcome in
                switch outcome {
                case let .matched(label, predicted) where isSmall(label):
                    counts.labels += 1
                    counts.any += 1
                    if label.type == predicted.type { counts.same += 1 }
                case let .missed(label) where isSmall(label):
                    counts.labels += 1
                default:
                    break
                }
            }
        }
        return SmallObjects(
            fractionOfCrop: smallObjectFraction,
            labels: perPhoto.reduce(0) { $0 + $1.labels },
            foundSameClass: perPhoto.reduce(0) { $0 + $1.same },
            foundAnyClass: perPhoto.reduce(0) { $0 + $1.any }
        )
    }

    // MARK: Counts

    public struct CountErrors: Sendable, Hashable, Codable {
        public let photos: Int
        public let photoTotalMAE: Double?
        public let perClassMAE: [String: Double]
        public let perZoneMAE: [String: Double]
    }

    public static func countErrors(_ results: [PhotoResult]) -> CountErrors {
        let labelled = results.filter { $0.truth != nil }
        let totals = labelled.map { Double(abs($0.predictions.count - ($0.truth?.count ?? 0))) }
        let perClass = Dictionary(uniqueKeysWithValues: LesionType.allCases.map { type in
            let errors = labelled.map { result in
                Double(abs(result.predictions.count { $0.type == type } - (result.truth ?? []).count { $0.type == type }))
            }
            return (type.modelLabel, mean(errors) ?? 0)
        })
        let zoned = labelled.compactMap { result -> (truth: [FaceZone: Int], predicted: [FaceZone: Int])? in
            guard let face = result.face else { return nil }
            func zoneCounts(_ boxes: [ImageRect]) -> [FaceZone: Int] {
                let zones = boxes.compactMap { FaceZoneMapper.zone(of: $0.center, face: face, angle: result.meta.angle) }
                return Dictionary(zones.map { ($0, 1) }, uniquingKeysWith: +)
            }
            return (zoneCounts((result.truth ?? []).map(\.box)), zoneCounts(result.predictions.map(\.box)))
        }
        let perZone = zoned.isEmpty ? [:] : Dictionary(uniqueKeysWithValues: FaceZone.allCases.map { zone in
            (zone.rawValue, mean(zoned.map { Double(abs(($0.predicted[zone] ?? 0) - ($0.truth[zone] ?? 0))) }) ?? 0)
        })
        return CountErrors(photos: labelled.count, photoTotalMAE: mean(totals), perClassMAE: perClass, perZoneMAE: perZone)
    }

    // MARK: Scans

    struct SessionKey: Hashable, Comparable {
        let subject: String
        let session: String

        static func < (lhs: SessionKey, rhs: SessionKey) -> Bool {
            (lhs.subject, lhs.session) < (rhs.subject, rhs.session)
        }
    }

    static func sessions(_ results: [PhotoResult]) -> [SessionKey: [PhotoResult]] {
        Dictionary(grouping: results) { SessionKey(subject: $0.meta.subjectID, session: $0.meta.sessionID) }
    }

    /// Detections counted once per scan, exactly as the app does: zone from the face box, then zone ownership.
    static func counted(_ photos: [(angle: CaptureAngle, face: ImageRect?, detections: [RawDetection])]) -> [ZonedDetection] {
        let zoned = photos.flatMap { photo -> [ZonedDetection] in
            guard let face = photo.face else { return [] }
            return photo.detections.compactMap { detection in
                FaceZoneMapper.zone(of: detection.box.center, face: face, angle: photo.angle)
                    .map { ZonedDetection(detection: detection, angle: photo.angle, zone: $0) }
            }
        }
        return ScanAggregator.counted(zoned, available: Set(photos.map(\.angle)))
    }

    static func predictedIndex(_ photos: [PhotoResult]) -> Int {
        let detections = counted(photos.map { ($0.meta.angle, $0.face, $0.predictions) })
        return BreakoutIndex.index(for: ScanAggregator.counts(of: detections))
    }

    public struct ScanErrors: Sendable, Hashable, Codable {
        public let scans: Int
        public let indexMAE: Double?
        public let groupedIndexMAE: Double?
        public let bandAccuracy: Double?
    }

    /// Breakout Index error per scan, using only the labelled angles of each session (both sides counted the same way).
    public static func scanErrors(_ results: [PhotoResult]) -> ScanErrors {
        let scans = sessions(results).values.compactMap { photos -> (index: Double, grouped: Double, sameBand: Bool)? in
            let labelled = photos.filter { $0.truth != nil }
            guard !labelled.isEmpty else { return nil }
            let truth = counted(labelled.map { photo in
                (photo.meta.angle, photo.face,
                 (photo.truth ?? []).map { RawDetection(type: $0.type, confidence: 1, box: $0.box) })
            })
            let predicted = counted(labelled.map { ($0.meta.angle, $0.face, $0.predictions) })
            let truthIndex = BreakoutIndex.index(for: ScanAggregator.counts(of: truth))
            let predictedIndex = BreakoutIndex.index(for: ScanAggregator.counts(of: predicted))
            let truthGrouped = GroupedBreakoutIndex.index(for: truth.map(\.detection))
            let predictedGrouped = GroupedBreakoutIndex.index(for: predicted.map(\.detection))
            return (
                Double(abs(predictedIndex - truthIndex)),
                Double(abs(predictedGrouped - truthGrouped)),
                BreakoutBand.classify(index: predictedIndex) == BreakoutBand.classify(index: truthIndex)
            )
        }
        return ScanErrors(
            scans: scans.count,
            indexMAE: mean(scans.map(\.index)),
            groupedIndexMAE: mean(scans.map(\.grouped)),
            bandAccuracy: mean(scans.map { $0.sameBand ? 1 : 0 })
        )
    }

    // MARK: Consistency

    public struct Consistency: Sendable, Hashable, Codable {
        /// Subjects with at least two sessions.
        public let subjects: Int
        public let meanBandAgreement: Double
        public let subjectsWithFullAgreement: Int
        public let meanIndexCV: Double?
    }

    /// Repeat scans of the same person should agree. Uses every photo, labelled or not.
    public static func consistency(_ results: [PhotoResult]) -> Consistency {
        let bySubject = Dictionary(grouping: sessions(results), by: \.key.subject)
        let perSubject = bySubject.values.compactMap { sessions -> (agreement: Double, cv: Double)? in
            guard sessions.count >= 2 else { return nil }
            let indices = sessions.sorted { $0.key < $1.key }.map { predictedIndex($0.value) }
            let agreement = ConsistencyMetrics.agreement(indices.map(BreakoutBand.classify(index:)))
            // The CV is undefined when every index is 0 — that is perfect agreement.
            let cv = ConsistencyMetrics.coefficientOfVariation(indices.map(Double.init)) ?? 0
            return (agreement, cv)
        }
        return Consistency(
            subjects: perSubject.count,
            meanBandAgreement: mean(perSubject.map(\.agreement)) ?? 0,
            subjectsWithFullAgreement: perSubject.count { $0.agreement == 1 },
            meanIndexCV: mean(perSubject.map(\.cv))
        )
    }

    // MARK: Slices

    public enum SliceDimension: String, Sendable, Codable {
        case fitzpatrick
        case lighting
    }

    public struct Slice: Sendable, Hashable, Codable {
        public let dimension: SliceDimension
        public let value: String
        public let photos: Int
        public let labels: Int
        /// All classes together (micro average); a label confusion counts as a miss.
        public let overall: Tally
        /// Label ignored.
        public let spots: Tally
        public let smallRecall: Double?
        public let countMAE: Double?
    }

    static let unknownGroup = "unknown"

    public static func slices(_ results: [PhotoResult], dimension: SliceDimension) -> [Slice] {
        let labelled = results.filter { $0.truth != nil }
        let groups = Dictionary(grouping: labelled) { result -> String in
            let value = dimension == .fitzpatrick ? result.meta.fitzpatrick : result.meta.lighting
            return value.isEmpty ? unknownGroup : value
        }
        return groups.keys
            .sorted { ($0 == unknownGroup ? 1 : 0, $0) < ($1 == unknownGroup ? 1 : 0, $1) }
            .map { value in
                let photos = groups[value] ?? []
                let outcomes = photos.flatMap { $0.outcomes ?? [] }
                return Slice(
                    dimension: dimension,
                    value: value,
                    photos: photos.count,
                    labels: photos.reduce(0) { $0 + ($1.truth?.count ?? 0) },
                    overall: classTallies(outcomes).values.reduce(Tally.zero) { $0.adding($1) },
                    spots: spotTally(outcomes),
                    smallRecall: smallObjects(photos).recall,
                    countMAE: countErrors(photos).photoTotalMAE
                )
            }
    }

    // MARK: Device parity

    public struct Parity: Sendable, Hashable, Codable {
        public let files: Int
        public let deviceDetections: Int
        /// Device detections the bench reproduced (same spot, same label).
        public let matched: Int
        public let meanAbsCountDifference: Double
        public let maxConfidenceDifference: Double
    }

    /// Compares what the phone counted (from the app export) with what the bench counts for the same photos.
    /// Meaningful when the dataset is one app export run with the same pipeline version as this variant.
    public static func parity(_ results: [PhotoResult], device: [String: [RawDetection]]) -> Parity? {
        guard !device.isEmpty else { return nil }
        let benchCounted = sessions(results).values.flatMap { photos in
            let counted = counted(photos.map { ($0.meta.angle, $0.face, $0.predictions) })
            return photos.map { photo in
                (photo, counted.filter { $0.angle == photo.meta.angle }.map(\.detection))
            }
        }
        let perFile = benchCounted.map { photo, bench -> (count: Int, device: Int, matched: Int, confidence: Double) in
            let phone = device[photo.meta.file] ?? []
            let confidence = Dictionary(phone.map { ($0.box, $0.confidence) }, uniquingKeysWith: max)
            let outcomes = SpotMatcher.match(
                predictions: bench, truth: phone.map { LabelBox(type: $0.type, box: $0.box) }, imageSize: photo.imageSize
            )
            let differences = outcomes.compactMap { outcome -> Double? in
                guard case let .matched(label, predicted) = outcome, label.type == predicted.type else { return nil }
                return abs(predicted.confidence - (confidence[label.box] ?? predicted.confidence))
            }
            return (abs(phone.count - bench.count), phone.count, differences.count, differences.max() ?? 0)
        }
        return Parity(
            files: perFile.count,
            deviceDetections: perFile.reduce(0) { $0 + $1.device },
            matched: perFile.reduce(0) { $0 + $1.matched },
            meanAbsCountDifference: mean(perFile.map { Double($0.count) }) ?? 0,
            maxConfidenceDifference: perFile.map(\.confidence).max() ?? 0
        )
    }

    // MARK: Helpers

    static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * fraction).rounded(.up))
        return sorted[min(index, sorted.count - 1)]
    }
}
