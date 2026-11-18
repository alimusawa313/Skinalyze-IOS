import CoreML
import OSLog
import UIKit
import Vision
import SkinalyzeKit

/// Runs the acne model. Loads it **once** and works off the main actor (the old code reloaded the 31 MB model per
/// photo and ran it synchronously on the main thread).
actor AcneDetector {
    static let shared = AcneDetector()
    static let modelVersion = "acneObj28200"

    enum DetectorError: Error {
        case modelUnavailable
        case invalidImage
    }

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

    /// Detects lesions in an upright image. Runs on a square face crop at native resolution (`.scaleFill` on a square
    /// input means no distortion) and returns boxes in **full-image** normalized coordinates, filtered with a confidence
    /// threshold and cross-class NMS.
    func detect(in image: CGImage, face: ImageRect?) throws -> [RawDetection] {
        let imageSize = CGSize(width: image.width, height: image.height)
        let cropRect = face.map { FaceCrop.squarePixelRect(face: $0, imageSize: imageSize) }
            ?? CGRect(origin: .zero, size: imageSize)
        guard let crop = image.cropping(to: cropRect.integral) else { throw DetectorError.invalidImage }

        let request = VNCoreMLRequest(model: try loadedModel())
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: crop, orientation: .up).perform([request])
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []

        let raw = observations.compactMap { observation -> RawDetection? in
            guard let label = observation.labels.first, let type = LesionType(modelLabel: label.identifier) else {
                return nil
            }
            return RawDetection(
                type: type,
                confidence: Double(label.confidence),
                box: Self.toImageSpace(observation.boundingBox, crop: cropRect.integral, imageSize: imageSize)
            )
        }
        return DetectionFilter.filter(raw)
    }

    /// Maps a crop-normalized Vision box (bottom-left origin) to full-image normalized coordinates.
    static func toImageSpace(_ box: CGRect, crop: CGRect, imageSize: CGSize) -> ImageRect {
        let cropBottom = imageSize.height - crop.maxY // crop's bottom edge, measured from the image bottom
        return ImageRect(
            x: (crop.minX + box.minX * crop.width) / imageSize.width,
            y: (cropBottom + box.minY * crop.height) / imageSize.height,
            width: box.width * crop.width / imageSize.width,
            height: box.height * crop.height / imageSize.height
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

    static func analyze(_ captures: [Capture], productIDs: [Int], date: Date = .now) async throws -> ScanDraft {
        var zoned: [ZonedDetection] = []
        for capture in captures {
            let face = faceBounds(in: capture.image)
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
        return ScanDraft(
            createdAt: date,
            captureMode: .camera2D,
            modelVersion: AcneDetector.modelVersion,
            counts: counts,
            legacyScore: LegacySeverityScale.score(for: counts),
            captures: captures.map { CaptureDraft(angle: $0.angle, imageData: $0.encoded) },
            detections: counted.map {
                DetectionDraft(type: $0.detection.type, confidence: $0.detection.confidence,
                               box: $0.detection.box, captureAngle: $0.angle)
            },
            productIDs: productIDs.filter { $0 > 0 },
            legacyResultID: nil
        )
    }

    static func faceBounds(in image: CGImage) -> ImageRect? {
        let request = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        } catch {
            logger.error("Face detection on capture failed: \(error.localizedDescription)")
            return nil
        }
        guard let box = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width })?.boundingBox else {
            return nil
        }
        return ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height)
    }
}
