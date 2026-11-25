import Foundation
import SkinalyzeKit

/// Everything one benchmark run measured. Numbers only — no file names, photos or subject IDs.
public struct BenchReport: Sendable, Codable {
    public struct Score: Sendable, Hashable, Codable {
        public let tally: Tally
        public let precision: Double?
        public let recall: Double?
        public let f1: Double?

        init(_ tally: Tally) {
            self.tally = tally
            precision = tally.precision
            recall = tally.recall
            f1 = tally.f1
        }
    }

    public struct ClassScore: Sendable, Hashable, Codable {
        public let name: String
        public let labels: Int
        public let score: Score
    }

    public struct Configuration: Sendable, Hashable, Codable {
        public let tiling: String
        public let runsPerPhoto: Int
        public let thresholds: [String: Double]
        public let iouThreshold: Double
        public let masksLandmarks: Bool
        public let normalizesColor: Bool
        public let modelConfidenceFloor: Double?
        /// `true` when this run is what the app ships today (`DetectionPipeline.Configuration.shipping`).
        public let isShipping: Bool
    }

    public struct Dataset: Sendable, Hashable, Codable {
        public let photos: Int
        public let labelledPhotos: Int
        /// Photos where Vision found a face. Without one, spots get no zone and are not counted (as in the app).
        public let photosWithFace: Int
        public let subjects: Int
        public let sessions: Int
        public let labelsPerClass: [String: Int]
    }

    public struct Timing: Sendable, Hashable, Codable {
        public let meanSecondsPerPhoto: Double?
        public let p95SecondsPerPhoto: Double?
    }

    public let variant: String
    public let date: String
    public let model: String
    public let configuration: Configuration
    public let dataset: Dataset
    public let perClass: [ClassScore]
    public let overall: Score
    public let spots: Score
    public let smallObjects: Evaluation.SmallObjects
    public let confusionLabels: [String]
    public let confusion: [[Int]]
    public let counts: Evaluation.CountErrors
    public let scans: Evaluation.ScanErrors
    public let consistency: Evaluation.Consistency
    public let fitzpatrick: [Evaluation.Slice]
    public let lighting: [Evaluation.Slice]
    public let timing: Timing
    public let parity: Evaluation.Parity?
}

public extension Evaluation {
    static func report(
        results: [PhotoResult],
        variant: String,
        date: String,
        model: String,
        configuration: DetectionPipeline.Configuration,
        modelConfidenceFloor: Double?,
        device: [String: [RawDetection]]
    ) -> BenchReport {
        let outcomes = results.flatMap { $0.outcomes ?? [] }
        let tallies = classTallies(outcomes)
        let labels = results.flatMap { $0.truth ?? [] }
        let tiling = configuration.tiling
        let tilingName = tiling.grid == 1
            ? "none"
            : "\(tiling.grid)x\(tiling.grid), overlap \(tiling.overlap)\(tiling.includesWholeCrop ? " + whole crop" : "")"
        let matrix = confusion(outcomes)
        let seconds = results.map(\.seconds)

        return BenchReport(
            variant: variant,
            date: date,
            model: model,
            configuration: BenchReport.Configuration(
                tiling: tilingName,
                runsPerPhoto: tiling.runsPerImage,
                thresholds: Dictionary(uniqueKeysWithValues: LesionType.allCases.map {
                    ($0.modelLabel, configuration.thresholds[$0])
                }),
                iouThreshold: configuration.iouThreshold,
                masksLandmarks: configuration.masksLandmarks,
                normalizesColor: configuration.normalizesColor,
                modelConfidenceFloor: modelConfidenceFloor,
                isShipping: configuration == .shipping && modelConfidenceFloor == nil
            ),
            dataset: BenchReport.Dataset(
                photos: results.count,
                labelledPhotos: results.count { $0.truth != nil },
                photosWithFace: results.count { $0.face != nil },
                subjects: Set(results.map(\.meta.subjectID)).count,
                sessions: sessions(results).count,
                labelsPerClass: Dictionary(uniqueKeysWithValues: LesionType.allCases.map { type in
                    (type.modelLabel, labels.count { $0.type == type })
                })
            ),
            perClass: LesionType.allCases.map { type in
                BenchReport.ClassScore(
                    name: type.modelLabel,
                    labels: labels.count { $0.type == type },
                    score: BenchReport.Score(tallies[type] ?? .zero)
                )
            },
            overall: BenchReport.Score(tallies.values.reduce(Tally.zero) { $0.adding($1) }),
            spots: BenchReport.Score(spotTally(outcomes)),
            smallObjects: smallObjects(results),
            confusionLabels: ConfusionClass.all.map(\.name),
            confusion: matrix.rows,
            counts: countErrors(results),
            scans: scanErrors(results),
            consistency: consistency(results),
            fitzpatrick: slices(results, dimension: .fitzpatrick),
            lighting: slices(results, dimension: .lighting),
            timing: BenchReport.Timing(meanSecondsPerPhoto: mean(seconds), p95SecondsPerPhoto: percentile(seconds, 0.95)),
            parity: parity(results, device: device)
        )
    }
}

public enum ReportRenderer {
    public static func json(_ report: BenchReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    public static func markdown(_ report: BenchReport) -> String {
        [
            header(report),
            perClass(report),
            spots(report),
            confusion(report),
            counts(report),
            consistency(report),
            slices("Fitzpatrick", report.fitzpatrick),
            slices("Lighting", report.lighting),
            timing(report),
        ].joined(separator: "\n\n") + "\n"
    }

    static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
    }

    static func number(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? "—"
    }

    static func table(_ header: [String], _ rows: [[String]]) -> String {
        let lines = [header, header.map { _ in "---" }] + rows
        return lines.map { "| " + $0.joined(separator: " | ") + " |" }.joined(separator: "\n")
    }

    private static func header(_ report: BenchReport) -> String {
        let config = report.configuration
        let thresholds = LesionType.allCases
            .map { "\($0.modelLabel) \(number(config.thresholds[$0.modelLabel]))" }
            .joined(separator: ", ")
        let dataset = report.dataset
        return """
        # Detector benchmark — \(report.variant) (\(report.date))

        Model `\(report.model)`. Numbers only; no photos, file names or subject IDs.
        \(config.isShipping ? "This is the configuration the app ships." : "Not the shipping configuration.")

        | Setting | Value |
        | --- | --- |
        | Tiling | \(config.tiling) (\(config.runsPerPhoto) model runs per photo) |
        | Thresholds | \(thresholds) |
        | NMS IoU | \(number(config.iouThreshold)) |
        | Landmark mask | \(config.masksLandmarks ? "on" : "off") |
        | Colour normalisation | \(config.normalizesColor ? "on" : "off") |
        | Model confidence floor | \(config.modelConfidenceFloor.map { number($0) } ?? "model default") |

        Dataset: \(dataset.photos) photos (\(dataset.labelledPhotos) labelled), people: \(dataset.subjects), \
        sessions: \(dataset.sessions).\(noFaceWarning(dataset))
        """
    }

    private static func noFaceWarning(_ dataset: BenchReport.Dataset) -> String {
        let missing = dataset.photos - dataset.photosWithFace
        guard missing > 0 else { return "" }
        return "\n\n**Warning:** no face found in \(missing) of \(dataset.photos) photos. Their spots get no zone, so " +
            "they are not counted in scan, zone or consistency numbers (the app drops them the same way)."
    }

    private static func perClass(_ report: BenchReport) -> String {
        let rows = report.perClass.map { item in
            [item.name, "\(item.labels)", percent(item.score.precision), percent(item.score.recall),
             percent(item.score.f1), "\(item.score.tally.truePositives)", "\(item.score.tally.falsePositives)",
             "\(item.score.tally.falseNegatives)"]
        } + [["**all (micro)**", "\(report.perClass.reduce(0) { $0 + $1.labels })", percent(report.overall.precision),
              percent(report.overall.recall), percent(report.overall.f1), "\(report.overall.tally.truePositives)",
              "\(report.overall.tally.falsePositives)", "\(report.overall.tally.falseNegatives)"]]
        return "## Per class\n\n" + table(["Class", "Labels", "Precision", "Recall", "F1", "TP", "FP", "FN"], rows)
    }

    private static func spots(_ report: BenchReport) -> String {
        let small = report.smallObjects
        return """
        ## Spots found (any label)

        Precision \(percent(report.spots.precision)), recall \(percent(report.spots.recall)), \
        F1 \(percent(report.spots.f1)). A gap between this and the per-class numbers means the model finds spots but \
        mislabels them.

        ## Small spots

        Labels smaller than \(percent(small.fractionOfCrop)) of the face-crop side: \(small.labels). \
        Recall \(percent(small.recall)) (same label), \(percent(small.recallAnyClass)) (any label).
        """
    }

    private static func confusion(_ report: BenchReport) -> String {
        let rows = zip(report.confusionLabels, report.confusion).map { label, counts in
            ["**\(label)**"] + counts.map(String.init)
        }
        return "## Confusion (rows: label, columns: prediction)\n\n" + table(["label \\ predicted"] + report.confusionLabels, rows)
    }

    private static func counts(_ report: BenchReport) -> String {
        let counts = report.counts
        let classRows = LesionType.allCases.map { [$0.modelLabel, number(counts.perClassMAE[$0.modelLabel])] }
        let zoneRows = FaceZone.allCases.compactMap { zone in
            counts.perZoneMAE[zone.rawValue].map { [zone.rawValue, number($0)] }
        }
        let scans = report.scans
        return """
        ## Counts

        Count error per labelled photo (mean absolute error): \(number(counts.photoTotalMAE)) spots.

        \(table(["Class", "MAE per photo"], classRows))

        \(zoneRows.isEmpty ? "No zone errors (no faces found)." : table(["Zone", "MAE per photo"], zoneRows))

        Per scan (labelled angles only, \(scans.scans) scans): Breakout Index MAE \(number(scans.indexMAE)), \
        band right \(percent(scans.bandAccuracy)). Proposed grouped index (ML-PLAN M1.6, not shipped) MAE \
        \(number(scans.groupedIndexMAE)).
        """
    }

    private static func consistency(_ report: BenchReport) -> String {
        let consistency = report.consistency
        return """
        ## Consistency across repeat sessions

        People with 2+ sessions: \(consistency.subjects). Band agreement \(percent(consistency.meanBandAgreement)) \
        (target ≥ 90%); \(consistency.subjectsWithFullAgreement) of them got the same band every time. \
        Mean index coefficient of variation \(percent(consistency.meanIndexCV)) (target ≤ 25%).
        """
    }

    private static func slices(_ title: String, _ slices: [Evaluation.Slice]) -> String {
        let rows = slices.map { slice in
            [slice.value, "\(slice.photos)", "\(slice.labels)", percent(slice.overall.precision),
             percent(slice.overall.recall), percent(slice.spots.recall), percent(slice.smallRecall), number(slice.countMAE)]
        }
        let header = ["Group", "Photos", "Labels", "Precision", "Recall", "Spot recall", "Small recall", "Count MAE"]
        return "## Slices: \(title)\n\n" + (rows.isEmpty ? "No labelled photos." : table(header, rows))
    }

    private static func timing(_ report: BenchReport) -> String {
        let parity = report.parity.map { parity in
            """
            ## Device parity

            \(parity.files) photos compared with what the phone counted: \(parity.matched) of \
            \(parity.deviceDetections) phone detections reproduced; mean count difference \
            \(number(parity.meanAbsCountDifference)) per photo; largest confidence difference \
            \(number(parity.maxConfidenceDifference)). Only meaningful when the dataset is one app export counted with \
            this variant's pipeline version.
            """
        } ?? "## Device parity\n\nNo `device_detections.csv` in the dataset."
        return """
        ## Timing (Mac, not the device budget)

        Mean \(number(report.timing.meanSecondsPerPhoto)) s per photo, p95 \(number(report.timing.p95SecondsPerPhoto)) s. \
        The 2.5 s / 3-photo budget must be checked on the oldest supported iPhone.

        \(parity)
        """
    }
}
