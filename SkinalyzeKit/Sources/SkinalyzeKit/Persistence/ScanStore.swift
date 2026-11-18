import Foundation
import SwiftData

/// Background persistence for scans: image re-encoding and inserts never run on the main actor.
@ModelActor
public actor ScanStore {
    /// IDs of legacy `Result` records that already have a migrated `ScanSession`.
    public func migratedLegacyIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<ScanSession>(predicate: #Predicate { $0.legacyResultID != nil })
        return Set(try modelContext.fetch(descriptor).compactMap(\.legacyResultID))
    }

    /// Converts and inserts legacy snapshots that haven't been migrated yet. Idempotent and safe to re-run.
    /// - Returns: the number of sessions created.
    @discardableResult
    public func importLegacy(_ snapshots: [LegacyScanSnapshot]) throws -> Int {
        let done = try migratedLegacyIDs()
        let pendingIDs = Set(LegacyMigrationPlan.pending(legacyIDs: snapshots.map(\.id), alreadyMigrated: done))
        let pending = snapshots.filter { pendingIDs.contains($0.id) }
        guard !pending.isEmpty else { return 0 }

        for snapshot in pending {
            ScanSession.insert(try LegacyScanConverter.makeDraft(from: snapshot), into: modelContext)
        }
        try modelContext.save()
        return pending.count
    }

    /// Persists a newly captured scan.
    @discardableResult
    public func save(_ draft: ScanDraft) throws -> PersistentIdentifier {
        let session = ScanSession.insert(draft, into: modelContext)
        try modelContext.save()
        return session.persistentModelID
    }

    public func sessionCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<ScanSession>())
    }
}
