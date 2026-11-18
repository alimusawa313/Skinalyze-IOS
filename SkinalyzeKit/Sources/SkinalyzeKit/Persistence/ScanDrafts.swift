import Foundation

/// Which way the head is turned for a capture, from the subject's point of view.
/// `.right` = head turned to the subject's right, so the camera sees the **left** cheek (and vice versa).
/// Legacy scans stored images in the order front, right ("Facing Right"), left.
public enum CaptureAngle: String, Codable, Sendable, CaseIterable, Hashable {
    case front
    case right
    case left

    /// Order the legacy camera flow captured images in (`Result.image1…image3`).
    public static let legacyOrder: [CaptureAngle] = [.front, .right, .left]
}

/// How a scan was captured. Trends must never silently mix incomparable modes (PLAN.md §11.2).
public enum CaptureMode: String, Codable, Sendable, Hashable {
    case trueDepth
    case camera2D
    case legacy
}

/// A rectangle in normalized image coordinates (0…1), Vision convention: origin bottom-left.
public struct ImageRect: Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DetectionDraft: Sendable, Hashable {
    public let type: LesionType
    public let confidence: Double
    public let box: ImageRect
    public let captureAngle: CaptureAngle
    /// Face zone the lesion was counted in (`nil` for legacy/unknown).
    public let zone: FaceZone?

    public init(type: LesionType, confidence: Double, box: ImageRect, captureAngle: CaptureAngle, zone: FaceZone? = nil) {
        self.type = type
        self.confidence = confidence
        self.box = box
        self.captureAngle = captureAngle
        self.zone = zone
    }
}

public struct CaptureDraft: Sendable, Hashable {
    public let angle: CaptureAngle
    public let imageData: Data

    public init(angle: CaptureAngle, imageData: Data) {
        self.angle = angle
        self.imageData = imageData
    }
}

/// Everything needed to persist one scan. Value type so it can cross actor boundaries.
public struct ScanDraft: Sendable, Hashable {
    public let createdAt: Date
    public let captureMode: CaptureMode
    public let modelVersion: String
    public let counts: LesionCounts
    public let legacyScore: Int
    public let captures: [CaptureDraft]
    public let detections: [DetectionDraft]
    public let productIDs: [Int]
    /// Set when the draft was converted from a legacy `Result`; used to make migration idempotent.
    public let legacyResultID: UUID?

    public init(
        createdAt: Date,
        captureMode: CaptureMode,
        modelVersion: String,
        counts: LesionCounts,
        legacyScore: Int,
        captures: [CaptureDraft],
        detections: [DetectionDraft],
        productIDs: [Int],
        legacyResultID: UUID?
    ) {
        self.createdAt = createdAt
        self.captureMode = captureMode
        self.modelVersion = modelVersion
        self.counts = counts
        self.legacyScore = legacyScore
        self.captures = captures
        self.detections = detections
        self.productIDs = productIDs
        self.legacyResultID = legacyResultID
    }
}

/// Product slots on a legacy `Result`. `0` means "no product".
public struct LegacyProductIDs: Sendable, Hashable {
    public let cleanser: Int
    public let toner: Int
    public let moisturizer: Int
    public let sunscreen: Int

    public init(cleanser: Int, toner: Int, moisturizer: Int, sunscreen: Int) {
        self.cleanser = cleanser
        self.toner = toner
        self.moisturizer = moisturizer
        self.sunscreen = sunscreen
    }

    public var nonEmpty: [Int] { [cleanser, toner, moisturizer, sunscreen].filter { $0 > 0 } }
}

/// A read-only copy of a legacy `Result` record, taken on the main context and handed to the migrator.
public struct LegacyScanSnapshot: Sendable, Hashable {
    public let id: UUID
    public let date: Date
    /// `Result.image1…image3` in stored order (front, right, left). `nil` when absent.
    public let imagesBase64: [String?]
    public let acneCounts: [String: Int]
    public let legacyScore: Int
    public let productIDs: LegacyProductIDs

    public init(
        id: UUID,
        date: Date,
        imagesBase64: [String?],
        acneCounts: [String: Int],
        legacyScore: Int,
        productIDs: LegacyProductIDs
    ) {
        self.id = id
        self.date = date
        self.imagesBase64 = imagesBase64
        self.acneCounts = acneCounts
        self.legacyScore = legacyScore
        self.productIDs = productIDs
    }
}
