import Foundation
import SwiftData

// CloudKit-compatible models (sync is live in production — schema changes must be ADDITIVE ONLY):
// every property has a default or is optional, relationships are optional, no unique constraints.

@Model
public final class ScanSession {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var captureModeRaw: String = CaptureMode.camera2D.rawValue
    public var modelVersion: String = ""
    public var legacyScore: Int = 0
    public var blackheadCount: Int = 0
    public var whiteheadCount: Int = 0
    public var papuleCount: Int = 0
    public var pustuleCount: Int = 0
    public var noduleCount: Int = 0
    public var darkSpotCount: Int = 0
    public var productIDs: [Int] = []
    public var notes: String = ""
    /// `Result.id` this session was migrated from; `nil` for scans created by the new pipeline.
    public var legacyResultID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \ScanCapture.session)
    public var captures: [ScanCapture]? = []

    @Relationship(deleteRule: .cascade, inverse: \StoredDetection.session)
    public var detections: [StoredDetection]? = []

    /// Optional 3D face (Face ID iPhones only). Added after first release — optional for CloudKit.
    @Relationship(deleteRule: .cascade)
    public var faceMesh: FaceMeshRecord?

    public init() {}

    public var captureMode: CaptureMode { CaptureMode(rawValue: captureModeRaw) ?? .camera2D }

    public var counts: LesionCounts {
        LesionCounts([
            .blackhead: blackheadCount, .whitehead: whiteheadCount, .papule: papuleCount,
            .pustule: pustuleCount, .nodule: noduleCount, .darkSpot: darkSpotCount,
        ])
    }

    /// Captures in front → right → left order.
    public var sortedCaptures: [ScanCapture] {
        (captures ?? []).sorted { $0.order < $1.order }
    }

    public var allDetections: [StoredDetection] { detections ?? [] }

    /// Weighted breakout score (dark spots excluded) — see `BreakoutIndex`.
    public var breakoutIndex: Int { BreakoutIndex.index(for: counts) }

    public var band: BreakoutBand { BreakoutBand.classify(index: breakoutIndex) }

    /// `true` when detections carry face zones (scans from the new pipeline).
    public var hasZoneData: Bool { allDetections.contains { $0.zone != nil } }

    /// Weighted breakout score for one face zone.
    public func zoneIndex(_ zone: FaceZone) -> Int {
        allDetections
            .filter { $0.zone == zone }
            .compactMap(\.lesionType)
            .reduce(0) { $0 + BreakoutIndex.weight(of: $1) }
    }

    public func detections(for angle: CaptureAngle, types: Set<LesionType>) -> [StoredDetection] {
        allDetections.filter { $0.angle == angle && $0.lesionType.map(types.contains) == true }
    }

    /// Inserts a fully-formed session (with captures and detections) built from `draft`.
    @discardableResult
    public static func insert(_ draft: ScanDraft, into context: ModelContext) -> ScanSession {
        let session = ScanSession()
        session.createdAt = draft.createdAt
        session.captureModeRaw = draft.captureMode.rawValue
        session.modelVersion = draft.modelVersion
        session.legacyScore = draft.legacyScore
        session.blackheadCount = draft.counts[.blackhead]
        session.whiteheadCount = draft.counts[.whitehead]
        session.papuleCount = draft.counts[.papule]
        session.pustuleCount = draft.counts[.pustule]
        session.noduleCount = draft.counts[.nodule]
        session.darkSpotCount = draft.counts[.darkSpot]
        session.productIDs = draft.productIDs
        session.legacyResultID = draft.legacyResultID
        context.insert(session)

        session.captures = draft.captures.enumerated().map { index, capture in
            let model = ScanCapture(angle: capture.angle, order: index, imageData: capture.imageData)
            context.insert(model)
            return model
        }
        session.detections = draft.detections.map { detection in
            let model = StoredDetection(detection)
            context.insert(model)
            return model
        }
        return session
    }
}

@Model
public final class ScanCapture {
    public var id: UUID = UUID()
    public var angleRaw: String = CaptureAngle.front.rawValue
    public var order: Int = 0
    @Attribute(.externalStorage) public var imageData: Data?
    public var session: ScanSession?

    public init(angle: CaptureAngle, order: Int, imageData: Data?) {
        angleRaw = angle.rawValue
        self.order = order
        self.imageData = imageData
    }

    public var angle: CaptureAngle { CaptureAngle(rawValue: angleRaw) ?? .front }
}

@Model
public final class StoredDetection {
    public var id: UUID = UUID()
    public var typeRaw: String = ""
    public var confidence: Double = 0
    public var x: Double = 0
    public var y: Double = 0
    public var width: Double = 0
    public var height: Double = 0
    public var angleRaw: String = CaptureAngle.front.rawValue
    /// Added after first release — optional so the CloudKit schema change stays additive.
    public var zoneRaw: String?
    public var session: ScanSession?

    public init(_ draft: DetectionDraft) {
        typeRaw = draft.type.rawValue
        confidence = draft.confidence
        x = draft.box.x
        y = draft.box.y
        width = draft.box.width
        height = draft.box.height
        angleRaw = draft.captureAngle.rawValue
        zoneRaw = draft.zone?.rawValue
    }

    public var zone: FaceZone? { zoneRaw.flatMap(FaceZone.init(rawValue:)) }
    public var lesionType: LesionType? { LesionType(rawValue: typeRaw) }
    public var angle: CaptureAngle { CaptureAngle(rawValue: angleRaw) ?? .front }
    public var box: ImageRect { ImageRect(x: x, y: y, width: width, height: height) }
}

public enum SkinalyzeSchema {
    /// New models owned by SkinalyzeKit. The app adds the legacy `Result` model to its schema.
    /// Additive only: `EngagementRecord` (synced streaks and rewards) was added after the first CloudKit release.
    public static let models: [any PersistentModel.Type] = [ScanSession.self, ScanCapture.self, StoredDetection.self,
                                                            FaceMeshRecord.self, EngagementRecord.self]

    /// SwiftData's pre-App-Group default store location. Pinned explicitly: once an App Group entitlement exists,
    /// SwiftData's *default* moves into the group container, which would make existing history disappear.
    /// Moving the store into the App Group is a separate, verified copy step (PHASES.md 0.4).
    public static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }
}
