import Foundation

// Skin School: 60-second lessons with a two-question quiz. Lessons are data (SkinSchool.json in the app), so new
// ones need no code. Every lesson is general information with its sources listed, and only lessons whose wording the
// owner has signed off (`reviewed`) are shown in release builds.

/// English and Indonesian side by side, so lesson files stay self-contained.
public struct LocalizedText: Codable, Hashable, Sendable {
    public var en: String
    public var id: String

    public init(en: String, id: String) {
        self.en = en
        self.id = id
    }

    public func text(for languageCode: String?) -> String {
        languageCode == "id" && !id.isEmpty ? id : en
    }
}

public struct QuizQuestion: Codable, Hashable, Sendable {
    public var question: LocalizedText
    public var options: [LocalizedText]
    /// Index of the right option.
    public var answer: Int
    /// Shown after answering, right or wrong.
    public var explain: LocalizedText

    public init(question: LocalizedText, options: [LocalizedText], answer: Int, explain: LocalizedText) {
        self.question = question
        self.options = options
        self.answer = answer
        self.explain = explain
    }
}

public struct Source: Codable, Hashable, Sendable {
    public var title: String
    public var url: String

    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

public struct Lesson: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// The owner has signed off the wording.
    public var reviewed: Bool
    public var title: LocalizedText
    public var cards: [LocalizedText]
    public var quiz: [QuizQuestion]
    public var sources: [Source]

    public init(id: String, reviewed: Bool, title: LocalizedText, cards: [LocalizedText], quiz: [QuizQuestion], sources: [Source]) {
        self.id = id
        self.reviewed = reviewed
        self.title = title
        self.cards = cards
        self.quiz = quiz
        self.sources = sources
    }
}

public struct CourseUnit: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: LocalizedText
    public var lessons: [Lesson]

    public init(id: String, title: LocalizedText, lessons: [Lesson]) {
        self.id = id
        self.title = title
        self.lessons = lessons
    }
}

public struct Course: Codable, Hashable, Sendable {
    public var units: [CourseUnit]

    public init(units: [CourseUnit]) {
        self.units = units
    }
}

/// What the user has finished. Synced with streaks and rewards.
public struct SchoolProgress: Codable, Equatable, Sendable {
    /// Lesson id → most correct answers ever.
    public var bestScores: [String: Int]
    public var xp: Int

    public static let empty = SchoolProgress(bestScores: [:], xp: 0)

    public init(bestScores: [String: Int], xp: Int) {
        self.bestScores = bestScores
        self.xp = xp
    }

    public static func merged(_ a: SchoolProgress, _ b: SchoolProgress) -> SchoolProgress {
        SchoolProgress(bestScores: a.bestScores.merging(b.bestScores, uniquingKeysWith: max), xp: max(a.xp, b.xp))
    }
}

public enum SkinSchoolEngine {
    public static let lessonXP = 10
    public static let xpPerCorrectAnswer = 5
    public static let minimumCards = 3
    public static let maximumCards = 5
    public static let questionsPerLesson = 2

    public enum LessonState: Equatable, Sendable {
        case done, open, locked, needsPro, hidden
    }

    public static func correctAnswers(_ answers: [Int], quiz: [QuizQuestion]) -> Int {
        zip(answers, quiz).filter { $0 == $1.answer }.count
    }

    /// Finishing a lesson: XP the first time only (replays cannot farm it); the best score is kept.
    public static func completing(_ lessonID: String, correct: Int, of total: Int, progress: SchoolProgress) -> SchoolProgress {
        var updated = progress
        if progress.bestScores[lessonID] == nil {
            updated.xp += lessonXP + xpPerCorrectAnswer * min(correct, total)
        }
        updated.bestScores[lessonID] = max(progress.bestScores[lessonID] ?? 0, correct)
        return updated
    }

    public static func visibleLessons(in course: Course, includeDrafts: Bool) -> [Lesson] {
        course.units.flatMap(\.lessons).filter { includeDrafts || $0.reviewed }
    }

    /// Lessons open one after another along the whole path; units after the free ones need full access.
    public static func state(of lessonID: String, in course: Course, progress: SchoolProgress, hasFullAccess: Bool,
                             includeDrafts: Bool) -> LessonState {
        let path = visibleLessons(in: course, includeDrafts: includeDrafts)
        guard let position = path.firstIndex(where: { $0.id == lessonID }) else { return .hidden }
        if progress.bestScores[lessonID] != nil { return .done }
        let unitIndex = course.units.firstIndex { $0.lessons.contains { $0.id == lessonID } } ?? 0
        if unitIndex >= FreeLimits.freeSchoolUnits && !hasFullAccess { return .needsPro }
        let previousDone = position == 0 || progress.bestScores[path[position - 1].id] != nil
        return previousDone ? .open : .locked
    }

    public static func nextLesson(in course: Course, progress: SchoolProgress, includeDrafts: Bool) -> Lesson? {
        visibleLessons(in: course, includeDrafts: includeDrafts).first { progress.bestScores[$0.id] == nil }
    }

    /// Everything wrong with a lesson's data (empty when it is fine). Used by tests over the shipped lessons.
    public static func problems(in lesson: Lesson) -> [String] {
        var problems: [String] = []
        func check(_ text: LocalizedText, _ what: String) {
            if text.en.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(lesson.id): \(what) has no English") }
            if text.id.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(lesson.id): \(what) has no Indonesian") }
        }
        check(lesson.title, "title")
        if !(minimumCards...maximumCards).contains(lesson.cards.count) {
            problems.append("\(lesson.id): \(lesson.cards.count) cards (needs \(minimumCards)–\(maximumCards))")
        }
        lesson.cards.enumerated().forEach { check($1, "card \($0 + 1)") }
        if lesson.quiz.count != questionsPerLesson { problems.append("\(lesson.id): \(lesson.quiz.count) questions") }
        for (index, question) in lesson.quiz.enumerated() {
            check(question.question, "question \(index + 1)")
            check(question.explain, "explanation \(index + 1)")
            question.options.enumerated().forEach { check($1, "question \(index + 1) option \($0 + 1)") }
            if question.options.count < 2 { problems.append("\(lesson.id): question \(index + 1) has too few options") }
            if !question.options.indices.contains(question.answer) {
                problems.append("\(lesson.id): question \(index + 1) answer is out of range")
            }
        }
        if lesson.sources.isEmpty { problems.append("\(lesson.id): no sources") }
        for source in lesson.sources where !source.url.hasPrefix("https://") || source.title.isEmpty {
            problems.append("\(lesson.id): source \(source.title) is not an https link with a title")
        }
        return problems
    }
}
