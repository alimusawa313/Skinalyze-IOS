import Foundation

/// Converts a legacy base64 `Result` snapshot into a `ScanDraft`. Pure and side-effect free:
/// it never writes to the legacy record, so migration can be retried safely.
public enum LegacyScanConverter {
    public static let legacyModelVersion = "acneObj28200-legacy"

    public static func makeDraft(from snapshot: LegacyScanSnapshot) throws -> ScanDraft {
        let captures = zip(CaptureAngle.legacyOrder, snapshot.imagesBase64).compactMap { angle, base64 in
            base64
                .flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
                .flatMap(ImageEncoding.compressedData(fromImageData:))
                .map { CaptureDraft(angle: angle, imageData: $0) }
        }
        let clampedScore = min(max(snapshot.legacyScore, LegacySeverityScale.range.lowerBound),
                               LegacySeverityScale.range.upperBound)
        return ScanDraft(
            createdAt: snapshot.date,
            captureMode: .legacy,
            modelVersion: legacyModelVersion,
            counts: LesionCounts(legacyDictionary: snapshot.acneCounts),
            legacyScore: clampedScore,
            captures: captures,
            detections: [],
            productIDs: snapshot.productIDs.nonEmpty,
            legacyResultID: snapshot.id
        )
    }
}

public enum LegacyMigrationPlan {
    /// Legacy record IDs that still need migrating, preserving input order.
    public static func pending(legacyIDs: [UUID], alreadyMigrated: Set<UUID>) -> [UUID] {
        legacyIDs.filter { !alreadyMigrated.contains($0) }
    }
}
