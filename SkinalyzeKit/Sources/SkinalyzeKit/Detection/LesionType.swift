import Foundation

/// The lesion classes the bundled detector (`acneObj28200`) can output.
///
/// `modelLabel` is the exact class label the model emits and the key used by legacy saved scans
/// (`Result.acneCounts`). Never change these strings — existing user data depends on them.
public enum LesionType: String, CaseIterable, Sendable, Codable, Hashable {
    case blackhead
    case whitehead
    case papule
    case pustule
    case nodule
    case darkSpot

    /// Raw class label emitted by the Core ML model and used as the legacy storage key.
    public var modelLabel: String {
        switch self {
        case .blackhead: "blackheads"
        case .whitehead: "whiteheads"
        case .papule: "papules"
        case .pustule: "pustules"
        case .nodule: "nodules"
        case .darkSpot: "dark spot"
        }
    }

    /// `true` for marks (pigmentation) rather than active breakouts.
    public var isMark: Bool { self == .darkSpot }

    /// Parses a model or legacy label, ignoring case and surrounding whitespace.
    public init?(modelLabel: String) {
        let normalized = modelLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = Self.allCases.first(where: { $0.modelLabel == normalized }) else {
            return nil
        }
        self = match
    }
}
