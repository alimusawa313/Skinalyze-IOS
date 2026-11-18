import Foundation
import SwiftData
import SkinalyzeKit

/// Copies legacy base64 `Result` records into the new `ScanSession` models on launch.
///
/// Safe to run every launch: `ScanStore.importLegacy` skips records that were already migrated, and legacy records are
/// never modified. Work happens in small batches on the `ScanStore` actor so image re-encoding stays off the main thread.
@MainActor
enum LegacyMigrationRunner {
    static let batchSize = 5

    static func run(container: ModelContainer) async {
        let store = ScanStore(modelContainer: container)
        do {
            let migrated = try await store.migratedLegacyIDs()
            let legacy = try container.mainContext.fetch(FetchDescriptor<Result>())
            let pending = legacy.filter { !migrated.contains($0.id) }
            guard !pending.isEmpty else { return }

            AppPersistence.logger.info("Migrating \(pending.count) legacy scans")
            for start in stride(from: 0, to: pending.count, by: batchSize) {
                let batch = pending[start..<min(start + batchSize, pending.count)].map(snapshot(of:))
                try await store.importLegacy(batch)
            }
            AppPersistence.logger.info("Legacy migration finished")
        } catch {
            // Non-fatal: legacy data is untouched, so the next launch retries.
            AppPersistence.logger.error("Legacy migration failed: \(error.localizedDescription)")
        }
    }

    static func snapshot(of result: Result) -> LegacyScanSnapshot {
        LegacyScanSnapshot(
            id: result.id,
            date: result.currentDate,
            imagesBase64: [result.image1, result.image2, result.image3],
            acneCounts: result.acneCounts,
            legacyScore: result.geaScale,
            productIDs: LegacyProductIDs(
                cleanser: result.cleanserUsedID,
                toner: result.tonerUsedID,
                moisturizer: result.moisturizerUsedID,
                sunscreen: result.sunscreenUsedID
            )
        )
    }
}
