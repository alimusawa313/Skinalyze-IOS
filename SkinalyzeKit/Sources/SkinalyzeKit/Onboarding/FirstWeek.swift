import Foundation

// The starter plan shown at the end of onboarding, the first-week path on Home, and the rules for Pimpi's coach marks.
// Everything here counts effort (showing up, learning, checking), never skin results (FEATURES.md §0 rule 1).

// MARK: - Starter plan

public struct StarterPlan: Equatable, Sendable {
    public let focus: SkinGoal
    /// Two ingredients to look for, from the skin-type guidance (gentle ones first for very sensitive skin).
    public let lookFor: [IngredientNote]
    /// Very or somewhat sensitive skin: patch-test new products first.
    public let patchTestFirst: Bool
    public let firstWeek: [FirstWeekPath.Step]

    /// Which goal leads when several are picked.
    static let priority: [SkinGoal] = [.fewerBreakouts, .fadeMarks, .buildRoutine, .checkProducts, .understand]
    static let strongActives: Set<IngredientCategory> = [.retinoid, .exfoliantAHA, .exfoliantBHA, .benzoylPeroxide, .vitaminC]
    /// Gentle stand-ins when the guidance's first picks are strong actives.
    static let gentle = ["Hyaluronic acid", "Ceramides", "Niacinamide", "Glycerin"]

    public static func make(goals: Set<SkinGoal>, skinType: SkinType, sensitivity: SkinSensitivity) -> StarterPlan {
        let focus = priority.first(where: goals.contains) ?? .understand
        var notes = SkinTypeGuidance.for(skinType).lookFor
        if sensitivity == .very {
            notes = notes.filter { note in
                (IngredientKnowledge.match(note.name)?.categories ?? []).isDisjoint(with: strongActives)
            }
            let fill = gentle.filter { name in !notes.contains { $0.name == name } }
                .map { IngredientNote(name: $0, note: String(localized: "Gentle and widely tolerated.")) }
            notes += fill
        }
        return StarterPlan(focus: focus, lookFor: Array(notes.prefix(2)), patchTestFirst: sensitivity != .notSensitive,
                           firstWeek: FirstWeekPath.Step.allCases)
    }
}

// MARK: - First week

/// What someone has done so far: counts the app already keeps.
public struct FirstWeekFacts: Equatable, Sendable {
    public var scans = 0
    public var shelfProducts = 0
    public var routineDays = 0
    public var lessonsFinished = 0
    public var productChecks = 0
    public var hasCompared = false
    public var chestsOpened = 0
    public var journeyVisited = false
    /// App launches (for coaches that wait for a second visit).
    public var sessions = 0
    public var hasChestWaiting = false

    public init(scans: Int = 0, shelfProducts: Int = 0, routineDays: Int = 0, lessonsFinished: Int = 0,
                productChecks: Int = 0, hasCompared: Bool = false, chestsOpened: Int = 0, journeyVisited: Bool = false,
                sessions: Int = 0, hasChestWaiting: Bool = false) {
        self.scans = scans
        self.shelfProducts = shelfProducts
        self.routineDays = routineDays
        self.lessonsFinished = lessonsFinished
        self.productChecks = productChecks
        self.hasCompared = hasCompared
        self.chestsOpened = chestsOpened
        self.journeyVisited = journeyVisited
        self.sessions = sessions
        self.hasChestWaiting = hasChestWaiting
    }
}

/// Seven small things, one a day suggested. Steps count whenever they're done; missing a day costs nothing.
public enum FirstWeekPath {
    public enum Step: String, CaseIterable, Codable, Sendable {
        case firstScan, routine, lesson, productCheck, compare, chest, journey
    }

    public struct Progress: Equatable, Sendable {
        public let done: Set<Step>
        /// The first step not done yet (nil when complete).
        public let current: Step?
        public var isComplete: Bool { current == nil }
    }

    public static func isDone(_ step: Step, _ facts: FirstWeekFacts) -> Bool {
        switch step {
        case .firstScan: facts.scans >= 1 && facts.shelfProducts >= 1
        case .routine: facts.routineDays >= 1
        case .lesson: facts.lessonsFinished >= 1
        case .productCheck: facts.productChecks >= 1
        case .compare: facts.hasCompared
        case .chest: facts.chestsOpened >= 1
        case .journey: facts.journeyVisited
        }
    }

    public static func progress(_ facts: FirstWeekFacts) -> Progress {
        let done = Set(Step.allCases.filter { isDone($0, facts) })
        return Progress(done: done, current: Step.allCases.first { !done.contains($0) })
    }
}

// MARK: - Coach marks

/// Pimpi pointing at one thing, the first time it matters.
public enum Coach: String, CaseIterable, Codable, Sendable {
    case homePimpi, homeStreak, homeToday, shelf, productPage, deckCompare, chest, school, journey, routineBuilder
    /// The four steps of the tour after the first scan's result (shown in order, never offered on their own).
    case resultIndex, resultChapters, resultHead, resultDone

    public static let resultTour: [Coach] = [.resultIndex, .resultChapters, .resultHead, .resultDone]

    public var isResultTour: Bool { Coach.resultTour.contains(self) }

    /// The tour step after this one (nil after the last, and for every other coach).
    public var nextInTour: Coach? {
        Coach.resultTour.firstIndex(of: self).flatMap { $0 + 1 < Coach.resultTour.count ? Coach.resultTour[$0 + 1] : nil }
    }
}

public struct CoachContext: Equatable, Sendable {
    /// A sheet, a scan or a celebration is on screen.
    public let isBusy: Bool
    public let shownThisSession: Int

    public init(isBusy: Bool, shownThisSession: Int) {
        self.isBusy = isBusy
        self.shownThisSession = shownThisSession
    }
}

/// What the tutorial has done. Synced with the rest of the engagement record; decoded tolerantly.
public struct TutorialState: Codable, Equatable, Sendable {
    public var seen: Set<Coach> = []
    public var tipsOff = false
    public var firstWeekRewarded = false
    public var resultTourDone = false

    public init(seen: Set<Coach> = [], tipsOff: Bool = false, firstWeekRewarded: Bool = false, resultTourDone: Bool = false) {
        self.seen = seen
        self.tipsOff = tipsOff
        self.firstWeekRewarded = firstWeekRewarded
        self.resultTourDone = resultTourDone
    }

    enum CodingKeys: String, CodingKey { case seen, tipsOff, firstWeekRewarded, resultTourDone }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Coaches this version doesn't know (added later) are dropped, not an error.
        seen = Set((try c.decodeIfPresent([String].self, forKey: .seen) ?? []).compactMap(Coach.init(rawValue:)))
        tipsOff = try c.decodeIfPresent(Bool.self, forKey: .tipsOff) ?? false
        firstWeekRewarded = try c.decodeIfPresent(Bool.self, forKey: .firstWeekRewarded) ?? false
        resultTourDone = try c.decodeIfPresent(Bool.self, forKey: .resultTourDone) ?? false
    }

    public func marking(_ coach: Coach) -> TutorialState {
        var copy = self
        copy.seen.insert(coach)
        return copy
    }

    /// Profile → "Replay the tour": every coach and the result tour again; rewards stay earned.
    public func replayingTour() -> TutorialState {
        TutorialState(seen: [], tipsOff: false, firstWeekRewarded: firstWeekRewarded, resultTourDone: false)
    }

    /// Two devices: what was seen anywhere stays seen, a reward is never lost, the newer tips switch wins.
    public static func merged(newer: TutorialState, older: TutorialState) -> TutorialState {
        TutorialState(seen: newer.seen.union(older.seen), tipsOff: newer.tipsOff,
                      firstWeekRewarded: newer.firstWeekRewarded || older.firstWeekRewarded,
                      resultTourDone: newer.resultTourDone || older.resultTourDone)
    }
}

public enum CoachRules {
    public static let maximumPerSession = 2

    public static func canShow(_ coach: Coach, state: TutorialState, facts: FirstWeekFacts, context: CoachContext) -> Bool {
        guard !state.tipsOff, !state.seen.contains(coach), !context.isBusy,
              context.shownThisSession < maximumPerSession else { return false }
        return isRelevant(coach, facts)
    }

    /// The coach's moment has come, and the person hasn't already found the feature on their own.
    static func isRelevant(_ coach: Coach, _ facts: FirstWeekFacts) -> Bool {
        switch coach {
        case .homePimpi, .routineBuilder: true
        case .homeStreak: facts.scans >= 1
        case .homeToday: facts.sessions >= 2
        case .shelf: facts.productChecks == 0
        case .productPage: facts.productChecks < 3
        case .deckCompare: facts.scans >= 2 && !facts.hasCompared
        case .chest: facts.hasChestWaiting && facts.chestsOpened == 0
        case .school: facts.lessonsFinished == 0
        case .journey: !facts.journeyVisited
        case .resultIndex, .resultChapters, .resultHead, .resultDone: false
        }
    }
}
