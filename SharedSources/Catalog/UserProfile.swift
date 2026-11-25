import Foundation
import SkinalyzeKit

/// `@AppStorage` keys. Legacy keys are kept exactly so existing users' answers carry over.
enum UserProfile {
    enum Key {
        static let name = "userName"
        static let skinType = "skinType"
        static let sensitivity = "skinSensitivity"
        static let goals = "goals"
        static let onboardingComplete = "onboardingComplete"
        static let legacyUseSkincare = "useSkincare"
        static let cleanserID = "cleanserUsedID"
        static let tonerID = "tonerUsedID"
        static let moisturizerID = "moisturizerUsedID"
        static let sunscreenID = "sunscreenUsedID"
        static let voiceGuidance = "voiceGuidance"
    }

    /// The kit's types (raw values are the legacy stored strings); titles and icons below.
    typealias Sensitivity = SkinSensitivity
    typealias Goal = SkinGoal

    static func goals(from stored: String) -> Set<Goal> {
        Set(stored.split(separator: ",").compactMap { Goal(rawValue: String($0)) })
    }

    static func store(_ goals: Set<Goal>) -> String {
        goals.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Current product slots (legacy @AppStorage IDs; `0` = none).
    static var currentProductIDs: [Int] {
        let defaults = UserDefaults.standard
        return [Key.cleanserID, Key.tonerID, Key.moisturizerID, Key.sunscreenID].map { defaults.integer(forKey: $0) }
    }
}

extension SkinSensitivity: Identifiable {
    public var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

extension SkinGoal: Identifiable {
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .fewerBreakouts: String(localized: "Fewer breakouts")
        case .fadeMarks: String(localized: "Fade dark marks")
        case .understand: String(localized: "Understand my skin")
        case .checkProducts: String(localized: "Check my products")
        case .buildRoutine: String(localized: "Build a routine")
        }
    }

    var systemImage: String {
        switch self {
        case .fewerBreakouts: "sparkle.magnifyingglass"
        case .fadeMarks: "circle.lefthalf.filled"
        case .understand: "chart.line.downtrend.xyaxis"
        case .checkProducts: "drop"
        case .buildRoutine: "checklist"
        }
    }
}
