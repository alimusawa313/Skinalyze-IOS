import Foundation
import OSLog
import SwiftData
import SkinalyzeKit

/// Builds the app's SwiftData container.
///
/// - The legacy `Result` model stays in the schema (CloudKit schema is additive-only; never remove it).
/// - The store URL is pinned to the pre-App-Group default so existing users keep their history.
enum AppPersistence {
    static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Persistence")

    static var schema: Schema {
        Schema([Result.self] + SkinalyzeSchema.models)
    }

    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: SkinalyzeSchema.legacyStoreURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Deletes a scan. Migrated scans also delete their legacy `Result`, otherwise the next launch's migration
    /// would bring the scan back.
    @MainActor
    static func delete(_ session: ScanSession, in context: ModelContext) {
        if let legacyID = session.legacyResultID {
            let descriptor = FetchDescriptor<Result>(predicate: #Predicate { $0.id == legacyID })
            do {
                try context.fetch(descriptor).forEach(context.delete)
            } catch {
                logger.error("Failed to fetch legacy record for deletion: \(error.localizedDescription)")
            }
        }
        context.delete(session)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save after deleting scan: \(error.localizedDescription)")
        }
    }
}
