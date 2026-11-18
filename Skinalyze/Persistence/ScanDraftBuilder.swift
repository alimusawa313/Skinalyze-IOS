import UIKit
import Vision
import SkinalyzeKit

/// Builds a `ScanDraft` from a finished analysis so a scan is stored once, as data (photos + detections),
/// instead of the old ~9 full-quality base64 JPEGs.
enum ScanDraftBuilder {
    static let modelVersion = "acneObj28200"

    static func makeDraft(
        images: [UIImage],
        detectionsPerImage: [[VNRecognizedObjectObservation]],
        counts: [String: Int],
        legacyScore: Int,
        date: Date,
        productIDs: [Int]
    ) -> ScanDraft {
        let angles = CaptureAngle.legacyOrder
        let captures = zip(angles, images).compactMap { angle, image in
            encodedData(for: image).map { CaptureDraft(angle: angle, imageData: $0) }
        }
        let detections = zip(angles, detectionsPerImage).flatMap { angle, observations in
            observations.compactMap { detectionDraft(from: $0, angle: angle) }
        }
        return ScanDraft(
            createdAt: date,
            captureMode: .camera2D,
            modelVersion: modelVersion,
            counts: LesionCounts(legacyDictionary: counts),
            legacyScore: legacyScore,
            captures: captures,
            detections: detections,
            productIDs: productIDs.filter { $0 > 0 },
            legacyResultID: nil
        )
    }

    /// JPEG keeps the UIImage's orientation as EXIF; `ImageEncoding` then re-encodes compactly with metadata intact.
    static func encodedData(for image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.95).flatMap(ImageEncoding.compressedData(fromImageData:))
    }

    static func detectionDraft(from observation: VNRecognizedObjectObservation, angle: CaptureAngle) -> DetectionDraft? {
        guard let label = observation.labels.first, let type = LesionType(modelLabel: label.identifier) else {
            return nil
        }
        let box = observation.boundingBox
        return DetectionDraft(
            type: type,
            confidence: Double(label.confidence),
            box: NormalizedRect(x: box.minX, y: box.minY, width: box.width, height: box.height),
            captureAngle: angle
        )
    }
}
