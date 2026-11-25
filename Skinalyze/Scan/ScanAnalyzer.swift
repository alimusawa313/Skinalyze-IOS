import CoreML
import OSLog
import UIKit
import Vision
import SkinalyzeKit

/// Runs the acne model. Loads it **once** and works off the main actor (the old code reloaded the 31 MB model per
/// photo and ran it synchronously on the main thread). Everything around the Core ML call lives in SkinalyzeKit's
/// `DetectionPipeline`, which `Tools/DetectorBench` runs too (ML-PLAN M0.1).
actor AcneDetector {
    static let shared = AcneDetector()
    static let modelVersion = "acneObj28200"

    enum DetectorError: Error {
        case modelUnavailable
    }

    private let pipeline = DetectionPipeline(configuration: .shipping)
    private var model: VNCoreMLModel?

    private func loadedModel() throws -> VNCoreMLModel {
        if let model { return model }
        do {
            let loaded = try VNCoreMLModel(for: acneObj28200(configuration: MLModelConfiguration()).model)
            model = loaded
            return loaded
        } catch {
            throw DetectorError.modelUnavailable
        }
    }

    /// Detects lesions in an upright image and returns boxes in **full-image** normalized coordinates.
    func detect(in image: CGImage, face: ImageRect?) throws -> [RawDetection] {
        let model = try loadedModel()
        let mask = pipeline.configuration.masksLandmarks ? Self.skinMask(in: image, face: face) : nil
        return try pipeline.detect(in: image, face: face, mask: mask) { tile in
            try CoreMLDetections.run(model, on: tile)
        }
    }

    /// The mask is an accuracy aid: if Vision can't find landmarks, the scan still runs unmasked.
    private static func skinMask(in image: CGImage, face: ImageRect?) -> SkinMask? {
        guard let face else { return nil }
        do {
            return try VisionFaceAnalysis.landmarks(in: image, face: face)
                .map { SkinMaskBuilder.mask(for: $0, face: face) }
        } catch {
            ScanAnalyzer.logger.error("Face landmarks failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Maps a crop-normalized Vision box (bottom-left origin) to full-image normalized coordinates.
    static func toImageSpace(_ box: CGRect, crop: CGRect, imageSize: CGSize) -> ImageRect {
        ImageSpace.toImage(
            ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height),
            region: crop,
            imageSize: imageSize
        )
    }
}

/// Turns three captured photos into a `ScanDraft`: face crop → detection → zones → each lesion counted once.
enum ScanAnalyzer {
    static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Analysis")

    struct Capture: Sendable {
        let angle: CaptureAngle
        let image: CGImage
        let encoded: Data
    }

    /// Prepares an upright, encoded copy of a captured photo (main-actor safe; UIKit drawing).
    static func prepare(_ image: UIImage, angle: CaptureAngle) -> Capture? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = upright.cgImage, let encoded = ImageEncoding.compressedData(from: cgImage) else {
            return nil
        }
        return Capture(angle: angle, image: cgImage, encoded: encoded)
    }

    struct Analysis: Sendable {
        let draft: ScanDraft
        /// Face box in the front photo — used to place pins on the 3D mesh.
        let frontFace: ImageRect?
    }

    static func analyze(_ captures: [Capture], productIDs: [Int], date: Date = .now) async throws -> Analysis {
        var zoned: [ZonedDetection] = []
        var frontFace: ImageRect?
        for capture in captures {
            let face = faceBounds(in: capture.image)
            if capture.angle == .front { frontFace = face }
            let detections = try await AcneDetector.shared.detect(in: capture.image, face: face)
            zoned += detections.compactMap { detection in
                guard let face,
                      let zone = FaceZoneMapper.zone(of: detection.box.center, face: face, angle: capture.angle)
                else { return nil }
                return ZonedDetection(detection: detection, angle: capture.angle, zone: zone)
            }
        }
        let counted = ScanAggregator.counted(zoned, available: Set(captures.map(\.angle)))
        let counts = ScanAggregator.counts(of: counted)
        let draft = ScanDraft(
            createdAt: date,
            captureMode: .camera2D,
            modelVersion: AcneDetector.modelVersion,
            pipelineVersion: DetectionPipeline.shippingVersion,
            counts: counts,
            legacyScore: LegacySeverityScale.score(for: counts),
            captures: captures.map { CaptureDraft(angle: $0.angle, imageData: $0.encoded) },
            detections: counted.map {
                DetectionDraft(type: $0.detection.type, confidence: $0.detection.confidence,
                               box: $0.detection.box, captureAngle: $0.angle, zone: $0.zone)
            },
            productIDs: productIDs.filter { $0 > 0 },
            legacyResultID: nil
        )
        return Analysis(draft: draft, frontFace: frontFace)
    }

    static func faceBounds(in image: CGImage) -> ImageRect? {
        do {
            return try VisionFaceAnalysis.largestFace(in: image)
        } catch {
            logger.error("Face detection on capture failed: \(error.localizedDescription)")
            return nil
        }
    }
}
