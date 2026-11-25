import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Ingredient parsing")
struct IngredientParserTests {
    @Test("Splits messy label text, strips the header, parentheticals and 'may contain' tails")
    func parsesLabel() {
        let text = """
        INGREDIENTS: Aqua (Water), Glycerin; Niacinamide • Salicylic Acid
        Parfum (Fragrance), Cetyl Alcohol. May contain: CI 77891
        """
        #expect(IngredientParser.parse(text) == ["aqua", "glycerin", "niacinamide", "salicylic acid", "parfum", "cetyl alcohol"])
    }

    @Test("Empty or whitespace input gives no ingredients")
    func empty() {
        #expect(IngredientParser.parse("  \n ").isEmpty)
    }

    @Test("Matches aliases and common OCR slips to one known ingredient")
    func aliases() {
        #expect(IngredientKnowledge.match("parfum")?.name == "Fragrance")
        #expect(IngredientKnowledge.match("salicylic acid")?.name == "Salicylic acid")
        #expect(IngredientKnowledge.match("sallcylic acid")?.name == "Salicylic acid", "OCR 'i' read as 'l'")
        #expect(IngredientKnowledge.match("totally unknown thing") == nil)
    }
}

@Suite("Ingredient knowledge base")
struct IngredientKnowledgeTests {
    private func categories(_ ingredient: String) -> Set<IngredientCategory> {
        IngredientKnowledge.match(ingredient)?.categories ?? []
    }

    @Test("Every name and alias is a unique, lowercase-able key — no two entries claim the same spelling")
    func uniqueKeys() {
        var owners: [String: String] = [:]
        for entry in IngredientKnowledge.entries {
            for key in [entry.name.lowercased()] + entry.aliases {
                #expect(key == key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), "alias '\(key)' must be lowercase")
                #expect(key != "alcohol", "plain 'alcohol' would catch fatty alcohols")
                if let owner = owners[key], owner != entry.name {
                    Issue.record("'\(key)' belongs to both \(owner) and \(entry.name)")
                }
                owners[key] = entry.name
            }
        }
        #expect(Set(IngredientKnowledge.entries.map(\.name)).count == IngredientKnowledge.entries.count, "entry names are unique")
        #expect(IngredientKnowledge.entries.count >= 140)
        #expect(IngredientKnowledge.entries.allSatisfy { !$0.categories.isEmpty })
    }

    @Test("Real INCI spellings of actives match the right category", arguments: [
        ("tretinoin", IngredientCategory.retinoid), ("retinyl propionate", .retinoid), ("retinyl acetate", .retinoid),
        ("hydroxypinacolone retinoate", .retinoid), ("adapalene 0.1%", .retinoid),
        ("gluconolactone", .exfoliantAHA), ("lactobionic acid", .exfoliantAHA), ("asam glikolat", .exfoliantAHA),
        ("capryloyl salicylic acid", .exfoliantBHA), ("asam salisilat", .exfoliantBHA),
        ("benzoyl peroxide 2.5%", .benzoylPeroxide), ("magnesium ascorbyl phosphate", .vitaminC),
        ("3-o-ethyl ascorbic acid", .vitaminC), ("tetrahexyldecyl ascorbate", .vitaminC),
        ("sodium acetylated hyaluronate", .humectant), ("sodium hyaluronate crosspolymer", .humectant),
        ("butylene glycol", .humectant), ("sodium pca", .humectant), ("urea", .humectant), ("trehalose", .humectant),
        ("ceramide ns", .barrier), ("cholesterol", .barrier), ("phytosphingosine", .barrier),
        ("butyrospermum parkii butter", .emollient), ("caprylic/capric triglyceride", .emollient), ("dimethicone", .emollient),
        ("madecassic acid", .soothing), ("dipotassium glycyrrhizate", .soothing), ("bisabolol", .soothing),
        ("aloe barbadensis leaf juice", .soothing), ("avena sativa kernel flour", .soothing), ("ectoin", .soothing),
        ("linalool", .fragrance), ("limonene", .fragrance), ("hexyl cinnamal", .fragrance), ("citronellol", .fragrance),
        ("lavandula angustifolia oil", .essentialOil), ("citrus limon peel oil", .essentialOil),
        ("mentha piperita oil", .essentialOil), ("citrus aurantium bergamia fruit oil", .essentialOil),
        ("sd alcohol 40-b", .dryingAlcohol), ("isopropyl alcohol", .dryingAlcohol),
        ("sodium coco-sulfate", .harshSurfactant), ("sodium lauryl sulphate", .harshSurfactant),
        ("isopropyl isostearate", .comedogenicOil), ("myristyl myristate", .comedogenicOil),
        ("triticum vulgare germ oil", .comedogenicOil), ("ethylhexyl palmitate", .comedogenicOil),
    ])
    func activesMatch(ingredient: String, category: IngredientCategory) {
        #expect(categories(ingredient).contains(category), "\(ingredient) → \(category)")
    }

    @Test("Fatty alcohols, benzyl alcohol and ethanol look-alikes are never drying alcohol", arguments: [
        "cetyl alcohol", "cetearyl alcohol", "stearyl alcohol", "behenyl alcohol", "myristyl alcohol", "arachidyl alcohol",
        "lauryl alcohol", "isostearyl alcohol", "c14-22 alcohols", "lanolin alcohol", "benzyl alcohol", "phenethyl alcohol",
        "phenoxyethanol", "triethanolamine", "ethanolamine", "polyvinyl alcohol", "t-butyl alcohol", "alcohol",
    ])
    func notDryingAlcohol(ingredient: String) {
        #expect(!categories(ingredient).contains(.dryingAlcohol), "\(ingredient)")
    }

    @Test("Common neutral INCI names and look-alikes of known ones stay neutral", arguments: [
        "water", "aqua", "phenoxyethanol", "ethylhexylglycerin", "caprylyl glycol", "1,2-hexanediol", "disodium edta",
        "xanthan gum", "carbomer", "tocopherol", "tocopheryl acetate", "sodium benzoate", "potassium sorbate", "citric acid",
        "sodium citrate", "sodium hydroxide", "glyceryl stearate", "peg-100 stearate", "stearic acid", "titanium dioxide",
        "zinc oxide", "ethylhexyl salicylate", "homosalate", "butyloctyl salicylate", "ethylhexyl methoxycinnamate",
        "cocamidopropyl betaine", "coco-betaine", "sodium laureth sulfate", "butylene glycol dicaprylate/dicaprate",
        "propylene glycol dicaprylate/dicaprate", "lactic acid/glycolic acid copolymer", "imidazolidinyl urea",
        "curcuma aromatica root oil", "salix alba bark extract", "methylparaben", "polyglycerin-3 methylglucose distearate",
        "bha", "bht", "peg-10 dimethicone", "butyrospermum parkii seedcake extract", "vitamin e", "vitamin b5",
    ])
    func neutral(ingredient: String) {
        #expect(IngredientKnowledge.match(ingredient) == nil, "\(ingredient) matched \(IngredientKnowledge.match(ingredient)?.name ?? "")")
    }

    @Test("Contained matches still catch percentages and plant-part variants")
    func containedVariants() {
        #expect(IngredientKnowledge.match("niacinamide 5%")?.name == "Niacinamide")
        #expect(IngredientKnowledge.match("centella asiatica leaf extract")?.name == "Centella asiatica")
        #expect(IngredientKnowledge.match("hydrolyzed hyaluronic acid")?.name == "Hyaluronic acid")
        #expect(IngredientKnowledge.match("aloe barbadensis leaf juice powder")?.categories.contains(.soothing) == true)
        #expect(IngredientKnowledge.match("hydrogenated cocos nucifera oil")?.name == "Coconut oil")
    }
}

@Suite("Product verdicts")
struct ProductVerdictTests {
    private func profile(_ type: SkinType = .normal, sensitive: Bool = false,
                         counts: LesionCounts = LesionCounts(), routine: Set<IngredientCategory> = []) -> VerdictProfile {
        VerdictProfile(skinType: type, isSensitive: sensitive, latestCounts: counts, routineCategories: routine)
    }

    @Test("No ingredients → not enough info")
    func notEnoughInfo() {
        #expect(ProductVerdictEngine.evaluate(ingredients: [], profile: profile()).verdict == .notEnoughInfo)
    }

    @Test("Gentle, fragrance-free basics are a good match")
    func goodMatch() {
        let result = ProductVerdictEngine.evaluate(ingredients: ["aqua", "glycerin", "niacinamide", "ceramide np"],
                                                   profile: profile(.dry))
        #expect(result.verdict == .goodMatch)
        #expect(result.reasons.contains { $0.kind == .positive })
    }

    @Test("Fragrance for sensitive skin → use with caution, with the reason first")
    func sensitiveFragrance() {
        let result = ProductVerdictEngine.evaluate(ingredients: ["aqua", "glycerin", "parfum"], profile: profile(sensitive: true))
        #expect(result.verdict == .useWithCaution)
        #expect(result.reasons.first?.ruleID == "sensitive.fragrance")
    }

    @Test("Several pore-clogging oils for comedone-prone skin → probably not for you")
    func comedogenic() {
        let comedonal = LesionCounts([.blackhead: 8, .whitehead: 6, .papule: 1])
        let result = ProductVerdictEngine.evaluate(ingredients: ["coconut oil", "isopropyl myristate", "aqua"],
                                                   profile: profile(.oily, counts: comedonal))
        #expect(result.verdict == .probablyNotForYou)
    }

    @Test("Retinoid product while the routine already has an exfoliating acid → layering caution")
    func conflict() {
        let result = ProductVerdictEngine.evaluate(ingredients: ["aqua", "retinol"], profile: profile(routine: [.exfoliantAHA]))
        #expect(result.verdict == .useWithCaution)
        #expect(result.reasons.contains { $0.ruleID == "conflict.retinoid-acid" })
    }

    @Test("Inflammation-calming actives are called out for active breakouts")
    func helpfulActives() {
        let inflamed = LesionCounts([.papule: 6, .pustule: 3])
        let result = ProductVerdictEngine.evaluate(ingredients: ["aqua", "azelaic acid"], profile: profile(counts: inflamed))
        #expect(result.reasons.contains { $0.ruleID == "breakouts.helpful-active" })
    }

    @Test("Verdict copy never uses diagnostic language")
    func copyIsSafe() {
        let banned = ["diagnos", "treat", "cure", "disease", "prescri", "safe", "harmful"]
        for verdict in ProductVerdict.allCases {
            let text = verdict.title.lowercased()
            #expect(!banned.contains { text.contains($0) })
        }
    }
}

@Suite("Insights")
struct InsightEngineTests {
    private func point(_ daysAgo: Int, _ index: Int, zones: [FaceZone: Int] = [:]) -> InsightEngine.Point {
        InsightEngine.Point(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!, index: index, zoneIndices: zones)
    }

    @Test("No trend claims with fewer than three scans")
    func minimumData() {
        #expect(InsightEngine.headline(for: []).contains("first scan"))
        #expect(InsightEngine.headline(for: [point(1, 5), point(3, 6)]).contains("unlock trends"))
    }

    @Test("Calmer than recent scans; the best-ever scan gets its own message")
    func calmer() {
        let best = [point(1, 2), point(5, 8), point(9, 9), point(13, 10)]
        #expect(InsightEngine.headline(for: best).contains("calmest"))
        let calmer = [point(1, 5), point(5, 8), point(9, 9), point(13, 3)]
        #expect(InsightEngine.headline(for: calmer).contains("calmer"))
    }

    @Test("A zone up three scans in a row is called out")
    func zoneStreak() {
        let points = [point(1, 9, zones: [.chin: 6]), point(4, 8, zones: [.chin: 4]), point(7, 7, zones: [.chin: 2]), point(10, 9, zones: [.chin: 1])]
        #expect(InsightEngine.headline(for: points).lowercased().contains("chin"))
    }

    @Test("Long gaps nudge a new scan")
    func gap() {
        #expect(InsightEngine.headline(for: [point(12, 4), point(20, 5), point(30, 6)]).contains("days since"))
    }
}

@Suite("Product effect")
struct ProductEffectTests {
    private func point(_ daysAgo: Int, _ index: Int) -> InsightEngine.Point {
        InsightEngine.Point(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!, index: index, zoneIndices: [:])
    }

    @Test("Needs ≥2 scans before, ≥3 after and ≥14 days of use")
    func requirements() {
        let start = Calendar.current.date(byAdding: .day, value: -20, to: .now)!
        let tooFew = [point(25, 10), point(10, 5), point(5, 4)]
        #expect(ProductEffect.evaluate(points: tooFew, startedAt: start) == nil)
    }

    @Test("Reports the median change after starting")
    func change() {
        let start = Calendar.current.date(byAdding: .day, value: -20, to: .now)!
        let points = [point(30, 10), point(25, 10), point(15, 6), point(10, 5), point(3, 4)]
        let effect = ProductEffect.evaluate(points: points, startedAt: start)
        #expect(effect?.percentChange == -50)
    }
}
