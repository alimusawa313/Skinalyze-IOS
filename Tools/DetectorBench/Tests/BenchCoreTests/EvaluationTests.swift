import CoreGraphics
import Foundation
import Testing
@testable import BenchCore
import SkinalyzeKit

private let size = CGSize(width: 1000, height: 1000)

private func box(_ x: Double, _ y: Double, _ side: Double = 0.01) -> ImageRect {
    ImageRect(x: x, y: y, width: side, height: side)
}

private func truth(_ type: LesionType, _ x: Double, _ y: Double, _ side: Double = 0.01) -> LabelBox {
    LabelBox(type: type, box: box(x, y, side))
}

private func prediction(_ type: LesionType, _ x: Double, _ y: Double, _ confidence: Double = 0.9) -> RawDetection {
    RawDetection(type: type, confidence: confidence, box: box(x, y))
}

@Suite("Matching predictions to labels")
struct SpotMatcherTests {
    @Test("Same-class matches first, then label confusions, then misses and spurious boxes")
    func outcomes() {
        let outcomes = SpotMatcher.match(
            predictions: [
                prediction(.papule, 0.2, 0.2),        // correct
                prediction(.pustule, 0.5, 0.5),       // right place, wrong label (truth: papule)
                prediction(.whitehead, 0.8, 0.8),     // nothing there
            ],
            truth: [truth(.papule, 0.2, 0.2), truth(.papule, 0.5, 0.5), truth(.blackhead, 0.1, 0.9)],
            imageSize: size
        )
        let tallies = Evaluation.classTallies(outcomes)
        #expect(tallies[.papule] == Tally(truePositives: 1, falsePositives: 0, falseNegatives: 1))
        #expect(tallies[.pustule] == Tally(truePositives: 0, falsePositives: 1, falseNegatives: 0))
        #expect(tallies[.whitehead] == Tally(truePositives: 0, falsePositives: 1, falseNegatives: 0))
        #expect(tallies[.blackhead] == Tally(truePositives: 0, falsePositives: 0, falseNegatives: 1))
        // Class-agnostic: 2 spots found, 1 spurious, 1 missed
        #expect(Evaluation.spotTally(outcomes) == Tally(truePositives: 2, falsePositives: 1, falseNegatives: 1))
    }

    @Test("Two predictions on one spot: the more confident matches, the other is a false positive")
    func duplicates() {
        let outcomes = SpotMatcher.match(
            predictions: [prediction(.papule, 0.2, 0.2, 0.5), prediction(.papule, 0.2005, 0.2, 0.9)],
            truth: [truth(.papule, 0.2, 0.2)],
            imageSize: size
        )
        #expect(Evaluation.classTallies(outcomes)[.papule] == Tally(truePositives: 1, falsePositives: 1, falseNegatives: 0))
        let matchedConfidence = outcomes.compactMap { outcome -> Double? in
            if case let .matched(_, predicted) = outcome { return predicted.confidence }
            return nil
        }
        #expect(matchedConfidence == [0.9])
    }

    @Test("Confusion matrix rows are labels, columns predictions, with background")
    func confusion() {
        let outcomes = SpotMatcher.match(
            predictions: [prediction(.pustule, 0.5, 0.5), prediction(.whitehead, 0.8, 0.8)],
            truth: [truth(.papule, 0.5, 0.5), truth(.nodule, 0.1, 0.1)],
            imageSize: size
        )
        let matrix = Evaluation.confusion(outcomes)
        #expect(matrix.count(truth: .lesion(.papule), predicted: .lesion(.pustule)) == 1)
        #expect(matrix.count(truth: .background, predicted: .lesion(.whitehead)) == 1)
        #expect(matrix.count(truth: .lesion(.nodule), predicted: .background) == 1)
        #expect(matrix.count(truth: .lesion(.papule), predicted: .lesion(.papule)) == 0)
    }

    @Test("Precision, recall and F1; undefined when nothing was predicted or labelled")
    func tallyScores() {
        let tally = Tally(truePositives: 6, falsePositives: 2, falseNegatives: 4)
        #expect(tally.precision == 0.75)
        #expect(tally.recall == 0.6)
        #expect(abs((tally.f1 ?? 0) - 2 * 0.75 * 0.6 / 1.35) < 1e-9)
        #expect(Tally(truePositives: 0, falsePositives: 0, falseNegatives: 3).precision == nil)
        #expect(Tally(truePositives: 0, falsePositives: 0, falseNegatives: 0).recall == nil)
    }
}

@Suite("Benchmark evaluation")
struct EvaluationTests {
    private let face = ImageRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)

    private func photo(
        _ file: String, subject: String = "S1", session: String = "a", angle: CaptureAngle = .front,
        fitzpatrick: String = "IV", predictions: [RawDetection], truth: [LabelBox]?
    ) -> PhotoResult {
        PhotoResult(
            meta: SampleMeta(file: file, subjectID: subject, sessionID: session, angle: angle,
                             fitzpatrick: fitzpatrick, lighting: "indoor"),
            imageSize: size, face: face, predictions: predictions, truth: truth, seconds: 0.5
        )
    }

    @Test("Small-object recall counts labels smaller than 1% of the face crop")
    func smallObjects() {
        // Face crop side = 0.6 * 1000 * 1.4 = 840 px → small means under 8.4 px.
        let centred = RawDetection(type: .blackhead, confidence: 0.9, box: ImageRect(x: 0.4975, y: 0.4975, width: 0.01, height: 0.01))
        let result = photo("a", predictions: [centred], truth: [
            LabelBox(type: .blackhead, box: box(0.5, 0.5, 0.005)),   // 5 px, found
            LabelBox(type: .whitehead, box: box(0.3, 0.3, 0.005)),   // 5 px, missed
            LabelBox(type: .papule, box: box(0.6, 0.6, 0.02)),       // 20 px, not small
        ])
        let small = Evaluation.smallObjects([result])
        #expect(small.labels == 2)
        #expect(small.recall == 0.5)
    }

    @Test("Count error per photo and per zone")
    func countError() {
        let result = photo("a", predictions: [prediction(.papule, 0.5, 0.5), prediction(.papule, 0.45, 0.45)],
                           truth: [truth(.papule, 0.5, 0.5)])
        let counts = Evaluation.countErrors([result])
        #expect(counts.photoTotalMAE == 1)
        #expect(counts.perClassMAE["papules"] == 1)
        #expect(counts.perZoneMAE["nose"] == 1)
    }

    @Test("Breakout index error and band accuracy per scan, from labelled angles only")
    func indexError() {
        let front = photo("a_front", predictions: [prediction(.nodule, 0.5, 0.7)], truth: [truth(.papule, 0.5, 0.7)])
        let unlabelled = photo("a_left", angle: .left, predictions: [prediction(.nodule, 0.3, 0.5)], truth: nil)
        let scans = Evaluation.scanErrors([front, unlabelled])
        #expect(scans.scans == 1)
        #expect(scans.indexMAE == 2)               // nodule 4 vs papule 2
        #expect(scans.groupedIndexMAE == 2)        // confident nodule 4 vs inflamed 2
        #expect(scans.bandAccuracy == 1)           // both "mild"
    }

    @Test("Consistency across a subject's repeat sessions uses every photo, labelled or not")
    func consistency() {
        let results = [
            photo("s1", session: "1", predictions: [prediction(.papule, 0.5, 0.7)], truth: nil),        // 2, mild
            photo("s2", session: "2", predictions: [prediction(.papule, 0.5, 0.7)], truth: nil),        // 2, mild
            photo("s3", session: "3", predictions: (0..<10).map { prediction(.papule, 0.3 + Double($0) * 0.03, 0.7) },
                  truth: nil),                                                                          // 20, active
            photo("t1", subject: "S2", session: "x", predictions: [], truth: nil),                      // one session only
        ]
        let consistency = Evaluation.consistency(results)
        #expect(consistency.subjects == 1)
        #expect(abs(consistency.meanBandAgreement - 2.0 / 3.0) < 1e-9)
        #expect(consistency.subjectsWithFullAgreement == 0)
        #expect((consistency.meanIndexCV ?? 0) > 0.9)
    }

    @Test("All-zero repeat sessions are perfectly consistent")
    func zeroConsistency() {
        let results = [
            photo("s1", session: "1", predictions: [], truth: nil),
            photo("s2", session: "2", predictions: [], truth: nil),
        ]
        let consistency = Evaluation.consistency(results)
        #expect(consistency.meanIndexCV == 0)
        #expect(consistency.meanBandAgreement == 1)
    }

    @Test("Slices by skin tone report each group separately; blank groups are 'unknown'")
    func slices() {
        let results = [
            photo("a", fitzpatrick: "II", predictions: [prediction(.papule, 0.5, 0.5)], truth: [truth(.papule, 0.5, 0.5)]),
            photo("b", fitzpatrick: "V", predictions: [], truth: [truth(.papule, 0.5, 0.5)]),
            photo("c", fitzpatrick: "", predictions: [], truth: []),
        ]
        let slices = Evaluation.slices(results, dimension: .fitzpatrick)
        #expect(slices.map(\.value) == ["II", "V", "unknown"])
        #expect(slices[0].spots.recall == 1)
        #expect(slices[1].spots.recall == 0)
    }

    @Test("Device parity compares what the phone counted with what the bench counts")
    func parity() {
        let results = [photo("a_front", predictions: [prediction(.papule, 0.5, 0.7, 0.8)], truth: nil)]
        let device = ["a_front": [prediction(.papule, 0.5, 0.7, 0.78), prediction(.whitehead, 0.3, 0.6)]]
        let parity = Evaluation.parity(results, device: device)
        #expect(parity?.files == 1)
        #expect(parity?.deviceDetections == 2)
        #expect(parity?.matched == 1)
        #expect(parity?.meanAbsCountDifference == 1)
        #expect(abs((parity?.maxConfidenceDifference ?? 0) - 0.02) < 1e-9)
        #expect(Evaluation.parity(results, device: [:]) == nil)
    }

    @Test("A full report renders Markdown with every section and no file names")
    func report() throws {
        let results = [
            photo("secret_name_front", predictions: [prediction(.papule, 0.5, 0.5)], truth: [truth(.papule, 0.5, 0.5)]),
            photo("secret_name_s2", session: "b", predictions: [], truth: nil),
        ]
        let report = Evaluation.report(
            results: results, variant: "baseline", date: "2026-11-25", model: "acneObj28200",
            configuration: .baseline, modelConfidenceFloor: nil, device: [:]
        )
        let markdown = ReportRenderer.markdown(report)
        for heading in ["Per class", "Spots found", "Small spots", "Confusion", "Counts", "Consistency",
                        "Fitzpatrick", "Lighting", "Timing"] {
            #expect(markdown.contains(heading), "missing section \(heading)")
        }
        #expect(!markdown.contains("secret_name"))
        #expect(!markdown.contains("no face found"), "every photo had a face")
        #expect(report.dataset.photosWithFace == 2)
        let json = try ReportRenderer.json(report)
        #expect(!json.isEmpty)
        #expect(String(decoding: json, as: UTF8.self).contains("\"variant\""))
    }
}
