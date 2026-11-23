import Foundation

/// 30-day challenges (E17). Thirty days done finishes it; a missed day costs nothing and there is no deadline —
/// effort is counted, never lost (FEATURES.md §0 rule 1).
public enum ChallengeKind: String, CaseIterable, Codable, Sendable {
    /// The morning sunscreen step checked off.
    case sunscreen
    /// A routine step checked off both morning and evening.
    case morningAndEvening
    /// "I kept my hands off my face today" — the user's own check-in.
    case handsOff
}

public struct Challenge: Codable, Equatable, Sendable {
    public let kind: ChallengeKind
    public let started: DayStamp
    public var doneDays: Set<DayStamp>
    public var finished: DayStamp?

    public init(kind: ChallengeKind, started: DayStamp, doneDays: Set<DayStamp> = [], finished: DayStamp? = nil) {
        self.kind = kind
        self.started = started
        self.doneDays = doneDays
        self.finished = finished
    }

    public var progress: Int { min(doneDays.count, ChallengeEngine.goalDays) }
    public var id: String { "\(kind.rawValue)-\(started.string)" }
}

/// The user's challenges: at most one running, plus the finished ones (each a badge and a finisher card).
public struct ChallengeBook: Codable, Equatable, Sendable {
    public var active: Challenge?
    public var finished: [Challenge]

    public static let empty = ChallengeBook(active: nil, finished: [])

    public init(active: Challenge?, finished: [Challenge]) {
        self.active = active
        self.finished = finished
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = try c.decodeIfPresent(Challenge.self, forKey: .active)
        finished = try c.decodeIfPresent([Challenge].self, forKey: .finished) ?? []
    }

    /// Two devices: days done are combined, finished challenges are combined, and a running challenge that one copy
    /// already finished stops running.
    public static func merged(_ a: ChallengeBook, _ b: ChallengeBook) -> ChallengeBook {
        var finished: [String: Challenge] = [:]
        for challenge in a.finished + b.finished {
            var merged = challenge
            if let existing = finished[challenge.id] { merged.doneDays.formUnion(existing.doneDays) }
            finished[challenge.id] = merged
        }
        var active: Challenge?
        switch (a.active, b.active) {
        case let (x?, y?) where x.id == y.id:
            var combined = x
            combined.doneDays.formUnion(y.doneDays)
            active = combined
        case let (x?, y?):
            active = x.started >= y.started ? x : y
        case let (x, y):
            active = x ?? y
        }
        if let running = active, finished[running.id] != nil { active = nil }
        return ChallengeBook(active: active, finished: finished.values.sorted { $0.started < $1.started })
    }
}

public enum ChallengeEngine {
    public static let goalDays = 30

    /// Starting a new challenge replaces the running one (its days are kept only if it was finished).
    public static func starting(_ kind: ChallengeKind, in book: ChallengeBook, today: DayStamp) -> ChallengeBook {
        ChallengeBook(active: Challenge(kind: kind, started: today), finished: book.finished)
    }

    public static func stopping(_ book: ChallengeBook) -> ChallengeBook {
        ChallengeBook(active: nil, finished: book.finished)
    }

    /// Records that today's condition was met (or no longer is, e.g. a routine step un-ticked). Only today counts —
    /// past days can't be filled in. Reaching the goal moves the challenge to `finished`.
    public static func recording(_ kind: ChallengeKind, done: Bool, in book: ChallengeBook, today: DayStamp) -> ChallengeBook {
        guard var challenge = book.active, challenge.kind == kind, today >= challenge.started else { return book }
        if done { challenge.doneDays.insert(today) } else { challenge.doneDays.remove(today) }
        guard challenge.doneDays.count >= goalDays else {
            return ChallengeBook(active: challenge, finished: book.finished)
        }
        challenge.finished = today
        return ChallengeBook(active: nil, finished: book.finished + [challenge])
    }
}
