import Foundation

// The first-run experience (docs/redesign/ONBOARDING-PLAN.md): ten short scenes hosted by Pimpi, ending in the first
// scan. Pure rules here; the scenes themselves live in the app.

/// What someone wants from the app. Stored comma-separated under the legacy `goals` key (raw values unchanged).
public enum SkinGoal: String, CaseIterable, Codable, Sendable, Hashable {
    case fewerBreakouts, fadeMarks, understand, checkProducts, buildRoutine
}

/// How skin reacts to new products. Raw values are the legacy stored strings.
public enum SkinSensitivity: String, CaseIterable, Codable, Sendable, Hashable {
    case notSensitive = "Not sensitive"
    case somewhat = "Somewhat sensitive"
    case very = "Very sensitive"
}

public enum OnboardingScene: String, CaseIterable, Codable, Sendable {
    case wake, hello, goals, skinCheck, sensitivity, shelf, promise, plan, camera, firstScan
}

/// Answers gathered so far.
public struct OnboardingAnswers: Equatable, Sendable {
    public var name = ""
    public var goals: Set<SkinGoal> = []
    public var skinType: SkinType?
    public var sensitivity: SkinSensitivity?

    public init() {}
}

public enum OnboardingFlow {
    public static let scenes = OnboardingScene.allCases
    /// Scenes with a Skip.
    public static let optionalScenes: Set<OnboardingScene> = [.hello, .shelf]

    public static func next(after scene: OnboardingScene) -> OnboardingScene? {
        scenes.firstIndex(of: scene).flatMap { $0 + 1 < scenes.count ? scenes[$0 + 1] : nil }
    }

    public static func previous(before scene: OnboardingScene) -> OnboardingScene? {
        scenes.firstIndex(of: scene).flatMap { $0 > 0 ? scenes[$0 - 1] : nil }
    }

    /// The questions need an answer; everything else can go on.
    public static func canContinue(_ scene: OnboardingScene, _ answers: OnboardingAnswers) -> Bool {
        switch scene {
        case .goals: !answers.goals.isEmpty
        case .skinCheck: answers.skinType != nil
        case .sensitivity: answers.sensitivity != nil
        default: true
        }
    }

    /// How far along Pimpi's path (0…1], for the progress walk at the top.
    public static func progress(_ scene: OnboardingScene) -> Double {
        Double((scenes.firstIndex(of: scene) ?? 0) + 1) / Double(scenes.count)
    }

    /// Where to pick up after the app was closed mid-onboarding.
    public static func resume(from stored: String?) -> OnboardingScene {
        stored.flatMap(OnboardingScene.init(rawValue:)) ?? .wake
    }
}

// MARK: - Skin type quiz

/// Three everyday questions instead of asking people to know their skin type. Each answer leans oily, balanced or
/// dry; the T-zone and the cheeks are scored separately so combination skin shows up.
public enum SkinTypeQuiz {
    public enum Question: String, CaseIterable, Sendable {
        /// "By midday, my forehead and nose are…"
        case tZone
        /// "My cheeks usually feel…"
        case cheeks
        /// "Half an hour after washing (nothing on), my skin feels…"
        case afterWashing
    }

    public enum Answer: Int, CaseIterable, Sendable {
        case oily = 1, balanced = 0, dry = -1
    }

    public static func result(tZone: Answer, cheeks: Answer, afterWashing: Answer) -> SkinType {
        let t = tZone.rawValue * 2 + afterWashing.rawValue
        let c = cheeks.rawValue * 2 + afterWashing.rawValue
        switch (t, c) {
        case let (t, c) where t > 0 && c > 0: return .oily
        case let (t, c) where t < 0 && c < 0: return .dry
        case let (t, c) where t > 0 || c > 0: return .combination
        case let (t, c) where t < 0 || c < 0: return .dry
        default: return .normal
        }
    }
}
