import Foundation

/// "What helps" for what a scan noticed — clogged pores, red spots, marks — on top of the skin-type guidance.
/// General information from the cited American Academy of Dermatology pages (checked live on 2026-11-25), never a
/// diagnosis; wording follows PLAN.md §15.1. Deterministic: the same counts always give the same advice.
public struct SpotGuidance: Sendable, Hashable {
    public enum Pattern: String, CaseIterable, Sendable, Hashable {
        /// Blackheads and whiteheads.
        case clogged
        /// Red bumps, spots with a white top, deep bumps.
        case inflamed
        /// Dark marks left behind.
        case marks
    }

    public let pattern: Pattern
    public let title: String
    public let lookFor: [IngredientNote]
    public let habits: [String]
    public let sources: [Citation]

    // Sources (AAD), each checked to cover what it is cited for.
    static let tips = Citation(title: "Acne: Tips for managing (AAD)", url: "https://www.aad.org/public/diseases/acne/skin-care/tips")
    static let options = Citation(title: "American Academy of Dermatology: acne care options", url: "https://www.aad.org/public/diseases/acne/derm-treat/treat")
    static let popping = Citation(title: "Pimple popping: Why only a dermatologist should do it (AAD)",
                                  url: "https://www.aad.org/public/diseases/acne/skin-care/popping")
    static let darkSpots = Citation(title: "How to fade dark spots in darker skin tones (AAD)",
                                    url: "https://www.aad.org/public/everyday-care/skin-care-secrets/routine/fade-dark-spots")
    static let sunscreen = Citation(title: "How to apply sunscreen (AAD)",
                                    url: "https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/how-to-apply-sunscreen")
    static let washing = Citation(title: "Face washing 101 (AAD)",
                                  url: "https://www.aad.org/public/everyday-care/skin-care-basics/care/face-washing-101")

    /// What the scan noticed, most-seen first (ties keep the order clogged, inflamed, marks).
    public static func patterns(for counts: LesionCounts) -> [Pattern] {
        let totals: [(Pattern, Int)] = [
            (.clogged, counts[.blackhead] + counts[.whitehead]),
            (.inflamed, counts[.papule] + counts[.pustule] + counts[.nodule]),
            (.marks, counts[.darkSpot]),
        ]
        return totals.enumerated()
            .filter { $0.element.1 > 0 }
            .sorted { ($0.element.1, -$0.offset) > ($1.element.1, -$1.offset) }
            .map(\.element.0)
    }

    public static func `for`(_ pattern: Pattern) -> SpotGuidance {
        switch pattern {
        case .clogged:
            SpotGuidance(
                pattern: pattern,
                title: String(localized: "For blackheads and whiteheads"),
                lookFor: [
                    IngredientNote(name: "Salicylic acid", note: String(localized: "A BHA many people use to help keep pores clear.")),
                    IngredientNote(name: "Adapalene", note: String(localized: "A retinoid sold over the counter that works on clogged pores. Give it 6–8 weeks.")),
                ],
                habits: [
                    String(localized: "Wash gently with your fingertips, up to twice a day and after sweating."),
                    String(localized: "Skip scrubs and washcloths; rubbing irritates skin."),
                    String(localized: "Pick gentle, alcohol-free products."),
                ],
                sources: [options, tips, washing]
            )
        case .inflamed:
            SpotGuidance(
                pattern: pattern,
                title: String(localized: "For red spots"),
                lookFor: [
                    IngredientNote(name: "Benzoyl peroxide", note: String(localized: "Cuts down acne bacteria on the skin; works best alongside another product.")),
                    IngredientNote(name: "Adapalene", note: String(localized: "A retinoid that also helps with some pimples. Give it 6–8 weeks.")),
                ],
                habits: [
                    String(localized: "Hands off: squeezing or popping makes spots last longer."),
                    String(localized: "Keep your hands away from your face during the day."),
                    String(localized: "Painful, deep spots are worth showing a dermatologist."),
                ],
                sources: [popping, options, tips]
            )
        case .marks:
            SpotGuidance(
                pattern: pattern,
                title: String(localized: "For marks left behind"),
                lookFor: [
                    IngredientNote(name: "Azelaic acid", note: String(localized: "Often used to help marks fade.")),
                    IngredientNote(name: "Vitamin C", note: String(localized: "An antioxidant used to even out tone.")),
                    IngredientNote(name: "Glycolic acid", note: String(localized: "An AHA that helps marks fade with regular use.")),
                    IngredientNote(name: "Retinol", note: String(localized: "A retinoid that can help marks fade; start slowly.")),
                ],
                habits: [
                    String(localized: "Sunscreen every day: sun keeps marks dark longer."),
                    String(localized: "Reapply every two hours outdoors, and after sweating."),
                    String(localized: "Be patient: marks often fade on their own over 6 to 12 months."),
                ],
                sources: [darkSpots, sunscreen]
            )
        }
    }

    public struct ShelfMatch: Sendable, Hashable {
        public let product: String
        /// What the product actually contains, by its ingredient name (retinol, not "adapalene", when that's on the label).
        public let ingredient: String
    }

    /// Shelf products holding an ingredient of the kind suggested (in suggestion order), each named once.
    public static func shelfMatches(for pattern: Pattern, shelf: [(name: String, ingredients: [String])]) -> [ShelfMatch] {
        let suggested = SpotGuidance.for(pattern).lookFor.compactMap { IngredientKnowledge.match($0.name)?.categories }
        return shelf.compactMap { product in
            let entries = product.ingredients.compactMap(IngredientKnowledge.match)
            for categories in suggested {
                if let entry = entries.first(where: { !$0.categories.isDisjoint(with: categories) }) {
                    return ShelfMatch(product: product.name, ingredient: entry.name)
                }
            }
            return nil
        }
    }
}
