import Foundation
import Observation
import OSLog
import SkinalyzeKit

/// Skin School lessons (from SkinSchool.json) and what the user has finished.
@Observable
@MainActor
final class SchoolModel {
    private static let progressKey = "schoolProgress"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "SkinSchool")

    let course: Course
    private(set) var progress: SchoolProgress
    private let defaults: UserDefaults

    /// Lessons whose wording the owner has not signed off show in debug builds only.
    static var includesDrafts: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static let languageCode = Locale.current.language.languageCode?.identifier

    init(defaults: UserDefaults = .standard, course: Course? = nil) {
        self.defaults = defaults
        self.course = course ?? Self.loadBundledCourse()
        progress = defaults.data(forKey: Self.progressKey).flatMap { try? JSONDecoder().decode(SchoolProgress.self, from: $0) } ?? .empty
    }

    static func loadBundledCourse(bundle: Bundle = .main) -> Course {
        guard let url = bundle.url(forResource: "SkinSchool", withExtension: "json") else {
            logger.error("SkinSchool.json is missing from the app")
            return Course(units: [])
        }
        do {
            return try JSONDecoder().decode(Course.self, from: Data(contentsOf: url))
        } catch {
            logger.error("SkinSchool.json could not be read: \(error.localizedDescription)")
            return Course(units: [])
        }
    }

    var visibleLessons: [Lesson] { SkinSchoolEngine.visibleLessons(in: course, includeDrafts: Self.includesDrafts) }

    var nextLesson: Lesson? { SkinSchoolEngine.nextLesson(in: course, progress: progress, includeDrafts: Self.includesDrafts) }

    func state(of lesson: Lesson, hasFullAccess: Bool) -> SkinSchoolEngine.LessonState {
        SkinSchoolEngine.state(of: lesson.id, in: course, progress: progress, hasFullAccess: hasFullAccess,
                               includeDrafts: Self.includesDrafts)
    }

    /// Whether a lesson can be taken right now (for today's quests).
    func hasOpenLesson(hasFullAccess: Bool) -> Bool {
        visibleLessons.contains { state(of: $0, hasFullAccess: hasFullAccess) == .open }
    }

    /// Returns the XP gained (0 for a replay).
    @discardableResult
    func complete(_ lesson: Lesson, correct: Int) -> Int {
        let updated = SkinSchoolEngine.completing(lesson.id, correct: correct, of: lesson.quiz.count, progress: progress)
        let gained = updated.xp - progress.xp
        save(updated)
        return gained
    }

    /// Takes progress merged from the user's other devices.
    func applySynced(_ merged: SchoolProgress) {
        save(merged)
    }

    func text(_ value: LocalizedText) -> String { value.text(for: Self.languageCode) }

    private func save(_ updated: SchoolProgress) {
        guard updated != progress else { return }
        progress = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Self.progressKey)
    }
}
