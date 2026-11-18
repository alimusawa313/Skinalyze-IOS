import Foundation

// MARK: - Knowledge

public enum IngredientCategory: String, CaseIterable, Sendable, Hashable, Codable {
    case humectant, emollient, barrier, exfoliantAHA, exfoliantBHA, retinoid, benzoylPeroxide, azelaicAcid
    case niacinamide, vitaminC, soothing, fragrance, essentialOil, dryingAlcohol, harshSurfactant, comedogenicOil
}

public struct IngredientEntry: Sendable, Hashable {
    public let name: String
    public let aliases: [String]
    public let categories: Set<IngredientCategory>
}

/// A small, curated knowledge base of common actives and irritants (PLAN.md §11.6). Intentionally conservative:
/// unknown ingredients are neutral, never guessed.
public enum IngredientKnowledge {
    public static let entries: [IngredientEntry] = [
        IngredientEntry(name: "Glycerin", aliases: ["glycerine", "gliserin"], categories: [.humectant]),
        IngredientEntry(name: "Hyaluronic acid", aliases: ["sodium hyaluronate", "hyaluronan"], categories: [.humectant]),
        IngredientEntry(name: "Panthenol", aliases: ["provitamin b5", "d-panthenol"], categories: [.humectant, .soothing]),
        IngredientEntry(name: "Ceramides", aliases: ["ceramide np", "ceramide ap", "ceramide eop", "ceramide 3", "ceramide"], categories: [.barrier]),
        IngredientEntry(name: "Squalane", aliases: [], categories: [.emollient]),
        IngredientEntry(name: "Niacinamide", aliases: ["nicotinamide", "vitamin b3"], categories: [.niacinamide]),
        IngredientEntry(name: "Salicylic acid", aliases: ["bha", "beta hydroxy acid", "betaine salicylate"], categories: [.exfoliantBHA]),
        IngredientEntry(name: "Glycolic acid", aliases: [], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Lactic acid", aliases: [], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Mandelic acid", aliases: [], categories: [.exfoliantAHA]),
        IngredientEntry(name: "Retinol", aliases: ["retinal", "retinaldehyde", "retinyl palmitate", "hydroxypinacolone retinoate", "adapalene"], categories: [.retinoid]),
        IngredientEntry(name: "Benzoyl peroxide", aliases: [], categories: [.benzoylPeroxide]),
        IngredientEntry(name: "Azelaic acid", aliases: [], categories: [.azelaicAcid]),
        IngredientEntry(name: "Vitamin C", aliases: ["ascorbic acid", "sodium ascorbyl phosphate", "ascorbyl glucoside", "ethyl ascorbic acid"], categories: [.vitaminC]),
        IngredientEntry(name: "Centella asiatica", aliases: ["cica", "madecassoside", "asiaticoside"], categories: [.soothing]),
        IngredientEntry(name: "Allantoin", aliases: [], categories: [.soothing]),
        IngredientEntry(name: "Green tea extract", aliases: ["camellia sinensis leaf extract"], categories: [.soothing]),
        IngredientEntry(name: "Fragrance", aliases: ["parfum", "perfume", "aroma", "fragrance"], categories: [.fragrance]),
        IngredientEntry(name: "Essential oils", aliases: ["lavender oil", "peppermint oil", "eucalyptus oil", "citrus oil", "lemon peel oil", "tea tree oil", "melaleuca alternifolia leaf oil"], categories: [.essentialOil]),
        IngredientEntry(name: "Drying alcohol", aliases: ["alcohol denat", "alcohol denat.", "denatured alcohol", "sd alcohol", "isopropyl alcohol", "ethanol"], categories: [.dryingAlcohol]),
        IngredientEntry(name: "Sodium lauryl sulfate", aliases: ["sls", "ammonium lauryl sulfate"], categories: [.harshSurfactant]),
        IngredientEntry(name: "Coconut oil", aliases: ["cocos nucifera oil", "cocos nucifera (coconut) oil"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Isopropyl myristate", aliases: ["isopropyl palmitate"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Cocoa butter", aliases: ["theobroma cacao seed butter"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Lanolin", aliases: ["acetylated lanolin"], categories: [.comedogenicOil]),
        IngredientEntry(name: "Mineral oil", aliases: ["paraffinum liquidum"], categories: [.emollient]),
    ]

    private static let index: [String: IngredientEntry] = {
        var map: [String: IngredientEntry] = [:]
        for entry in entries {
            for key in [entry.name.lowercased()] + entry.aliases { map[key] = entry }
        }
        return map
    }()

    /// Exact/alias match, then contained-name match, then a tolerant match for OCR slips (one character off).
    public static func match(_ ingredient: String) -> IngredientEntry? {
        let key = ingredient.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = index[key] { return exact }
        let longestContained = index
            .filter { key.count > 4 && $0.key.count > 4 && key.contains($0.key) }
            .max { $0.key.count < $1.key.count }
        if let longestContained { return longestContained.value }
        return index.first { $0.key.count >= 6 && editDistance($0.key, key) <= 1 }?.value
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= 1 else { return 2 }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}

// MARK: - Parsing

public enum IngredientParser {
    /// Turns raw label/OCR/web text into a normalized ingredient list (INCI order preserved, duplicates removed).
    public static func parse(_ text: String) -> [String] {
        var body = text.lowercased()
        if let header = body.range(of: "ingredients:") { body = String(body[header.upperBound...]) }
        if let tail = body.range(of: "may contain") { body = String(body[..<tail.lowerBound]) }
        body = body.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        let separators = CharacterSet(charactersIn: ",;•·\n")
        var seen = Set<String>()
        return body
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".*"))) }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty && $0.count < 80 && seen.insert($0).inserted }
    }
}

// MARK: - Verdicts

public enum ProductVerdict: String, CaseIterable, Sendable, Hashable, Codable {
    case goodMatch, useWithCaution, probablyNotForYou, notEnoughInfo

    public var title: String {
        switch self {
        case .goodMatch: String(localized: "Good match")
        case .useWithCaution: String(localized: "Use with care")
        case .probablyNotForYou: String(localized: "Probably not for you")
        case .notEnoughInfo: String(localized: "Not enough info")
        }
    }

    public var systemImage: String {
        switch self {
        case .goodMatch: "checkmark.seal"
        case .useWithCaution: "exclamationmark.circle"
        case .probablyNotForYou: "xmark.circle"
        case .notEnoughInfo: "questionmark.circle"
        }
    }
}

public struct VerdictReason: Sendable, Hashable, Identifiable {
    public enum Kind: Int, Sendable, Hashable { case negative = 0, caution = 1, positive = 2 }
    public let ruleID: String
    public let kind: Kind
    public let text: String
    public var id: String { ruleID }
}

public struct VerdictProfile: Sendable, Hashable {
    public let skinType: SkinType
    public let isSensitive: Bool
    public let latestCounts: LesionCounts
    public let routineCategories: Set<IngredientCategory>

    public init(skinType: SkinType, isSensitive: Bool, latestCounts: LesionCounts, routineCategories: Set<IngredientCategory>) {
        self.skinType = skinType
        self.isSensitive = isSensitive
        self.latestCounts = latestCounts
        self.routineCategories = routineCategories
    }

    var isComedonal: Bool {
        let comedones = latestCounts[.blackhead] + latestCounts[.whitehead]
        return comedones >= 4 && comedones >= latestCounts[.papule] + latestCounts[.pustule]
    }

    var isInflamed: Bool { latestCounts[.papule] + latestCounts[.pustule] + latestCounts[.nodule] >= 4 }
}

public struct VerdictResult: Sendable, Hashable {
    public let verdict: ProductVerdict
    public let reasons: [VerdictReason]
    public let matchedCategories: Set<IngredientCategory>
}

/// Deterministic, unit-tested rules (PLAN.md §12): an LLM never decides — it may only rephrase these reasons.
public enum ProductVerdictEngine {
    public static func categories(of ingredients: [String]) -> Set<IngredientCategory> {
        Set(ingredients.compactMap(IngredientKnowledge.match).flatMap(\.categories))
    }

    public static func evaluate(ingredients: [String], profile: VerdictProfile) -> VerdictResult {
        guard !ingredients.isEmpty else {
            return VerdictResult(verdict: .notEnoughInfo, reasons: [], matchedCategories: [])
        }
        let matched = ingredients.compactMap(IngredientKnowledge.match)
        let categories = Set(matched.flatMap(\.categories))
        let topFive = Set(ingredients.prefix(5).compactMap(IngredientKnowledge.match).flatMap(\.categories))
        let comedogenicCount = matched.filter { $0.categories.contains(.comedogenicOil) }.count
        var reasons: [VerdictReason] = []

        func add(_ id: String, _ kind: VerdictReason.Kind, _ text: String) {
            reasons.append(VerdictReason(ruleID: id, kind: kind, text: text))
        }

        if profile.isSensitive, !categories.isDisjoint(with: [.fragrance, .essentialOil]) {
            add("sensitive.fragrance", .caution, String(localized: "Contains fragrance or essential oils, which often sting sensitive skin."))
        }
        if profile.isComedonal || profile.skinType == .oily, comedogenicCount > 0 {
            add("comedonal.oils", comedogenicCount >= 2 ? .negative : .caution,
                String(localized: "Has pore-clogging oils, which tend to worsen blackheads and whiteheads."))
        }
        if profile.skinType == .dry, !topFive.isDisjoint(with: [.dryingAlcohol, .harshSurfactant]) {
            add("dry.stripping", .caution, String(localized: "High in drying alcohol or harsh cleansers, which can leave dry skin tight."))
        }
        let acids: Set<IngredientCategory> = [.exfoliantAHA, .exfoliantBHA]
        if categories.contains(.retinoid), !profile.routineCategories.isDisjoint(with: acids) {
            add("conflict.retinoid-acid", .caution, String(localized: "Your routine already has an exfoliating acid — don't layer it with this retinoid on the same night."))
        } else if !categories.isDisjoint(with: acids), profile.routineCategories.contains(.retinoid) {
            add("conflict.acid-retinoid", .caution, String(localized: "You already use a retinoid — alternate nights instead of layering with this acid."))
        }
        let calming: Set<IngredientCategory> = [.exfoliantBHA, .benzoylPeroxide, .azelaicAcid, .niacinamide]
        if profile.isInflamed, !categories.isDisjoint(with: calming) {
            add("breakouts.helpful-active", .positive, String(localized: "Has an ingredient many people use for active breakouts."))
        }
        let preferred = Set(SkinTypeGuidance.for(profile.skinType).lookFor.compactMap { IngredientKnowledge.match($0.name) }.flatMap(\.categories))
        if !categories.isDisjoint(with: preferred) {
            add("skintype.match", .positive, String(localized: "Includes ingredients suited to \(profile.skinType.title.lowercased()) skin."))
        }
        if !categories.isDisjoint(with: [.barrier, .soothing, .humectant]), reasons.allSatisfy({ $0.kind == .positive }) {
            add("gentle.basics", .positive, String(localized: "Hydrating, barrier-friendly basics."))
        }

        let sorted = reasons.sorted { $0.kind.rawValue < $1.kind.rawValue }
        let verdict: ProductVerdict = if sorted.contains(where: { $0.kind == .negative }) {
            .probablyNotForYou
        } else if sorted.contains(where: { $0.kind == .caution }) {
            .useWithCaution
        } else if matched.isEmpty {
            .notEnoughInfo
        } else {
            .goodMatch
        }
        return VerdictResult(verdict: verdict, reasons: sorted, matchedCategories: categories)
    }
}
