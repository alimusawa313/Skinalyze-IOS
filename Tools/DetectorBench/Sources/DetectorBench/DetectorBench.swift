import BenchCore
import CoreML
import Foundation
import ImageIO
import SkinalyzeKit
import Vision

/// Runs the app's detection pipeline over a labelled photo set and writes a Markdown + JSON report
/// (docs/redesign/ML-PLAN.md M0.4). See `BenchOptions.usage`.
@main
struct DetectorBench {
    enum BenchError: Error, CustomStringConvertible {
        case unreadableImage(String)

        var description: String {
            switch self {
            case let .unreadableImage(name): "cannot read image \(name)"
            }
        }
    }

    static func main() async {
        do {
            try await run(try BenchOptions.parse(Array(CommandLine.arguments.dropFirst())))
        } catch let error as BenchOptions.ParseError {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(2)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ options: BenchOptions) async throws {
        let samples = try BenchDataset.load(root: options.dataURL)
        let device = try BenchDataset.deviceDetections(root: options.dataURL)
        let model = try await loadModel(options)
        let pipeline = DetectionPipeline(configuration: options.configuration)
        print("Running `\(options.variant)` on \(samples.count) photos…")

        let results = try samples.enumerated().map { index, sample in
            let result = try analyse(sample, model: model, pipeline: pipeline)
            if (index + 1) % 10 == 0 || index + 1 == samples.count { print("  \(index + 1)/\(samples.count)") }
            return result
        }

        let date = Date.now.formatted(.iso8601.year().month().day())
        let report = Evaluation.report(
            results: results, variant: options.variant, date: date,
            model: options.modelURL.deletingPathExtension().lastPathComponent,
            configuration: options.configuration, modelConfidenceFloor: options.modelConfidenceFloor, device: device
        )
        let folder = options.outputURL ?? repoBenchmarksFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = folder.appending(path: "\(date)-\(options.variant)")
        try ReportRenderer.markdown(report).write(to: base.appendingPathExtension("md"), atomically: true, encoding: .utf8)
        try ReportRenderer.json(report).write(to: base.appendingPathExtension("json"))
        print("Wrote \(base.path).md and .json")
    }

    /// `docs/redesign/benchmarks/` in the repo this tool lives in.
    static var repoBenchmarksFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DetectorBench
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // DetectorBench package
            .deletingLastPathComponent() // Tools
            .deletingLastPathComponent() // repo root
            .appending(path: "docs/redesign/benchmarks")
    }

    static func loadModel(_ options: BenchOptions) async throws -> VNCoreMLModel {
        let compiled = try await MLModel.compileModel(at: options.modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = options.cpuOnly ? .cpuOnly : .all
        let model = try VNCoreMLModel(for: try MLModel(contentsOf: compiled, configuration: configuration))
        if let floor = options.modelConfidenceFloor {
            model.featureProvider = try CoreMLDetections.thresholdInputs(
                confidence: floor, iou: options.configuration.iouThreshold
            )
        }
        return model
    }

    static func analyse(_ sample: BenchSample, model: VNCoreMLModel, pipeline: DetectionPipeline) throws -> PhotoResult {
        let image = try loadUpright(sample.imageURL)
        let clock = ContinuousClock()
        let start = clock.now
        let face = try VisionFaceAnalysis.largestFace(in: image)
        let mask = try pipeline.configuration.masksLandmarks
            ? face.flatMap { face in
                try VisionFaceAnalysis.landmarks(in: image, face: face).map { SkinMaskBuilder.mask(for: $0, face: face) }
            }
            : nil
        let predictions = try pipeline.detect(in: image, face: face, mask: mask) { tile in
            try CoreMLDetections.run(model, on: tile)
        }
        let elapsed = start.duration(to: clock.now).components
        return PhotoResult(
            meta: sample.meta,
            imageSize: CGSize(width: image.width, height: image.height),
            face: face,
            predictions: predictions,
            truth: sample.truth,
            seconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        )
    }

    /// Decodes at full size with the EXIF orientation applied, so labels drawn on the upright photo line up.
    static func loadUpright(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw BenchError.unreadableImage(url.lastPathComponent) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw BenchError.unreadableImage(url.lastPathComponent)
        }
        return image
    }
}
