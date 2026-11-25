import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Onboarding flow")
struct OnboardingFlowTests {
    @Test("Scenes run in order and end with the first scan; Back stops at the start")
    func order() {
        #expect(OnboardingFlow.scenes.first == .wake)
        #expect(OnboardingFlow.scenes.last == .firstScan)
        #expect(OnboardingFlow.next(after: .wake) == .hello)
        #expect(OnboardingFlow.next(after: .firstScan) == nil)
        #expect(OnboardingFlow.previous(before: .wake) == nil)
        #expect(OnboardingFlow.previous(before: .goals) == .hello)
    }

    @Test("Only name and shelf are optional; questions need an answer before Continue")
    func requiredAnswers() {
        #expect(OnboardingFlow.optionalScenes == [.hello, .shelf])
        var answers = OnboardingAnswers()
        #expect(OnboardingFlow.canContinue(.hello, answers))
        #expect(!OnboardingFlow.canContinue(.goals, answers))
        #expect(!OnboardingFlow.canContinue(.skinCheck, answers))
        #expect(!OnboardingFlow.canContinue(.sensitivity, answers))
        answers.goals = [.fadeMarks]
        answers.skinType = .dry
        answers.sensitivity = .somewhat
        #expect(OnboardingFlow.canContinue(.goals, answers))
        #expect(OnboardingFlow.canContinue(.skinCheck, answers))
        #expect(OnboardingFlow.canContinue(.sensitivity, answers))
    }

    @Test("Progress grows with each scene and reaches 1 on the last")
    func progress() {
        let values = OnboardingFlow.scenes.map(OnboardingFlow.progress)
        #expect(values == values.sorted())
        #expect(values.last == 1)
        #expect(values.first! > 0)
    }

    @Test("Resuming: a stored scene comes back; an unknown one starts over")
    func resume() {
        #expect(OnboardingFlow.resume(from: OnboardingScene.promise.rawValue) == .promise)
        #expect(OnboardingFlow.resume(from: "nonsense") == .wake)
        #expect(OnboardingFlow.resume(from: nil) == .wake)
    }
}

@Suite("Skin type quiz")
struct SkinTypeQuizTests {
    typealias A = SkinTypeQuiz.Answer

    @Test("Clear answers give the obvious type")
    func clearCases() {
        #expect(SkinTypeQuiz.result(tZone: .oily, cheeks: .oily, afterWashing: .oily) == .oily)
        #expect(SkinTypeQuiz.result(tZone: .dry, cheeks: .dry, afterWashing: .dry) == .dry)
        #expect(SkinTypeQuiz.result(tZone: .oily, cheeks: .dry, afterWashing: .balanced) == .combination)
        #expect(SkinTypeQuiz.result(tZone: .oily, cheeks: .balanced, afterWashing: .balanced) == .combination)
        #expect(SkinTypeQuiz.result(tZone: .balanced, cheeks: .balanced, afterWashing: .balanced) == .normal)
    }

    @Test("Every one of the 27 answer combinations gives a type, and oily/dry are never mixed up")
    func exhaustive() {
        for t in A.allCases {
            for c in A.allCases {
                for w in A.allCases {
                    let type = SkinTypeQuiz.result(tZone: t, cheeks: c, afterWashing: w)
                    if t != .oily && c != .oily && w != .oily { #expect(type != .oily && type != .combination) }
                    if t != .dry && c != .dry && w != .dry { #expect(type != .dry) }
                }
            }
        }
    }

    @Test("Three questions, three answers each")
    func shape() {
        #expect(SkinTypeQuiz.Question.allCases.count == 3)
        #expect(A.allCases.count == 3)
    }
}

@Suite("Starter plan")
struct StarterPlanTests {
    @Test("The focus follows the first goal in a fixed priority; no goals means understanding")
    func focus() {
        #expect(StarterPlan.make(goals: [.checkProducts, .fewerBreakouts], skinType: .oily, sensitivity: .notSensitive).focus == .fewerBreakouts)
        #expect(StarterPlan.make(goals: [], skinType: .normal, sensitivity: .notSensitive).focus == .understand)
    }

    @Test("Two ingredients to look for, from the skin-type guidance")
    func ingredients() {
        let plan = StarterPlan.make(goals: [.fadeMarks], skinType: .dry, sensitivity: .notSensitive)
        #expect(plan.lookFor.count == 2)
        let guidance = SkinTypeGuidance.for(.dry).lookFor.map(\.name)
        #expect(plan.lookFor.allSatisfy { guidance.contains($0.name) })
    }

    @Test("Very sensitive skin is never pointed at strong actives first")
    func sensitive() {
        let plan = StarterPlan.make(goals: [.fewerBreakouts], skinType: .normal, sensitivity: .very)
        let strong: Set<IngredientCategory> = [.retinoid, .exfoliantAHA, .exfoliantBHA, .benzoylPeroxide, .vitaminC]
        for note in plan.lookFor {
            let categories = IngredientKnowledge.match(note.name)?.categories ?? []
            #expect(categories.isDisjoint(with: strong), "\(note.name) is a strong active")
        }
        #expect(plan.patchTestFirst)
    }

    @Test("Every plan carries the first-week path and today's first step")
    func firstWeek() {
        let plan = StarterPlan.make(goals: [.buildRoutine], skinType: .combination, sensitivity: .somewhat)
        #expect(plan.firstWeek == FirstWeekPath.Step.allCases)
        #expect(plan.firstWeek.first == .firstScan)
    }
}

@Suite("First week path")
struct FirstWeekPathTests {
    @Test("Nothing done: the first step is current and nothing is complete")
    func fresh() {
        let progress = FirstWeekPath.progress(FirstWeekFacts())
        #expect(progress.current == .firstScan)
        #expect(progress.done.isEmpty)
        #expect(!progress.isComplete)
    }

    @Test("Steps count as soon as they're done, in any order; the current step is the first one left")
    func anyOrder() {
        var facts = FirstWeekFacts()
        facts.lessonsFinished = 1
        facts.productChecks = 2
        var progress = FirstWeekPath.progress(facts)
        #expect(progress.done == [.lesson, .productCheck])
        #expect(progress.current == .firstScan)
        facts.scans = 1
        facts.shelfProducts = 1
        progress = FirstWeekPath.progress(facts)
        #expect(progress.current == .routine)
    }

    @Test("The first scan step needs a scan and one product on the shelf")
    func firstStep() {
        var facts = FirstWeekFacts()
        facts.scans = 1
        #expect(!FirstWeekPath.progress(facts).done.contains(.firstScan))
        facts.shelfProducts = 1
        #expect(FirstWeekPath.progress(facts).done.contains(.firstScan))
    }

    @Test("Everything done completes the path")
    func complete() {
        let facts = FirstWeekFacts(scans: 2, shelfProducts: 1, routineDays: 1, lessonsFinished: 1, productChecks: 1,
                                   hasCompared: true, chestsOpened: 1, journeyVisited: true)
        let progress = FirstWeekPath.progress(facts)
        #expect(progress.isComplete)
        #expect(progress.current == nil)
        #expect(progress.done.count == FirstWeekPath.Step.allCases.count)
    }
}

@Suite("Coach marks")
struct CoachRulesTests {
    private let busyFree = CoachContext(isBusy: false, shownThisSession: 0)

    @Test("A coach shows once, only when relevant, never while busy, at most two a session")
    func basics() {
        var state = TutorialState()
        let facts = FirstWeekFacts(scans: 1)
        #expect(CoachRules.canShow(.homeStreak, state: state, facts: facts, context: busyFree))
        #expect(!CoachRules.canShow(.homeStreak, state: state, facts: facts, context: CoachContext(isBusy: true, shownThisSession: 0)))
        #expect(!CoachRules.canShow(.homeStreak, state: state, facts: facts, context: CoachContext(isBusy: false, shownThisSession: 2)))
        state = state.marking(.homeStreak)
        #expect(!CoachRules.canShow(.homeStreak, state: state, facts: facts, context: busyFree))
    }

    @Test("Coaches wait for their moment: Compare needs two scans, the streak needs one")
    func eligibility() {
        let state = TutorialState()
        #expect(!CoachRules.canShow(.deckCompare, state: state, facts: FirstWeekFacts(scans: 1), context: busyFree))
        #expect(CoachRules.canShow(.deckCompare, state: state, facts: FirstWeekFacts(scans: 2), context: busyFree))
        #expect(!CoachRules.canShow(.homeStreak, state: state, facts: FirstWeekFacts(), context: busyFree))
    }

    @Test("Someone who already used a feature never gets its coach")
    func alreadyUsed() {
        let state = TutorialState()
        #expect(!CoachRules.canShow(.deckCompare, state: state, facts: FirstWeekFacts(scans: 5, hasCompared: true), context: busyFree))
        #expect(!CoachRules.canShow(.shelf, state: state, facts: FirstWeekFacts(productChecks: 3), context: busyFree))
    }

    @Test("Tips off silences every coach; replaying the tour clears what was seen but keeps rewards")
    func offAndReplay() {
        var state = TutorialState()
        state.tipsOff = true
        #expect(!CoachRules.canShow(.homePimpi, state: state, facts: FirstWeekFacts(), context: busyFree))
        state = TutorialState(seen: [.homePimpi, .shelf], tipsOff: true, firstWeekRewarded: true, resultTourDone: true)
        let replayed = state.replayingTour()
        #expect(replayed.seen.isEmpty && !replayed.tipsOff && !replayed.resultTourDone && replayed.firstWeekRewarded)
    }

    @Test("Two devices: seen coaches combine, a reward is never lost, the newer tips switch wins")
    func merge() {
        let older = TutorialState(seen: [.shelf], tipsOff: true, firstWeekRewarded: true, resultTourDone: false)
        let newer = TutorialState(seen: [.homePimpi], tipsOff: false, firstWeekRewarded: false, resultTourDone: true)
        let merged = TutorialState.merged(newer: newer, older: older)
        #expect(merged.seen == [.shelf, .homePimpi])
        #expect(merged.firstWeekRewarded && merged.resultTourDone && !merged.tipsOff)
    }

    @Test("The tutorial travels in the synced engagement record: old copies load, two devices merge")
    func synced() throws {
        let old = try JSONDecoder().decode(SyncedEngagement.self, from: Data(#"{"doneDays":[]}"#.utf8))
        #expect(old.tutorial == TutorialState())
        var a = SyncedEngagement.empty
        a.tutorial = TutorialState(seen: [.shelf])
        a.updatedAt = Date(timeIntervalSince1970: 10)
        var b = SyncedEngagement.empty
        b.tutorial = TutorialState(seen: [.journey], firstWeekRewarded: true)
        b.updatedAt = Date(timeIntervalSince1970: 20)
        let merged = SyncedEngagement.merged(a, b)
        #expect(merged.tutorial.seen == [.shelf, .journey] && merged.tutorial.firstWeekRewarded)
    }

    @Test("The result tour runs in order and is never offered as a coach on its own")
    func resultTour() {
        #expect(Coach.resultIndex.nextInTour == .resultChapters)
        #expect(Coach.resultDone.nextInTour == nil)
        #expect(Coach.shelf.nextInTour == nil)
        for step in Coach.resultTour {
            #expect(!CoachRules.canShow(step, state: TutorialState(), facts: FirstWeekFacts(scans: 1), context: busyFree))
        }
    }

    @Test("Older saves without tutorial fields still decode")
    func tolerantDecoding() throws {
        let state = try JSONDecoder().decode(TutorialState.self, from: Data("{}".utf8))
        #expect(state == TutorialState())
        let future = try JSONDecoder().decode(TutorialState.self, from: Data(#"{"seen":["homePimpi","someFutureCoach"]}"#.utf8))
        #expect(future.seen == [.homePimpi])
    }
}

@Suite("First-week reward")
struct FirstWeekRewardTests {
    @Test("The scarf is never in a chest, even when every other outfit is owned")
    func notInChests() {
        var ledger = RewardLedger.empty
        ledger.chestsWaiting = 20
        for _ in 0..<20 {
            let (next, reward) = RewardEngine.openChest(ledger, isPro: true)
            #expect(reward?.outfit != .scarf)
            ledger = next
        }
        #expect(!ledger.unlocked.contains(.scarf))
    }

    @Test("Finishing the first week gives the scarf and puts it on, once")
    func granted() {
        let ledger = RewardEngine.grantingFirstWeekReward(.empty)
        #expect(ledger.unlocked.contains(.scarf) && ledger.worn == .scarf)
        var changed = ledger
        changed.worn = .bow
        #expect(RewardEngine.grantingFirstWeekReward(changed) == changed)
    }

    @Test("A ledger holding an outfit this version doesn't know still loads")
    func tolerant() throws {
        let json = #"{"points":5,"unlocked":["bow","jetpack"],"worn":"jetpack"}"#
        let ledger = try JSONDecoder().decode(RewardLedger.self, from: Data(json.utf8))
        #expect(ledger.points == 5 && ledger.unlocked == [.bow] && ledger.worn == nil)
    }
}
