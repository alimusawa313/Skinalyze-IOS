import Foundation
import SwiftData
import Testing
@testable import SkinalyzeKit

@Suite("Scan persistence models")
@MainActor
struct ScanModelTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(SkinalyzeSchema.models), configurations: configuration)
        return ModelContext(container)
    }

    private func draft(detections: [DetectionDraft] = []) throws -> ScanDraft {
        let jpeg = try #require(Data(base64Encoded: Fixtures.tinyJPEGBase64))
        return ScanDraft(
            createdAt: Date(timeIntervalSince1970: 1_730_000_000),
            captureMode: .camera2D,
            modelVersion: "acneObj28200",
            counts: LesionCounts(modelLabels: ["papules", "nodules"]),
            legacyScore: 4,
            captures: [CaptureDraft(angle: .front, imageData: jpeg)],
            detections: detections,
            productIDs: [12],
            legacyResultID: nil
        )
    }

    @Test("Inserting a draft stores the session, its captures, detections and counts")
    func insertDraft() throws {
        let context = try makeContext()
        let box = ImageRect(x: 0.1, y: 0.2, width: 0.05, height: 0.05)
        let session = ScanSession.insert(
            try draft(detections: [DetectionDraft(type: .papule, confidence: 0.8, box: box, captureAngle: .front)]),
            into: context
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ScanSession>())
        #expect(fetched.count == 1)
        #expect(session.counts[.papule] == 1)
        #expect(session.counts[.nodule] == 1)
        #expect(session.legacyScore == 4)
        #expect(session.sortedCaptures.map(\.angle) == [.front])
        #expect(session.allDetections.first?.box == box)
        #expect(session.allDetections.first?.lesionType == .papule)
        #expect(session.productIDs == [12])
    }

    @Test("Deleting a session cascades to captures and detections")
    func cascadeDelete() throws {
        let context = try makeContext()
        let box = ImageRect(x: 0, y: 0, width: 0.1, height: 0.1)
        let session = ScanSession.insert(
            try draft(detections: [DetectionDraft(type: .pustule, confidence: 0.6, box: box, captureAngle: .front)]),
            into: context
        )
        try context.save()

        context.delete(session)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ScanSession>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ScanCapture>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StoredDetection>()) == 0)
    }

    @Test("Zones, breakout index and band are derived from stored detections")
    func zonesAndScore() throws {
        let context = try makeContext()
        let box = ImageRect(x: 0, y: 0, width: 0.1, height: 0.1)
        let session = ScanSession.insert(
            try draft(detections: [
                DetectionDraft(type: .pustule, confidence: 0.9, box: box, captureAngle: .front, zone: .chin),
                DetectionDraft(type: .papule, confidence: 0.9, box: box, captureAngle: .front, zone: .chin),
                DetectionDraft(type: .darkSpot, confidence: 0.9, box: box, captureAngle: .front, zone: .forehead),
            ]),
            into: context
        )
        #expect(session.allDetections.first?.zone == .chin)
        #expect(session.zoneIndex(.chin) == 5)       // pustule 3 + papule 2
        #expect(session.zoneIndex(.forehead) == 0)   // dark spots are marks, not breakouts
        #expect(session.hasZoneData)
        #expect(session.breakoutIndex == BreakoutIndex.index(for: session.counts))
        #expect(session.band == BreakoutBand.classify(index: session.breakoutIndex))
    }

    @Test("Detections can be filtered by lesion type and capture")
    func filtering() throws {
        let context = try makeContext()
        let box = ImageRect(x: 0, y: 0, width: 0.1, height: 0.1)
        let session = ScanSession.insert(
            try draft(detections: [
                DetectionDraft(type: .papule, confidence: 0.9, box: box, captureAngle: .front),
                DetectionDraft(type: .darkSpot, confidence: 0.7, box: box, captureAngle: .left),
            ]),
            into: context
        )
        #expect(session.detections(for: .front, types: [.papule]).count == 1)
        #expect(session.detections(for: .front, types: [.darkSpot]).isEmpty)
        #expect(session.detections(for: .left, types: Set(LesionType.allCases)).count == 1)
    }
}

@Suite("Store location")
struct StoreLocationTests {
    @Test("The store stays at the pre-App-Group default location so existing users keep their history")
    func pinnedLocation() {
        let url = SkinalyzeSchema.legacyStoreURL
        #expect(url.lastPathComponent == "default.store")
        #expect(url.deletingLastPathComponent() == URL.applicationSupportDirectory)
    }
}
