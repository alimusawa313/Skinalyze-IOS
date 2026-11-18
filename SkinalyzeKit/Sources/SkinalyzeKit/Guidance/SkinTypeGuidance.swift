import Foundation

public enum SkinType: String, CaseIterable, Sendable, Codable, Hashable {
    case oily
    case dry
    case combination
    case normal

    /// Parses the value stored in `@AppStorage("skinType")` (legacy values were capitalised).
    public init(stored: String) {
        self = SkinType(rawValue: stored.trimmingCharacters(in: .whitespaces).lowercased()) ?? .normal
    }

    public var title: String {
        switch self {
        case .oily: String(localized: "Oily")
        case .dry: String(localized: "Dry")
        case .combination: String(localized: "Combination")
        case .normal: String(localized: "Normal")
        }
    }

    public var blurb: String {
        switch self {
        case .oily: String(localized: "Shiny by midday, visible pores.")
        case .dry: String(localized: "Feels tight, can flake.")
        case .combination: String(localized: "Oily T-zone, drier cheeks.")
        case .normal: String(localized: "Balanced most days.")
        }
    }
}

public struct IngredientNote: Sendable, Hashable, Identifiable {
    public let name: String
    public let note: String
    public var id: String { name }
}

public struct Citation: Sendable, Hashable, Identifiable {
    public let title: String
    public let url: String
    public var id: String { url }
}

/// Ingredient guidance per skin type, with the cited sources shipped since the App Review 1.4.1 fix.
/// General, non-diagnostic information — phrasing follows PLAN.md §15.1.
public struct SkinTypeGuidance: Sendable, Hashable {
    public let lookFor: [IngredientNote]
    public let avoid: [IngredientNote]
    public let sources: [Citation]

    private static let commonAvoid = [
        IngredientNote(name: String(localized: "Added fragrance"), note: String(localized: "A common cause of irritation, especially for sensitive skin.")),
        IngredientNote(name: String(localized: "Parabens"), note: String(localized: "Preservatives some people prefer to avoid; can irritate sensitive skin.")),
    ]
    private static let avoidSources = [
        Citation(title: "The Upside and Downside of Using Coconut Oil in Skincare", url: "https://buckheaddermatology.com/the-upside-and-downside-of-using-coconut-oil-in-skincare/"),
        Citation(title: "Sodium Lauryl Sulfate-induced barrier disruption and irritation", url: "https://doi.org/10.1111/j.1365-2133.2005.06531.x"),
    ]

    public static func `for`(_ type: SkinType) -> SkinTypeGuidance {
        switch type {
        case .oily:
            SkinTypeGuidance(
                lookFor: [
                    IngredientNote(name: "Salicylic acid", note: String(localized: "A BHA that helps keep pores clear and reduce excess oil.")),
                    IngredientNote(name: "Niacinamide", note: String(localized: "Helps balance oil and refine the look of pores.")),
                    IngredientNote(name: "Tea tree oil", note: String(localized: "Often used in oil-control routines.")),
                    IngredientNote(name: "Hyaluronic acid", note: String(localized: "Lightweight hydration without heaviness.")),
                ],
                avoid: commonAvoid + [
                    IngredientNote(name: String(localized: "Coconut oil"), note: String(localized: "Rich and pore-clogging for many oily skin types.")),
                    IngredientNote(name: String(localized: "Drying alcohol"), note: String(localized: "Strips oil, which can leave skin feeling tight.")),
                ],
                sources: [Citation(title: "American Academy of Dermatology (AAD)", url: "https://www.aad.org/public/diseases/acne/diy/adult-acne-treatment")] + avoidSources
            )
        case .dry:
            SkinTypeGuidance(
                lookFor: [
                    IngredientNote(name: "Hyaluronic acid", note: String(localized: "Draws moisture into the skin.")),
                    IngredientNote(name: "Glycerin", note: String(localized: "A humectant that helps skin hold water.")),
                    IngredientNote(name: "Ceramides", note: String(localized: "Support the skin barrier and lock in moisture.")),
                    IngredientNote(name: "Squalane", note: String(localized: "A light oil that moisturises without heaviness.")),
                ],
                avoid: commonAvoid + [
                    IngredientNote(name: String(localized: "Drying alcohol"), note: String(localized: "Can make dry skin feel tighter.")),
                    IngredientNote(name: "Sodium lauryl sulfate", note: String(localized: "A harsh cleanser that strips natural oils.")),
                ],
                sources: [
                    Citation(title: "What to Know About Ceramides for Skin", url: "https://www.webmd.com/beauty/what-to-know-about-ceramides-for-skin"),
                    Citation(title: "The Benefits of Glycerin for Your Skin", url: "https://www.kiehls.com/skincare-advice/glycerin-benefits-for-skin.html"),
                ] + avoidSources
            )
        case .combination:
            SkinTypeGuidance(
                lookFor: [
                    IngredientNote(name: "Niacinamide", note: String(localized: "Balances oilier and drier areas.")),
                    IngredientNote(name: "Hyaluronic acid", note: String(localized: "Hydration that isn't too heavy.")),
                    IngredientNote(name: String(localized: "AHAs"), note: String(localized: "Gentle exfoliation for uneven texture.")),
                    IngredientNote(name: String(localized: "Green tea extract"), note: String(localized: "An antioxidant that soothes.")),
                ],
                avoid: commonAvoid + [
                    IngredientNote(name: String(localized: "Mineral oil"), note: String(localized: "Can feel heavy on oilier areas.")),
                    IngredientNote(name: "Sodium lauryl sulfate", note: String(localized: "A harsh cleanser that strips natural oils.")),
                ],
                sources: [
                    Citation(title: "Katiyar S. K. (2011) — Green tea and skin", url: "https://doi.org/10.1016/j.abb.2010.11.015"),
                    Citation(title: "Everything You Need to Know About Alpha Hydroxy Acids", url: "https://www.healthline.com/health/beauty-skin-care/alpha-hydroxy-acid"),
                ] + avoidSources
            )
        case .normal:
            SkinTypeGuidance(
                lookFor: [
                    IngredientNote(name: String(localized: "Vitamin C"), note: String(localized: "An antioxidant that brightens.")),
                    IngredientNote(name: String(localized: "Peptides"), note: String(localized: "Support firmness.")),
                    IngredientNote(name: "Hyaluronic acid", note: String(localized: "Hydrates and plumps.")),
                    IngredientNote(name: "Retinol", note: String(localized: "Supports cell turnover; start slowly and use SPF.")),
                ],
                avoid: commonAvoid,
                sources: [
                    Citation(title: "Retinoid or retinol? (AAD)", url: "https://www.aad.org/public/everyday-care/skin-care-secrets/anti-aging/retinoid-retinol"),
                    Citation(title: "WebMD: Benefits of Vitamin C for skin", url: "https://www.webmd.com/beauty/ss/slideshow-benefits-of-vitamin-c-for-skin"),
                ]
            )
        }
    }
}
