import Foundation
import Observation
import SkinalyzeKit

/// The first-time tutorial (docs/redesign/ONBOARDING-PLAN.md §5): which Pimpi coach mark is showing, what has been
/// seen, the first-week path's facts, and the result tour. The rules live in `CoachRules` / `FirstWeekPath` (tested);
/// this stores the state, counts sessions, and records the two things the app doesn't track elsewhere (comparing two
/// scans, visiting the Journey).
@Observable
@MainActor
final class TutorialModel {
    private static let stateKey = "tutorialState"
    private static let sessionsKey = "tutorialSessions"
    private static let comparedKey = "tutorialCompared"
    private static let journeyKey = "tutorialJourneyVisited"

    private(set) var state: TutorialState
    /// The coach mark on screen right now (one at a time).
    private(set) var current: Coach?
    private(set) var sessions: Int
    private(set) var hasCompared: Bool
    private(set) var journeyVisited: Bool
    private var shownThisSession = 0
    /// Debug builds: coach marks silenced for UI tests (never saved).
    private var isSilenced = false
    /// Debug builds: a fresh tutorial for this launch, ignoring synced copies.
    private var ignoresSync = false
    private let defaults: UserDefaults
    /// Set by the app shell: what the person has done, and whether a sheet or scan is on screen.
    @ObservationIgnored var factsSource: @MainActor () -> FirstWeekFacts = { FirstWeekFacts() }
    @ObservationIgnored var isBusySource: @MainActor () -> Bool = { false }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.data(forKey: Self.stateKey).flatMap { try? JSONDecoder().decode(TutorialState.self, from: $0) }
            ?? TutorialState()
        sessions = defaults.integer(forKey: Self.sessionsKey)
        hasCompared = defaults.bool(forKey: Self.comparedKey)
        journeyVisited = defaults.bool(forKey: Self.journeyKey)
        #if DEBUG
        // UI tests and screenshots: `-tutorialOff YES` (and demo data, unless `-tutorialOn YES`) keeps coach marks out
        // of the way, so existing tests can tap through. In memory only: it must never reach the saved or synced state.
        isSilenced = defaults.bool(forKey: "tutorialOff") || (DemoData.isRequested && !defaults.bool(forKey: "tutorialOn"))
        // `-resetTutorial YES`: start fresh for this launch, whatever the synced copy says.
        ignoresSync = defaults.bool(forKey: "resetTutorial")
        #endif
    }

    /// The app came to the front.
    func beginSession() {
        sessions += 1
        shownThisSession = 0
        defaults.set(sessions, forKey: Self.sessionsKey)
    }

    /// A screen offers its coach mark; it shows if the rules allow it now.
    @discardableResult
    func offer(_ coach: Coach, facts: FirstWeekFacts, isBusy: Bool) -> Bool {
        guard current == nil, !isSilenced,
              CoachRules.canShow(coach, state: state, facts: facts,
                                 context: CoachContext(isBusy: isBusy, shownThisSession: shownThisSession)) else { return false }
        current = coach
        shownThisSession += 1
        return true
    }

    /// The first of these coaches the rules allow right now, if any.
    func offerFirst(_ coaches: [Coach]) {
        let facts = factsSource()
        let busy = isBusySource()
        for coach in coaches where offer(coach, facts: facts, isBusy: busy) { return }
    }

    /// "Got it" (or a tap anywhere): this coach never shows again. In the result tour, on to the next step.
    func dismiss() {
        guard let current else { return }
        if current.isResultTour {
            self.current = current.nextInTour
            if self.current == nil { finishResultTour() }
            return
        }
        save(state.marking(current))
        self.current = nil
    }

    /// After the first scan's sticker moment: the four-step tour of the result (once).
    func startResultTour() {
        guard !state.resultTourDone, !state.tipsOff, !isSilenced else { return }
        // The tour takes over from a coach mark still up on the screen underneath (it can come back later).
        current = Coach.resultTour.first
    }

    func skipResultTour() {
        guard current?.isResultTour == true else { return }
        current = nil
        finishResultTour()
    }

    /// A screen went away while its coach was up: hide it, but it may come back next time.
    func withdraw(_ coach: Coach) {
        if current == coach { current = nil }
    }

    func noteCompared() {
        hasCompared = true
        defaults.set(true, forKey: Self.comparedKey)
        if current == .deckCompare { dismiss() }
    }

    func noteJourneyVisited() {
        journeyVisited = true
        defaults.set(true, forKey: Self.journeyKey)
    }

    var tipsOff: Bool { state.tipsOff }

    func setTipsOff(_ off: Bool) {
        var copy = state
        copy.tipsOff = off
        save(copy)
        if off { current = nil }
    }

    /// Profile → "Replay the tour".
    func replayTour() {
        save(state.replayingTour())
    }

    var resultTourDone: Bool { state.resultTourDone }

    func finishResultTour() {
        var copy = state
        copy.resultTourDone = true
        save(copy)
    }

    var firstWeekRewarded: Bool { state.firstWeekRewarded }

    func markFirstWeekRewarded() {
        var copy = state
        copy.firstWeekRewarded = true
        save(copy)
    }

    func applySynced(_ merged: TutorialState) {
        guard !ignoresSync else { return }
        save(merged)
    }

    private func save(_ new: TutorialState) {
        state = new
        if let data = try? JSONEncoder().encode(new) { defaults.set(data, forKey: Self.stateKey) }
    }
}

extension TutorialModel {
    /// What the person has done so far, from the counts the app already keeps.
    func facts(scanCount: Int, quests: QuestModel?, school: SchoolModel?,
               defaults: UserDefaults = .standard) -> FirstWeekFacts {
        FirstWeekFacts(
            scans: scanCount,
            shelfProducts: UserProfile.currentProductIDs.filter { $0 > 0 }.count,
            routineDays: EngagementStore(defaults: defaults).doneDays.count,
            lessonsFinished: school?.progress.bestScores.count ?? 0,
            productChecks: ProductCheckLedger().count,
            hasCompared: hasCompared,
            chestsOpened: quests?.ledger.chestsOpened ?? 0,
            journeyVisited: journeyVisited,
            sessions: sessions,
            hasChestWaiting: (quests?.ledger.chestsWaiting ?? 0) > 0
        )
    }
}
