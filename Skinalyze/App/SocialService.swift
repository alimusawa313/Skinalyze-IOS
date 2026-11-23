import CloudKit
import Foundation
import OSLog
import SkinalyzeKit

/// Where friend and league profiles live. The real one is the app's iCloud public database (no server of our own);
/// debug builds can use an in-memory stand-in (`-socialDemo YES`) because the Simulator has no iCloud account.
protocol SocialService: Sendable {
    func isAvailable() async -> Bool
    func publish(_ profile: SocialProfile) async throws
    func profiles(_ codes: [FriendCode]) async throws -> [SocialProfile]
    func league(weekStart: DayStamp, tier: LeagueTier, group: Int) async throws -> [SocialProfile]
    func invited(by code: FriendCode) async throws -> [SocialProfile]
    func withdraw(_ code: FriendCode) async throws
}

/// The iCloud public database. Records can be read by anyone with the app and changed only by the person who made
/// them (CloudKit's default public-database roles). One record per person: "profile-<friend code>".
///
/// Queries need these indexes in the CloudKit Console (owner action, see FEATURE-PHASES.md Phase 9):
/// `SocialProfile`: recordName (queryable), weekStart / tier / room / invitedBy (queryable), weekPoints (sortable).
struct CloudSocialService: SocialService {
    static let recordType = "SocialProfile"
    static let leagueLimit = 50
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Social")

    private let container = CKContainer(identifier: "iCloud.com.Patani.Skinalyze")
    private var database: CKDatabase { container.publicCloudDatabase }

    private enum Field {
        static let code = "code", adjective = "nameAdjective", animal = "nameAnimal", streak = "streak"
        static let lastActive = "lastActive", weekStart = "weekStart", weekPoints = "weekPoints", tier = "tier"
        static let room = "room", outfit = "outfit", invitedBy = "invitedBy", updatedAt = "updatedAt"
    }

    static func recordID(_ code: FriendCode) -> CKRecord.ID { CKRecord.ID(recordName: "profile-\(code.value)") }

    func isAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    func publish(_ profile: SocialProfile) async throws {
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(profile.code))
        record[Field.code] = profile.code.value
        record[Field.adjective] = profile.name.adjective
        record[Field.animal] = profile.name.animal
        record[Field.streak] = profile.streak
        record[Field.lastActive] = profile.lastActive?.string
        record[Field.weekStart] = profile.weekStart.string
        record[Field.weekPoints] = profile.weekPoints
        record[Field.tier] = profile.tier.rawValue
        record[Field.room] = profile.group
        record[Field.outfit] = profile.outfit
        record[Field.invitedBy] = profile.invitedBy?.value
        record[Field.updatedAt] = profile.updatedAt
        // Only this person can write this record, so their copy always wins.
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func profiles(_ codes: [FriendCode]) async throws -> [SocialProfile] {
        guard !codes.isEmpty else { return [] }
        let results = try await database.records(for: codes.map(Self.recordID))
        return results.values.compactMap { try? $0.get() }.compactMap(Self.profile)
    }

    func league(weekStart: DayStamp, tier: LeagueTier, group: Int) async throws -> [SocialProfile] {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d AND %K == %d", Field.weekStart, weekStart.string,
                                    Field.tier, tier.rawValue, Field.room, group)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Field.weekPoints, ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: Self.leagueLimit)
        return results.compactMap { try? $0.1.get() }.compactMap(Self.profile)
    }

    func invited(by code: FriendCode) async throws -> [SocialProfile] {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "%K == %@", Field.invitedBy, code.value))
        let (results, _) = try await database.records(matching: query, resultsLimit: 100)
        return results.compactMap { try? $0.1.get() }.compactMap(Self.profile)
    }

    func withdraw(_ code: FriendCode) async throws {
        do {
            _ = try await database.deleteRecord(withID: Self.recordID(code))
        } catch let error as CKError where error.code == .unknownItem {
            return // already gone
        }
    }

    /// Never trusts a record: anything malformed is skipped.
    static func profile(_ record: CKRecord) -> SocialProfile? {
        guard let code = (record[Field.code] as? String).flatMap(FriendCode.init),
              record.recordID == recordID(code),
              let week = (record[Field.weekStart] as? String).flatMap(DayStamp.init(string:)) else {
            logger.notice("Skipped a malformed social profile")
            return nil
        }
        let int = { (key: String) in (record[key] as? Int) ?? 0 }
        return SocialProfile(code: code, name: PublicName(adjective: int(Field.adjective), animal: int(Field.animal)),
                             streak: max(0, int(Field.streak)),
                             lastActive: (record[Field.lastActive] as? String).flatMap(DayStamp.init(string:)),
                             weekStart: week, weekPoints: max(0, int(Field.weekPoints)),
                             tier: LeagueTier(rawValue: int(Field.tier)) ?? .bronze, group: max(0, int(Field.room)),
                             outfit: (record[Field.outfit] as? String).flatMap(PimpiOutfit.init(rawValue:))?.rawValue,
                             invitedBy: (record[Field.invitedBy] as? String).flatMap(FriendCode.init),
                             updatedAt: (record[Field.updatedAt] as? Date) ?? .distantPast)
    }
}

#if DEBUG
/// `-socialDemo YES`: friends and a league room that live in memory, so every screen can be checked without iCloud.
actor DemoSocialService: SocialService {
    private var store: [FriendCode: SocialProfile] = [:]

    init(calendar: Calendar = .current, now: Date = .now) {
        let today = DayStamp(now, calendar: calendar)
        let week = RecapEngine.week(containing: today, calendar: calendar).first
        // Valid codes only (no 0, O, 1, I or L).
        let codes = ["FRND22", "PAWS33", "MATE44", "BUDY55"] + (0..<12).map { "TEAM" + String(FriendCode.alphabet[$0]) + "2" }
        for (index, raw) in codes.enumerated() {
            guard let code = FriendCode(raw) else { continue }
            store[code] = SocialProfile(code: code, name: PublicName(adjective: index * 5, animal: index * 7),
                                        streak: [21, 6, 0, 3][index % 4], lastActive: index % 4 == 2 ? nil : today,
                                        weekStart: week, weekPoints: 40 + (index * 37) % 260, tier: .bronze, group: 0,
                                        outfit: PimpiOutfit.allCases[index % PimpiOutfit.allCases.count].rawValue,
                                        invitedBy: index == 1 ? FriendCode("DEMO22") : nil, updatedAt: now)
        }
    }

    func isAvailable() async -> Bool { true }
    func publish(_ profile: SocialProfile) async throws { store[profile.code] = profile }
    func profiles(_ codes: [FriendCode]) async throws -> [SocialProfile] { codes.compactMap { store[$0] } }
    func league(weekStart: DayStamp, tier: LeagueTier, group: Int) async throws -> [SocialProfile] {
        store.values.filter { $0.weekStart == weekStart && $0.tier == tier && $0.group == group }
    }
    func invited(by code: FriendCode) async throws -> [SocialProfile] {
        store.values.filter { $0.invitedBy == code || ($0.invitedBy?.value == "DEMO22") }
    }
    func withdraw(_ code: FriendCode) async throws { store[code] = nil }
}
#endif
