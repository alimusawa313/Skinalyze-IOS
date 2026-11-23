import Foundation

// P5 routine builder: extra steps around the four shelf slots, and "don't mix these" warnings from the ingredient
// engine. Warnings are general information about common pairings, never a diagnosis.

public enum RoutinePart: String, CaseIterable, Codable, Sendable {
    case morning, evening
}

/// Steps beyond the four shelf slots (cleanser, toner, moisturizer, sunscreen).
public enum ExtraStepKind: String, CaseIterable, Codable, Sendable {
    case serum, treatment, exfoliant, eyeCream, mask, spotTreatment
}

/// An extra step: a catalog product or a name the user typed, plus the actives it contains (picked by the user when
/// the product isn't in the catalog).
public struct RoutineStep: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var kind: ExtraStepKind
    public var productID: Int?
    public var customName: String?
    public var actives: Set<IngredientCategory>

    public init(id: String = UUID().uuidString, kind: ExtraStepKind, productID: Int? = nil, customName: String? = nil,
                actives: Set<IngredientCategory> = []) {
        self.id = id
        self.kind = kind
        self.productID = productID
        self.customName = customName
        self.actives = actives
    }
}

public struct RoutinePlan: Codable, Equatable, Sendable {
    public var morning: [RoutineStep]
    public var evening: [RoutineStep]

    public static let empty = RoutinePlan(morning: [], evening: [])
    public static let maximumExtraSteps = 6

    public init(morning: [RoutineStep], evening: [RoutineStep]) {
        self.morning = morning
        self.evening = evening
    }

    public subscript(part: RoutinePart) -> [RoutineStep] {
        get { part == .morning ? morning : evening }
        set {
            let capped = Array(newValue.prefix(Self.maximumExtraSteps))
            if part == .morning { morning = capped } else { evening = capped }
        }
    }
}

/// One thing in a routine part, as the advisor sees it.
public struct RoutineItem: Sendable, Equatable {
    public let label: String
    public let categories: Set<IngredientCategory>
    public let isSunscreen: Bool

    public init(label: String, categories: Set<IngredientCategory>, isSunscreen: Bool = false) {
        self.label = label
        self.categories = categories
        self.isSunscreen = isSunscreen
    }
}

public struct RoutineWarning: Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable {
        /// Retinoid with an exfoliating acid.
        case retinoidWithAcid
        /// Retinoid with benzoyl peroxide.
        case retinoidWithBenzoyl
        /// Vitamin C with an exfoliating acid or benzoyl peroxide.
        case vitaminCWithAcidOrBenzoyl
        /// More than one exfoliating product.
        case doubleExfoliation
        /// Retinoid in the morning.
        case retinoidInMorning
        /// Acids or retinoid in the morning with no sunscreen.
        case morningWithoutSunscreen
    }

    public let kind: Kind
    /// The steps involved, by label.
    public let items: [String]
}

public enum RoutineAdvisor {
    static let acids: Set<IngredientCategory> = [.exfoliantAHA, .exfoliantBHA]

    public static func warnings(for items: [RoutineItem], part: RoutinePart) -> [RoutineWarning] {
        func with(_ categories: Set<IngredientCategory>) -> [String] {
            items.filter { !$0.categories.isDisjoint(with: categories) }.map(\.label)
        }
        let retinoid = with([.retinoid]), acid = with(acids), benzoyl = with([.benzoylPeroxide]), vitaminC = with([.vitaminC])
        var warnings: [RoutineWarning] = []
        if !retinoid.isEmpty, !acid.isEmpty {
            warnings.append(.init(kind: .retinoidWithAcid, items: unique(retinoid + acid)))
        }
        if !retinoid.isEmpty, !benzoyl.isEmpty {
            warnings.append(.init(kind: .retinoidWithBenzoyl, items: unique(retinoid + benzoyl)))
        }
        if !vitaminC.isEmpty, !(acid + benzoyl).isEmpty, Set(vitaminC) != Set(acid + benzoyl) {
            warnings.append(.init(kind: .vitaminCWithAcidOrBenzoyl, items: unique(vitaminC + acid + benzoyl)))
        }
        if acid.count > 1 {
            warnings.append(.init(kind: .doubleExfoliation, items: unique(acid)))
        }
        if part == .morning {
            if !retinoid.isEmpty { warnings.append(.init(kind: .retinoidInMorning, items: unique(retinoid))) }
            let sensitising = unique(retinoid + acid)
            if !sensitising.isEmpty, !items.contains(where: \.isSunscreen) {
                warnings.append(.init(kind: .morningWithoutSunscreen, items: sensitising))
            }
        }
        return warnings
    }

    private static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}
