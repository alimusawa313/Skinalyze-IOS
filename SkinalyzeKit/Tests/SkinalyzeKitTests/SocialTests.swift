import Foundation
import Testing
@testable import SkinalyzeKit

/// Friends, friend streaks, friend quests and weekly leagues (E15, E16) — and what syncs between the user's devices.
@Suite("Friends and leagues")
struct SocialTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    func day(_ y: Int, _ m: Int, _ d: Int) -> DayStamp { DayStamp(year: y, month: m, day: d) }
    let monday = DayStamp(year: 2026, month: 11, day: 23)

    func profile(_ code: String, points: Int = 0, streak: Int = 0, lastActive: DayStamp? = nil,
                 tier: LeagueTier = .bronze, week: DayStamp? = nil, updated: TimeInterval = 0,
                 invitedBy: String? = nil) -> SocialProfile {
        SocialProfile(code: FriendCode(code)!, name: PublicName(adjective: 1, animal: 2), streak: streak,
                      lastActive: lastActive, weekStart: week ?? monday, weekPoints: points, tier: tier, group: 0,
                      outfit: nil, invitedBy: invitedBy.flatMap(FriendCode.init), updatedAt: Date(timeIntervalSince1970: updated))
    }

    // MARK: Codes and names

    @Test("Friend codes accept what people type and refuse look-alike or wrong-length input")
    func friendCodes() {
        #expect(FriendCode("abc-234")?.value == "ABC234")
        #expect(FriendCode(" ab c2 34 ")?.value == "ABC234")
        #expect(FriendCode("ABC23") == nil)
        #expect(FriendCode("ABC2340") == nil)
        #expect(FriendCode("ABCO12") == nil) // O, 1 are not in the alphabet
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<50 { #expect(FriendCode(FriendCode.random(using: &generator).value) != nil) }
    }

    @Test("The stable hash is fixed (the same on every device and launch)")
    func stableHash() {
        #expect(FriendCode("ABC234")!.stableHash == FriendCode("abc234")!.stableHash)
        #expect(FriendCode("ABC234")!.stableHash != FriendCode("ABC235")!.stableHash)
    }

    @Test("Public names stay inside the word lists")
    func publicNames() {
        let name = PublicName(adjective: 99, animal: -1)
        #expect((0..<PublicName.adjectives).contains(name.adjective))
        #expect((0..<PublicName.animals).contains(name.animal))
    }

    // MARK: Friends

    @Test("A friend streak is the shorter live streak, and ends when either misses a whole day")
    func togetherStreak() {
        let today = day(2026, 11, 25)
        let me = profile("AAAAAA", streak: 12, lastActive: today)
        let friend = profile("BBBBBB", streak: 5, lastActive: day(2026, 11, 24))
        #expect(FriendEngine.togetherStreak(me, friend, today: today, calendar: calendar) == 5)
        let lapsed = profile("CCCCCC", streak: 40, lastActive: day(2026, 11, 23))
        #expect(FriendEngine.togetherStreak(me, lapsed, today: today, calendar: calendar) == 0)
    }

    @Test("The friend quest adds this week's points only")
    func friendQuest() {
        let today = day(2026, 11, 25)
        let me = profile("AAAAAA", points: 250)
        let friend = profile("BBBBBB", points: 160)
        let quest = FriendEngine.questProgress(me, friend, today: today, calendar: calendar)
        #expect(quest.points == 410 && quest.done)
        let lastWeek = profile("BBBBBB", points: 900, week: day(2026, 11, 16))
        #expect(FriendEngine.questProgress(me, lastWeek, today: today, calendar: calendar).points == 250)
    }

    @Test("Invited friends are found by the inviter's code")
    func invited() {
        let profiles = [profile("BBBBBB", invitedBy: "AAAAAA"), profile("CCCCCC"), profile("AAAAAA", invitedBy: "AAAAAA")]
        #expect(FriendEngine.invited(by: FriendCode("AAAAAA")!, among: profiles).map(\.code.value) == ["BBBBBB"])
    }

    // MARK: Leagues

    @Test("Standings: this week, tier and group only, most points first, ties to whoever got there first")
    func standings() {
        let profiles = [profile("AAAAAA", points: 50, updated: 20), profile("BBBBBB", points: 90),
                        profile("CCCCCC", points: 50, updated: 10), profile("DDDDDD", points: 500, tier: .gold),
                        profile("EEEEEE", points: 999, week: day(2026, 11, 16)), profile("BBBBBB", points: 90)]
        let table = LeagueEngine.standings(profiles, weekStart: monday, tier: .bronze, group: 0)
        #expect(table.map(\.code.value) == ["BBBBBB", "CCCCCC", "AAAAAA"])
    }

    @Test("Top five with points move up; in a room of ten or more the bottom three move down; bronze is the floor")
    func moves() {
        let room = (0..<12).map { profile(String(repeating: FriendCode.alphabet[$0], count: 6), points: 120 - $0 * 10, tier: .silver) }
        let table = LeagueEngine.standings(room, weekStart: monday, tier: .silver, group: 0)
        #expect(LeagueEngine.move(for: table[0].code, in: table) == .up)
        #expect(LeagueEngine.move(for: table[4].code, in: table) == .up)
        #expect(LeagueEngine.move(for: table[5].code, in: table) == .stay)
        #expect(LeagueEngine.move(for: table[11].code, in: table) == .down)
        #expect(LeagueEngine.move(for: FriendCode("ZZZZZZ")!, in: table) == .stay)

        let small = LeagueEngine.standings(Array(room.prefix(6)), weekStart: monday, tier: .silver, group: 0)
        #expect(LeagueEngine.move(for: small[5].code, in: small) == .stay)
        let zero = [profile("AAAAAA", points: 0)]
        #expect(LeagueEngine.move(for: zero[0].code, in: zero) == .stay)
        #expect(LeagueEngine.tier(after: .down, from: .bronze) == .bronze)
        #expect(LeagueEngine.tier(after: .up, from: .diamond) == .diamond)
    }

    // MARK: Sync

    @Test("Adding is capped, ignores yourself and duplicates; removing sticks through a merge")
    func friendList() {
        var state = SocialState.empty
        state.code = FriendCode("AAAAAA")
        state = state.adding(FriendCode("BBBBBB")!, at: .now).adding(FriendCode("BBBBBB")!, at: .now)
            .adding(FriendCode("AAAAAA")!, at: .now)
        #expect(state.friends.map(\.code.value) == ["BBBBBB"])
        let otherDevice = state
        let removedHere = state.removing(FriendCode("BBBBBB")!)
        #expect(SocialState.merged(newer: removedHere, older: otherDevice).friends.isEmpty)
    }

    @Test("Two devices that both opted in keep the identity made first and combine friends")
    func identityMerge() {
        var phone = SocialState.empty
        phone.code = FriendCode("AAAAAA"); phone.createdAt = Date(timeIntervalSince1970: 100); phone.isSharing = true
        phone = phone.adding(FriendCode("CCCCCC")!, at: Date(timeIntervalSince1970: 150))
        var tablet = SocialState.empty
        tablet.code = FriendCode("BBBBBB"); tablet.createdAt = Date(timeIntervalSince1970: 200); tablet.isSharing = true
        tablet = tablet.adding(FriendCode("DDDDDD")!, at: Date(timeIntervalSince1970: 250))
        let merged = SocialState.merged(newer: tablet, older: phone)
        #expect(merged.code?.value == "AAAAAA")
        #expect(merged.friends.map(\.code.value) == ["CCCCCC", "DDDDDD"])
    }

    @Test("Synced copies from before friends existed still load")
    func tolerant() throws {
        let old = #"{"doneDays":[],"weekendOff":false}"#
        #expect(try JSONDecoder().decode(SyncedEngagement.self, from: Data(old.utf8)).social == .empty)
        let partial = #"{"social":{"isSharing":true,"tier":99}}"#
        let decoded = try JSONDecoder().decode(SyncedEngagement.self, from: Data(partial.utf8))
        #expect(decoded.social.isSharing && decoded.social.tier == .bronze)
    }
}
