import Foundation
import Observation
import OSLog
import SkinalyzeKit

/// Friends and the weekly league. Off until the user opts in; turning it off deletes the public profile.
/// Rules live in `FriendEngine` / `LeagueEngine` (tested); this stores the user's state and talks to `SocialService`.
@Observable
@MainActor
final class SocialModel {
    enum Status: Equatable {
        case idle, loading, ready
        /// No iCloud account on this device.
        case noAccount
        case failed
    }

    /// What this device knows about the user's own effort, for publishing.
    struct Effort: Equatable {
        let streak: Int
        let lastActive: DayStamp?
        let weekPoints: Int
        let outfit: PimpiOutfit?
    }

    private static let stateKey = "socialState"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Social")

    private(set) var state: SocialState
    private(set) var status: Status = .idle
    private(set) var me: SocialProfile?
    private(set) var friends: [SocialProfile] = []
    private(set) var league: [SocialProfile] = []
    private(set) var invitedCount = 0
    /// The tier move applied when this week started, to celebrate once.
    private(set) var lastMove: LeagueEngine.Move?

    private let service: any SocialService
    private let defaults: UserDefaults
    let calendar: Calendar

    init(service: (any SocialService)? = nil, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        #if DEBUG
        let demo: (any SocialService)? = defaults.bool(forKey: "socialDemo") ? DemoSocialService() : nil
        self.service = service ?? demo ?? CloudSocialService()
        #else
        self.service = service ?? CloudSocialService()
        #endif
        state = defaults.data(forKey: Self.stateKey).flatMap { try? JSONDecoder().decode(SocialState.self, from: $0) } ?? .empty
    }

    var isSharing: Bool { state.isSharing && state.code != nil }

    var today: DayStamp { DayStamp(.now, calendar: calendar) }

    /// Opting in: makes the friend code and public name once (kept if the user turns sharing off and on again).
    func join(effort: Effort, invitedBy: FriendCode? = nil, now: Date = .now) async {
        guard await service.isAvailable() else {
            status = .noAccount
            return
        }
        var updated = state
        if updated.code == nil {
            var generator = SystemRandomNumberGenerator()
            updated.code = FriendCode.random(using: &generator)
            updated.name = PublicName.random(using: &generator)
            updated.createdAt = now
        }
        updated.isSharing = true
        if updated.invitedBy == nil, let invitedBy, invitedBy != updated.code { updated.invitedBy = invitedBy }
        save(updated)
        await refresh(effort: effort, now: now)
    }

    func stopSharing() async {
        guard let code = state.code else { return }
        var updated = state
        updated.isSharing = false
        save(updated)
        me = nil
        friends = []
        league = []
        do {
            try await service.withdraw(code)
        } catch {
            Self.logger.error("Could not remove the public profile: \(error.localizedDescription)")
        }
    }

    enum AddResult { case added, notJoinedYet, alreadyFriend, yourOwnCode, full }

    @discardableResult
    func addFriend(_ code: FriendCode, effort: Effort) async -> AddResult {
        if code == state.code { return .yourOwnCode }
        if state.friends.contains(where: { $0.code == code }) { return .alreadyFriend }
        let updated = state.adding(code, at: .now)
        guard updated != state else { return .full }
        save(updated)
        await refresh(effort: effort)
        return friends.contains { $0.code == code } ? .added : .notJoinedYet
    }

    func removeFriend(_ code: FriendCode) {
        save(state.removing(code))
        friends.removeAll { $0.code == code }
    }

    /// Settles the tier when a new week starts, publishes this week's effort, then loads friends, league and invites.
    func refresh(effort: Effort, now: Date = .now) async {
        guard isSharing, let code = state.code, let name = state.name else { return }
        guard await service.isAvailable() else {
            status = .noAccount
            return
        }
        status = .loading
        do {
            try await settleTier(code: code, now: now)
            let week = RecapEngine.week(containing: DayStamp(now, calendar: calendar), calendar: calendar).first
            let profile = SocialProfile(code: code, name: name, streak: effort.streak, lastActive: effort.lastActive,
                                        weekStart: week, weekPoints: effort.weekPoints, tier: state.tier,
                                        group: LeagueEngine.group(for: code), outfit: effort.outfit?.rawValue,
                                        invitedBy: state.invitedBy, updatedAt: now)
            try await service.publish(profile)
            me = profile
            async let friendProfiles = service.profiles(state.friends.map(\.code))
            async let room = service.league(weekStart: week, tier: state.tier, group: profile.group)
            async let invited = service.invited(by: code)
            let order = state.friends.map(\.code)
            friends = try await friendProfiles.sorted { (order.firstIndex(of: $0.code) ?? 0) < (order.firstIndex(of: $1.code) ?? 0) }
            league = LeagueEngine.standings(try await room.filter { $0.code != code } + [profile],
                                            weekStart: week, tier: state.tier, group: profile.group)
            invitedCount = FriendEngine.invited(by: code, among: try await invited).count
            status = .ready
        } catch {
            Self.logger.error("Social refresh failed: \(error.localizedDescription)")
            status = .failed
        }
    }

    /// Once per week: where last week's standings put this player.
    private func settleTier(code: FriendCode, now: Date) async throws {
        let thisWeek = RecapEngine.week(containing: DayStamp(now, calendar: calendar), calendar: calendar).first
        guard state.tierWeek != thisWeek else { return }
        var updated = state
        if let previous = state.tierWeek {
            let table = LeagueEngine.standings(
                try await service.league(weekStart: previous, tier: state.tier, group: LeagueEngine.group(for: code)),
                weekStart: previous, tier: state.tier, group: LeagueEngine.group(for: code))
            let move = LeagueEngine.move(for: code, in: table)
            updated.tier = LeagueEngine.tier(after: move, from: state.tier)
            lastMove = move
        }
        updated.tierWeek = thisWeek
        save(updated)
    }

    func applySynced(_ merged: SocialState) {
        save(merged)
    }

    private func save(_ updated: SocialState) {
        guard updated != state else { return }
        state = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Self.stateKey)
    }
}
