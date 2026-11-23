import Foundation

// Daily quests, glow points, chests, Pimpi outfits and badges. Everything here rewards showing up and learning —
// never a skin result (FEATURES.md §0 rule 1). Pure and tested; the app only stores the ledger and reports events.

/// Something small to do today.
public enum QuestKind: String, CaseIterable, Codable, Sendable {
    /// Check off a routine step.
    case routine
    /// Save a scan.
    case scan
    /// Check a product ("Is it good for me?").
    case productCheck
    /// Share a card or video.
    case share
    /// Open an earlier scan or compare two.
    case lookBack
}

/// What the user can actually do today, so no quest is impossible.
public struct QuestContext: Sendable, Equatable {
    /// A scan is allowed today (free scan unused, or Pro) and none was saved yet today.
    public var canScan: Bool
    /// There is a routine to check off.
    public var hasRoutine: Bool
    /// A product check is still available this month.
    public var canCheckProduct: Bool
    public var scanCount: Int

    public init(canScan: Bool, hasRoutine: Bool, canCheckProduct: Bool, scanCount: Int) {
        self.canScan = canScan
        self.hasRoutine = hasRoutine
        self.canCheckProduct = canCheckProduct
        self.scanCount = scanCount
    }
}

public enum QuestEngine {
    public static let questsPerDay = 3

    public static func points(for kind: QuestKind) -> Int {
        switch kind {
        case .routine: 10
        case .share: 10
        case .lookBack: 10
        case .productCheck: 15
        case .scan: 20
        }
    }

    /// Today's quests: the possible ones, in an order that rotates by day, so a day always gives the same three.
    public static func quests(for day: DayStamp, context: QuestContext) -> [QuestKind] {
        let possible = QuestKind.allCases.filter { kind in
            switch kind {
            case .routine: context.hasRoutine
            case .scan: context.canScan
            case .productCheck: context.canCheckProduct
            case .share: true
            case .lookBack: context.scanCount >= 2
            }
        }
        guard !possible.isEmpty else { return [] }
        let seed = day.year * 372 + day.month * 31 + day.day
        // Rotate by the day, and step through with a stride coprime to the count so the trio changes daily.
        let count = possible.count
        let stride = count > 2 ? 2 : 1
        let order = (0..<count).map { possible[(seed + $0 * stride) % count] }
        var seen = Set<QuestKind>()
        let unique = order.filter { seen.insert($0).inserted } + possible.filter { !seen.contains($0) }
        return Array(unique.prefix(questsPerDay))
    }
}

/// Cosmetic rewards from chests, drawn on Pimpi.
public enum PimpiOutfit: String, CaseIterable, Codable, Sendable {
    case partyHat, beanie, flower, bow, crown, sunglasses

    /// Pro sets: only Pro chests hold them.
    public var isPro: Bool {
        switch self {
        case .crown, .sunglasses: true
        default: false
        }
    }
}

/// What has been earned. Stored by the app; decoded tolerantly so older saves keep loading.
public struct RewardLedger: Codable, Equatable, Sendable {
    public var points: Int
    /// Quests done, per day ("yyyy-MM-dd").
    public var completed: [String: Set<QuestKind>]
    public var chestsWaiting: Int
    public var chestsOpened: Int
    public var unlocked: Set<PimpiOutfit>
    public var worn: PimpiOutfit?
    /// The latest day anything was earned; no earlier day can earn again (clock set back).
    public var latestDay: DayStamp?
    public var shares: Int
    public var productChecks: Int

    public static let empty = RewardLedger(points: 0, completed: [:], chestsWaiting: 0, chestsOpened: 0, unlocked: [],
                                           worn: nil, latestDay: nil, shares: 0, productChecks: 0)

    public init(points: Int, completed: [String: Set<QuestKind>], chestsWaiting: Int, chestsOpened: Int,
                unlocked: Set<PimpiOutfit>, worn: PimpiOutfit?, latestDay: DayStamp?, shares: Int, productChecks: Int) {
        self.points = points
        self.completed = completed
        self.chestsWaiting = chestsWaiting
        self.chestsOpened = chestsOpened
        self.unlocked = unlocked
        self.worn = worn
        self.latestDay = latestDay
        self.shares = shares
        self.productChecks = productChecks
    }

    private enum CodingKeys: String, CodingKey {
        case points, completed, chestsWaiting, chestsOpened, unlocked, worn, latestDay, shares, productChecks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        completed = try c.decodeIfPresent([String: Set<QuestKind>].self, forKey: .completed) ?? [:]
        chestsWaiting = try c.decodeIfPresent(Int.self, forKey: .chestsWaiting) ?? 0
        chestsOpened = try c.decodeIfPresent(Int.self, forKey: .chestsOpened) ?? 0
        unlocked = try c.decodeIfPresent(Set<PimpiOutfit>.self, forKey: .unlocked) ?? []
        worn = try c.decodeIfPresent(PimpiOutfit.self, forKey: .worn)
        latestDay = try c.decodeIfPresent(DayStamp.self, forKey: .latestDay)
        shares = try c.decodeIfPresent(Int.self, forKey: .shares) ?? 0
        productChecks = try c.decodeIfPresent(Int.self, forKey: .productChecks) ?? 0
    }

    /// Days on which every quest was done.
    public var fullQuestDays: Int {
        completed.values.filter { $0.count >= QuestEngine.questsPerDay }.count
    }
}

public enum RewardEngine {
    public static let chestBonusPoints = 50

    public struct Award: Equatable, Sendable {
        public let kind: QuestKind
        public let points: Int
        /// This completed all of today's quests.
        public let earnedChest: Bool
    }

    public struct ChestReward: Equatable, Sendable {
        public let outfit: PimpiOutfit?
        public let bonusPoints: Int
    }

    public static func completed(on day: DayStamp, ledger: RewardLedger) -> Set<QuestKind> {
        ledger.completed[day.string] ?? []
    }

    /// Records that `kind` happened on `day`. Earns only when it is one of that day's quests, not yet done, and the
    /// day is not earlier than the latest day already seen.
    public static func record(_ kind: QuestKind, day: DayStamp, todaysQuests: [QuestKind], ledger: RewardLedger,
                              isPro: Bool) -> (RewardLedger, Award?) {
        guard todaysQuests.contains(kind) else { return (ledger, nil) }
        if let latest = ledger.latestDay, day < latest { return (ledger, nil) }
        var done = completed(on: day, ledger: ledger)
        guard !done.contains(kind) else { return (ledger, nil) }
        done.insert(kind)
        var updated = ledger
        updated.completed[day.string] = done
        updated.latestDay = day
        let points = QuestEngine.points(for: kind) * (isPro ? 2 : 1)
        updated.points += points
        let allDone = Set(todaysQuests).isSubset(of: done)
        if allDone { updated.chestsWaiting += 1 }
        return (updated, Award(kind: kind, points: points, earnedChest: allDone))
    }

    /// Opens one waiting chest: the next outfit not owned yet (Pro sets only for Pro), else bonus points.
    public static func openChest(_ ledger: RewardLedger, isPro: Bool) -> (RewardLedger, ChestReward?) {
        guard ledger.chestsWaiting > 0 else { return (ledger, nil) }
        var updated = ledger
        updated.chestsWaiting -= 1
        updated.chestsOpened += 1
        let available = PimpiOutfit.allCases.filter { !ledger.unlocked.contains($0) && (isPro || !$0.isPro) }
        if available.isEmpty {
            updated.points += chestBonusPoints
            return (updated, ChestReward(outfit: nil, bonusPoints: chestBonusPoints))
        }
        // Varied but repeatable: the number of chests opened picks among what is left.
        let outfit = available[ledger.chestsOpened % available.count]
        updated.unlocked.insert(outfit)
        return (updated, ChestReward(outfit: outfit, bonusPoints: 0))
    }

    /// Puts on an owned outfit (`nil` takes it off). Unowned outfits are ignored.
    public static func wearing(_ outfit: PimpiOutfit?, ledger: RewardLedger) -> RewardLedger {
        if let outfit, !ledger.unlocked.contains(outfit) { return ledger }
        var updated = ledger
        updated.worn = outfit
        return updated
    }

    /// Counts toward badges, whether or not it was a quest today.
    public static func counting(_ kind: QuestKind, ledger: RewardLedger) -> RewardLedger {
        var updated = ledger
        switch kind {
        case .share: updated.shares += 1
        case .productCheck: updated.productChecks += 1
        default: break
        }
        return updated
    }
}

/// Badges for effort.
public enum Badge: String, CaseIterable, Codable, Sendable {
    case firstScan, first3D, routineWeek, tenChecks, firstShare, questWeek
}

public struct BadgeFacts: Sendable, Equatable {
    public var scans: Int
    public var has3DScan: Bool
    public var bestRoutineStreak: Int
    public var productChecks: Int
    public var shares: Int
    /// Days with every quest done.
    public var questDays: Int

    public init(scans: Int, has3DScan: Bool, bestRoutineStreak: Int, productChecks: Int, shares: Int, questDays: Int) {
        self.scans = scans
        self.has3DScan = has3DScan
        self.bestRoutineStreak = bestRoutineStreak
        self.productChecks = productChecks
        self.shares = shares
        self.questDays = questDays
    }
}

public enum BadgeEngine {
    public static func earned(_ facts: BadgeFacts) -> Set<Badge> {
        var badges = Set<Badge>()
        if facts.scans >= 1 { badges.insert(.firstScan) }
        if facts.has3DScan { badges.insert(.first3D) }
        if facts.bestRoutineStreak >= 7 { badges.insert(.routineWeek) }
        if facts.productChecks >= 10 { badges.insert(.tenChecks) }
        if facts.shares >= 1 { badges.insert(.firstShare) }
        if facts.questDays >= 7 { badges.insert(.questWeek) }
        return badges
    }
}
