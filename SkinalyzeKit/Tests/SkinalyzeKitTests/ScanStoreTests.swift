import Foundation
import SwiftData
import Testing
@testable import SkinalyzeKit

@Suite("ScanStore (background actor)")
struct ScanStoreTests {
    private func makeStore() throws -> (ScanStore, ModelContainer) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(SkinalyzeSchema.models), configurations: configuration)
        return (ScanStore(modelContainer: container), container)
    }

    private func snapshot(id: UUID = UUID()) -> LegacyScanSnapshot {
        LegacyScanSnapshot(
            id: id, date: Date(timeIntervalSince1970: 1_730_000_000),
            imagesBase64: [Fixtures.tinyJPEGBase64, nil, nil],
            acneCounts: ["whiteheads": 4], legacyScore: 1,
            productIDs: LegacyProductIDs(cleanser: 1, toner: 0, moisturizer: 0, sunscreen: 0)
        )
    }

    @Test("Importing legacy scans is idempotent — running twice never duplicates history")
    func idempotentImport() async throws {
        let (store, _) = try makeStore()
        let batch = [snapshot(), snapshot()]

        let first = try await store.importLegacy(batch)
        let second = try await store.importLegacy(batch)

        #expect(first == 2)
        #expect(second == 0)
        #expect(try await store.sessionCount() == 2)
        #expect(try await store.migratedLegacyIDs() == Set(batch.map(\.id)))
    }

    @Test("Imported sessions keep counts, score, date and images")
    @MainActor
    func importedContent() async throws {
        let (store, container) = try makeStore()
        let source = snapshot()
        _ = try await store.importLegacy([source])

        let session = try #require(try container.mainContext.fetch(FetchDescriptor<ScanSession>()).first)
        #expect(session.legacyResultID == source.id)
        #expect(session.counts[.whitehead] == 4)
        #expect(session.legacyScore == 1)
        #expect(session.captureMode == .legacy)
        #expect(session.sortedCaptures.count == 1)
        #expect(session.productIDs == [1])
    }

    @Test("Saving a new draft persists it and returns its identifier")
    func saveDraft() async throws {
        let (store, _) = try makeStore()
        let draft = ScanDraft(
            createdAt: .now, captureMode: .camera2D, modelVersion: "acneObj28200",
            counts: LesionCounts(modelLabels: ["papules"]), legacyScore: 1,
            captures: [], detections: [], productIDs: [], legacyResultID: nil
        )
        _ = try await store.save(draft)
        #expect(try await store.sessionCount() == 1)
    }
}
