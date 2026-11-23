import Foundation
import Testing
@testable import SkinalyzeKit

/// Skin School: lessons as data, quiz scoring, XP, and the order lessons unlock in.
@Suite("Skin School")
struct SkinSchoolTests {
    private func text(_ s: String) -> LocalizedText { LocalizedText(en: s, id: "id: " + s) }

    private func lesson(_ id: String, reviewed: Bool = true) -> Lesson {
        Lesson(id: id, reviewed: reviewed, title: text(id),
               cards: [text("one"), text("two"), text("three")],
               quiz: [QuizQuestion(question: text("q1"), options: [text("a"), text("b"), text("c")], answer: 1, explain: text("e1")),
                      QuizQuestion(question: text("q2"), options: [text("a"), text("b"), text("c")], answer: 2, explain: text("e2"))],
               sources: [Source(title: "Source", url: "https://example.org")])
    }

    private var course: Course {
        Course(units: [
            CourseUnit(id: "basics", title: text("Basics"), lessons: [lesson("a"), lesson("b")]),
            CourseUnit(id: "more", title: text("More"), lessons: [lesson("c"), lesson("d", reviewed: false)]),
        ])
    }

    // MARK: Text

    @Test("Indonesian readers get Indonesian; everyone else English")
    func language() {
        let value = LocalizedText(en: "Hello", id: "Halo")
        #expect(value.text(for: "id") == "Halo")
        #expect(value.text(for: "en") == "Hello")
        #expect(value.text(for: "fr") == "Hello")
        #expect(value.text(for: nil) == "Hello")
    }

    // MARK: Quiz and XP

    @Test("The quiz counts correct answers")
    func scoring() {
        let quiz = lesson("a").quiz
        #expect(SkinSchoolEngine.correctAnswers([1, 2], quiz: quiz) == 2)
        #expect(SkinSchoolEngine.correctAnswers([0, 2], quiz: quiz) == 1)
        #expect(SkinSchoolEngine.correctAnswers([0], quiz: quiz) == 0) // unanswered questions are wrong
    }

    @Test("XP is earned the first time a lesson is finished, never again; the best score is kept")
    func xpOnce() {
        let first = SkinSchoolEngine.completing("a", correct: 1, of: 2, progress: .empty)
        #expect(first.xp == SkinSchoolEngine.lessonXP + SkinSchoolEngine.xpPerCorrectAnswer)
        let replay = SkinSchoolEngine.completing("a", correct: 2, of: 2, progress: first)
        #expect(replay.xp == first.xp)
        #expect(replay.bestScores["a"] == 2)
        let worse = SkinSchoolEngine.completing("a", correct: 0, of: 2, progress: replay)
        #expect(worse.bestScores["a"] == 2)
    }

    // MARK: The path

    @Test("Lessons open in order: the first is open, the next opens when the one before is finished")
    func order() {
        let free = SkinSchoolEngine.state(of: "a", in: course, progress: .empty, hasFullAccess: false, includeDrafts: false)
        #expect(free == .open)
        #expect(SkinSchoolEngine.state(of: "b", in: course, progress: .empty, hasFullAccess: false, includeDrafts: false) == .locked)
        let done = SkinSchoolEngine.completing("a", correct: 2, of: 2, progress: .empty)
        #expect(SkinSchoolEngine.state(of: "a", in: course, progress: done, hasFullAccess: false, includeDrafts: false) == .done)
        #expect(SkinSchoolEngine.state(of: "b", in: course, progress: done, hasFullAccess: false, includeDrafts: false) == .open)
    }

    @Test("Only the first unit is free; later units need Pro")
    func freeUnits() {
        var progress = SkinSchoolEngine.completing("a", correct: 2, of: 2, progress: .empty)
        progress = SkinSchoolEngine.completing("b", correct: 2, of: 2, progress: progress)
        #expect(SkinSchoolEngine.state(of: "c", in: course, progress: progress, hasFullAccess: false, includeDrafts: false) == .needsPro)
        #expect(SkinSchoolEngine.state(of: "c", in: course, progress: progress, hasFullAccess: true, includeDrafts: false) == .open)
        #expect(FreeLimits.freeSchoolUnits == 1)
    }

    @Test("Lessons whose wording is not yet signed off are hidden unless drafts are shown")
    func drafts() {
        #expect(SkinSchoolEngine.visibleLessons(in: course, includeDrafts: false).map(\.id) == ["a", "b", "c"])
        #expect(SkinSchoolEngine.visibleLessons(in: course, includeDrafts: true).map(\.id) == ["a", "b", "c", "d"])
        #expect(SkinSchoolEngine.state(of: "d", in: course, progress: .empty, hasFullAccess: true, includeDrafts: false) == .hidden)
    }

    @Test("The next lesson is the first one not finished yet")
    func next() {
        #expect(SkinSchoolEngine.nextLesson(in: course, progress: .empty, includeDrafts: false)?.id == "a")
        let done = SkinSchoolEngine.completing("a", correct: 2, of: 2, progress: .empty)
        #expect(SkinSchoolEngine.nextLesson(in: course, progress: done, includeDrafts: false)?.id == "b")
    }

    // MARK: Checking lesson data

    @Test("A well-formed lesson passes the checks")
    func validLesson() {
        #expect(SkinSchoolEngine.problems(in: lesson("a")).isEmpty)
    }

    @Test("Lesson checks catch missing pieces")
    func invalidLesson() {
        var bad = lesson("x")
        bad.cards = [text("only one")]
        bad.quiz[0].answer = 7
        bad.sources = []
        bad.title = LocalizedText(en: "Title", id: "")
        let problems = SkinSchoolEngine.problems(in: bad)
        #expect(problems.count >= 4)
    }

    // MARK: Progress across devices

    @Test("Progress from two devices combines: every finished lesson, best scores, most XP")
    func mergesProgress() {
        let phone = SkinSchoolEngine.completing("a", correct: 1, of: 2, progress: .empty)
        let tablet = SkinSchoolEngine.completing("b", correct: 2, of: 2,
                                                  progress: SkinSchoolEngine.completing("a", correct: 2, of: 2, progress: .empty))
        let merged = SchoolProgress.merged(phone, tablet)
        #expect(merged.bestScores == ["a": 2, "b": 2])
        #expect(merged.xp == max(phone.xp, tablet.xp))
        #expect(merged == SchoolProgress.merged(tablet, phone))
    }

    @Test("Synced engagement saved before Skin School existed still loads")
    func oldSyncedCopyLoads() throws {
        var older = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SyncedEngagement.empty)) as! [String: Any]
        older.removeValue(forKey: "school")
        let decoded = try JSONDecoder().decode(SyncedEngagement.self, from: JSONSerialization.data(withJSONObject: older))
        #expect(decoded.school == .empty)
    }
}
