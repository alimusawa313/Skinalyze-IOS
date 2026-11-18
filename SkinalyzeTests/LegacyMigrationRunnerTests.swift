import SwiftData
import Testing
import UIKit
import SkinalyzeKit
@testable import Skinalyze

@Suite("Legacy migration (app-hosted, real Result model)")
@MainActor
struct LegacyMigrationRunnerTests {
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: AppPersistence.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        return try ModelContainer(for: AppPersistence.schema, configurations: configuration)
    }

    /// Exactly how the shipped app stored photos: JPEG quality 1.0, base64.
    private func legacyBase64Photo() -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 16)).image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 16))
        }
        return image.jpegData(compressionQuality: 1)!.base64EncodedString()
    }

    private func insertLegacyResult(into context: ModelContext, counts: [String: Int] = ["papules": 3]) -> Result {
        let photo = legacyBase64Photo()
        let result = Result(
            images: [photo, photo, photo],
            analyzedImages: [photo, photo, photo],
            acneCounts: counts,
            geaScale: 1,
            currentDate: Date(timeIntervalSince1970: 1_731_000_000),
            boundingBoxImages: [photo],
            cleanserUsedID: 18
        )
        context.insert(result)
        return result
    }

    @Test("Migrates every legacy scan once, with photos, counts, score, date and products")
    func migratesOnce() async throws {
        let container = try makeContainer()
        let legacy = insertLegacyResult(into: container.mainContext)
        try container.mainContext.save()

        await LegacyMigrationRunner.run(container: container)
        await LegacyMigrationRunner.run(container: container) // second launch: must not duplicate

        let sessions = try container.mainContext.fetch(FetchDescriptor<ScanSession>())
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.legacyResultID == legacy.id)
        #expect(session.counts[.papule] == 3)
        #expect(session.legacyScore == 1)
        #expect(session.createdAt == legacy.currentDate)
        #expect(session.uiImages.count == 3)
        #expect(session.productIDs == [18])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Result>()) == 1, "legacy data is never removed by migration")
    }

    @Test("Deleting a migrated scan also deletes its legacy record so it can't come back")
    func deleteDoesNotResurrect() async throws {
        let container = try makeContainer()
        _ = insertLegacyResult(into: container.mainContext)
        try container.mainContext.save()
        await LegacyMigrationRunner.run(container: container)

        let session = try #require(try container.mainContext.fetch(FetchDescriptor<ScanSession>()).first)
        AppPersistence.delete(session, in: container.mainContext)
        await LegacyMigrationRunner.run(container: container)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<ScanSession>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Result>()) == 0)
    }

    @Test("Blackhead-only legacy scans keep their stored score (no silent re-scoring)")
    func keepsStoredScore() async throws {
        let container = try makeContainer()
        _ = insertLegacyResult(into: container.mainContext, counts: ["blackheads": 12])
        try container.mainContext.save()
        await LegacyMigrationRunner.run(container: container)

        let session = try #require(try container.mainContext.fetch(FetchDescriptor<ScanSession>()).first)
        #expect(session.legacyScore == 1, "the score the user saw is preserved")
        #expect(session.counts[.blackhead] == 12)
    }
}

@Suite("Detector coordinate mapping")
struct AcneDetectorMappingTests {
    @Test("A box in a face crop maps back to full-image normalized coordinates (bottom-left origin)")
    func cropToImage() {
        // 1000×2000 image; crop is the 600×600 square starting at (200, 700) in top-left pixel coordinates.
        let crop = CGRect(x: 200, y: 700, width: 600, height: 600)
        let mapped = AcneDetector.toImageSpace(
            CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1), crop: crop, imageSize: CGSize(width: 1000, height: 2000)
        )
        #expect(abs(mapped.x - 0.5) < 1e-9)              // (200 + 300) / 1000
        #expect(abs(mapped.y - 0.5) < 1e-9)              // crop bottom at 700 px from image bottom; (700 + 300) / 2000
        #expect(abs(mapped.width - 0.06) < 1e-9)
        #expect(abs(mapped.height - 0.03) < 1e-9)
    }
}

@Suite("Detection overlay")
struct DetectionOverlayRendererTests {
    @Test("Vision's bottom-left normalized boxes map to top-left pixel rects")
    func flipsCoordinates() {
        let rect = DetectionOverlayRenderer.rect(
            for: ImageRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            in: CGSize(width: 100, height: 200)
        )
        #expect(rect == CGRect(x: 10, y: 80, width: 30, height: 80))
    }
}
