import Testing
@testable import SkinalyzeKit

@Suite("What helps for what a scan noticed")
struct SpotGuidanceTests {
    @Test("Patterns come from the scan's counts, the most-seen first")
    func patternsByCount() {
        let counts = LesionCounts([.blackhead: 2, .whitehead: 3, .papule: 1, .darkSpot: 6])
        #expect(SpotGuidance.patterns(for: counts) == [.marks, .clogged, .inflamed])
    }

    @Test("Pustules and nodules count as red spots; nothing noticed means no pattern")
    func inflamedAndEmpty() {
        #expect(SpotGuidance.patterns(for: LesionCounts([.pustule: 1, .nodule: 1])) == [.inflamed])
        #expect(SpotGuidance.patterns(for: LesionCounts()).isEmpty)
    }

    @Test("Every pattern has ingredients, habits and at least one source")
    func everyPatternIsComplete() {
        for pattern in SpotGuidance.Pattern.allCases {
            let guidance = SpotGuidance.for(pattern)
            #expect(!guidance.lookFor.isEmpty)
            #expect(guidance.habits.count >= 2)
            #expect(!guidance.sources.isEmpty)
            #expect(guidance.sources.allSatisfy { $0.url.hasPrefix("https://www.aad.org/") })
        }
    }

    @Test("Ingredients named in the guidance are ones the ingredient engine recognises")
    func ingredientsAreKnown() {
        for pattern in SpotGuidance.Pattern.allCases {
            for note in SpotGuidance.for(pattern).lookFor {
                #expect(IngredientKnowledge.match(note.name) != nil, "\(note.name) is not in IngredientKnowledge")
            }
        }
    }

    @Test("Shelf matches: products holding a suggested ingredient, named once each")
    func shelfMatches() {
        let shelf: [(name: String, ingredients: [String])] = [
            ("Clear Gel", ["aqua", "salicylic acid", "glycerin"]),
            ("Plain Cream", ["aqua", "glycerin", "dimethicone"]),
            ("Spot Gel", ["aqua", "benzoyl peroxide", "salicylic acid"]),
        ]
        let matches = SpotGuidance.shelfMatches(for: .clogged, shelf: shelf)
        #expect(matches.map(\.product) == ["Clear Gel", "Spot Gel"])
        #expect(matches.first?.ingredient == "Salicylic acid")
    }

    @Test("Copy stays tracking language: no diagnosis or treatment words")
    func copyRules() {
        let banned = ["diagnos", "treat", "cure", "disease", "prescri", "clinically proven", "medical", "severe"]
        for pattern in SpotGuidance.Pattern.allCases {
            let guidance = SpotGuidance.for(pattern)
            let text = ([guidance.title] + guidance.lookFor.flatMap { [$0.name, $0.note] } + guidance.habits)
                .joined(separator: " ").lowercased()
            for word in banned { #expect(!text.contains(word), "\(pattern): \(word)") }
        }
    }
}
