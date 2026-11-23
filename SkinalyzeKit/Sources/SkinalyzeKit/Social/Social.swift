import Foundation

// Friends and weekly leagues (E15, E16) without a server of our own: profiles live in the app's iCloud public
// database. What leaves the device is only effort — a routine streak and this week's quest points — under a generated
// name (no free text, so there is nothing to moderate). Never photos, never skin results (FEATURES.md §0 rule 3).

/// Six characters to add a friend by. No look-alike characters (0/O, 1/I/L).
public struct FriendCode: Hashable, Codable, Sendable, Comparable {
    public static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    public static let length = 6

    public let value: String

    /// Accepts what a person types: any case, spaces or dashes, "O" for "0" is not guessed — invalid input is nil.
    public init?(_ raw: String) {
        let cleaned = raw.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == Self.length, cleaned.allSatisfy(Self.alphabet.contains) else { return nil }
        value = cleaned
    }

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> FriendCode {
        let value = String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
        return FriendCode(value)!
    }

    public static func random() -> FriendCode {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    public static func < (lhs: FriendCode, rhs: FriendCode) -> Bool { lhs.value < rhs.value }

    /// A stable number for this code (FNV-1a), the same on every device and every launch.
    public var stableHash: UInt64 {
        value.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
    }
}

/// A generated public name ("Sunny Otter"): two indexes into fixed word lists, so every device shows it in its own
/// language and nobody can type anything into it.
public struct PublicName: Hashable, Codable, Sendable {
    public static let adjectives = 24
    public static let animals = 24

    public let adjective: Int
    public let animal: Int

    public init(adjective: Int, animal: Int) {
        self.adjective = ((adjective % Self.adjectives) + Self.adjectives) % Self.adjectives
        self.animal = ((animal % Self.animals) + Self.animals) % Self.animals
    }

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> PublicName {
        PublicName(adjective: Int.random(in: 0..<adjectives, using: &generator),
                   animal: Int.random(in: 0..<animals, using: &generator))
    }
}

public enum LeagueTier: Int, CaseIterable, Codable, Sendable, Comparable {
    case bronze, silver, gold, emerald, diamond

    public static func < (lhs: LeagueTier, rhs: LeagueTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var up: LeagueTier { LeagueTier(rawValue: rawValue + 1) ?? self }
    var down: LeagueTier { LeagueTier(rawValue: rawValue - 1) ?? self }
}

/// What one person publishes.
public struct SocialProfile: Codable, Equatable, Sendable {
    public var code: FriendCode
    public var name: PublicName
    /// Routine streak and the last day it grew (a streak whose last day is before yesterday is over).
    public var streak: Int
    public var lastActive: DayStamp?
    /// Monday of the week `weekPoints` belong to.
    public var weekStart: DayStamp
    public var weekPoints: Int
    public var tier: LeagueTier
    public var group: Int
    public var outfit: String?
    /// The friend code of whoever invited this person, if they came through an invite.
    public var invitedBy: FriendCode?
    public var updatedAt: Date

    public init(code: FriendCode, name: PublicName, streak: Int, lastActive: DayStamp?, weekStart: DayStamp,
                weekPoints: Int, tier: LeagueTier, group: Int, outfit: String?, invitedBy: FriendCode?, updatedAt: Date) {
        self.code = code
        self.name = name
        self.streak = streak
        self.lastActive = lastActive
        self.weekStart = weekStart
        self.weekPoints = weekPoints
        self.tier = tier
        self.group = group
        self.outfit = outfit
        self.invitedBy = invitedBy
        self.updatedAt = updatedAt
    }

    /// The streak as seen today: zero once a whole day has been missed.
    public func liveStreak(today: DayStamp, calendar: Calendar) -> Int {
        guard let lastActive, lastActive >= today.adding(days: -1, calendar: calendar) else { return 0 }
        return streak
    }

    /// Points for the week holding `today` (zero when the profile is from an earlier week).
    public func points(inWeekOf today: DayStamp, calendar: Calendar) -> Int {
        weekStart == RecapEngine.week(containing: today, calendar: calendar).first ? weekPoints : 0
    }
}

// MARK: - Friends

public enum FriendEngine {
    /// Combined quest points two friends aim for each week.
    public static let weeklyGoal = 400

    /// Days in a row you've both kept your routine: the shorter of the two live streaks.
    public static func togetherStreak(_ mine: SocialProfile, _ theirs: SocialProfile, today: DayStamp,
                                      calendar: Calendar) -> Int {
        min(mine.liveStreak(today: today, calendar: calendar), theirs.liveStreak(today: today, calendar: calendar))
    }

    /// The friend quest: this week's points together, out of `weeklyGoal`.
    public static func questProgress(_ mine: SocialProfile, _ theirs: SocialProfile, today: DayStamp,
                                     calendar: Calendar) -> (points: Int, done: Bool) {
        let points = mine.points(inWeekOf: today, calendar: calendar) + theirs.points(inWeekOf: today, calendar: calendar)
        return (points, points >= weeklyGoal)
    }

    /// Friends who joined through this person's invite.
    public static func invited(by code: FriendCode, among profiles: [SocialProfile]) -> [SocialProfile] {
        profiles.filter { $0.invitedBy == code && $0.code != code }
    }
}

// MARK: - Leagues

public enum LeagueEngine {
    /// Groups per tier. One while the app is small; raising it splits each tier into rooms of similar size.
    public static let groupsPerTier = 1
    public static let promotions = 5
    public static let demotions = 3
    /// Below this many players nobody moves down (a tiny room shouldn't send anyone back).
    public static let minimumForDemotion = 10

    public static func group(for code: FriendCode) -> Int { Int(code.stableHash % UInt64(groupsPerTier)) }

    /// Most points first; equal points go to whoever got there first, then by code so every device agrees.
    public static func standings(_ profiles: [SocialProfile], weekStart: DayStamp, tier: LeagueTier, group: Int) -> [SocialProfile] {
        var seen = Set<FriendCode>()
        return profiles
            .filter { $0.weekStart == weekStart && $0.tier == tier && $0.group == group }
            .sorted { a, b in
                if a.weekPoints != b.weekPoints { return a.weekPoints > b.weekPoints }
                if a.updatedAt != b.updatedAt { return a.updatedAt < b.updatedAt }
                return a.code < b.code
            }
            .filter { seen.insert($0.code).inserted }
    }

    public enum Move: Sendable, Equatable { case up, stay, down }

    /// Where a player goes after a finished week. Only players who earned points move up; nobody leaves bronze.
    public static func move(for code: FriendCode, in finalStandings: [SocialProfile]) -> Move {
        guard let rank = finalStandings.firstIndex(where: { $0.code == code }) else { return .stay }
        let player = finalStandings[rank]
        if rank < promotions, player.weekPoints > 0, player.tier != .diamond { return .up }
        let count = finalStandings.count
        if count >= minimumForDemotion, rank >= count - demotions, player.tier != .bronze { return .down }
        return .stay
    }

    public static func tier(after move: Move, from tier: LeagueTier) -> LeagueTier {
        switch move {
        case .up: tier.up
        case .stay: tier
        case .down: tier.down
        }
    }
}

// MARK: - What this device keeps (synced through the user's own iCloud)

public struct FriendEntry: Codable, Hashable, Sendable {
    public let code: FriendCode
    public let added: Date

    public init(code: FriendCode, added: Date) {
        self.code = code
        self.added = added
    }
}

/// The user's social identity and friend list. Nil code = never opted in.
public struct SocialState: Codable, Equatable, Sendable {
    public var code: FriendCode?
    public var name: PublicName?
    public var createdAt: Date?
    public var isSharing: Bool
    public var friends: [FriendEntry]
    public var tier: LeagueTier
    /// Monday of the week the tier was last settled for.
    public var tierWeek: DayStamp?
    public var invitedBy: FriendCode?
    /// Friends removed on any device, so a merge doesn't bring them back.
    public var removed: Set<FriendCode>

    public static let empty = SocialState(code: nil, name: nil, createdAt: nil, isSharing: false, friends: [],
                                          tier: .bronze, tierWeek: nil, invitedBy: nil, removed: [])

    public init(code: FriendCode?, name: PublicName?, createdAt: Date?, isSharing: Bool, friends: [FriendEntry],
                tier: LeagueTier, tierWeek: DayStamp?, invitedBy: FriendCode?, removed: Set<FriendCode>) {
        self.code = code
        self.name = name
        self.createdAt = createdAt
        self.isSharing = isSharing
        self.friends = friends
        self.tier = tier
        self.tierWeek = tierWeek
        self.invitedBy = invitedBy
        self.removed = removed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(FriendCode.self, forKey: .code)
        name = try c.decodeIfPresent(PublicName.self, forKey: .name)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        isSharing = try c.decodeIfPresent(Bool.self, forKey: .isSharing) ?? false
        friends = try c.decodeIfPresent([FriendEntry].self, forKey: .friends) ?? []
        tier = (try? c.decodeIfPresent(LeagueTier.self, forKey: .tier)) ?? .bronze
        tierWeek = try c.decodeIfPresent(DayStamp.self, forKey: .tierWeek)
        invitedBy = try c.decodeIfPresent(FriendCode.self, forKey: .invitedBy)
        removed = try c.decodeIfPresent(Set<FriendCode>.self, forKey: .removed) ?? []
    }

    public static let maximumFriends = 50

    public func adding(_ friend: FriendCode, at date: Date) -> SocialState {
        guard friend != code, !friends.contains(where: { $0.code == friend }), friends.count < Self.maximumFriends else {
            return self
        }
        var copy = self
        copy.friends.append(FriendEntry(code: friend, added: date))
        copy.removed.remove(friend)
        return copy
    }

    public func removing(_ friend: FriendCode) -> SocialState {
        var copy = self
        copy.friends.removeAll { $0.code == friend }
        copy.removed.insert(friend)
        return copy
    }

    /// Two devices: the identity made first wins (both may have opted in before syncing), friends are combined minus
    /// removed ones, and the later-settled tier wins. `newer` decides the sharing switch.
    public static func merged(newer: SocialState, older: SocialState) -> SocialState {
        let identity: SocialState = switch (newer.createdAt, older.createdAt) {
        case let (a?, b?): a <= b ? newer : older
        case (_?, nil): newer
        case (nil, _?): older
        case (nil, nil): newer
        }
        let removed = newer.removed.union(older.removed)
        var friends: [FriendEntry] = []
        for entry in (newer.friends + older.friends).sorted(by: { $0.added < $1.added })
        where !removed.contains(entry.code) && !friends.contains(where: { $0.code == entry.code }) && entry.code != identity.code {
            friends.append(entry)
        }
        let settled = [newer, older].max { ($0.tierWeek ?? DayStamp(year: 0, month: 1, day: 1)) < ($1.tierWeek ?? DayStamp(year: 0, month: 1, day: 1)) } ?? newer
        return SocialState(code: identity.code, name: identity.name, createdAt: identity.createdAt,
                           isSharing: newer.isSharing, friends: Array(friends.prefix(maximumFriends)),
                           tier: settled.tier, tierWeek: settled.tierWeek,
                           invitedBy: newer.invitedBy ?? older.invitedBy, removed: removed)
    }
}
