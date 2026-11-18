import Testing
import SkinalyzeKit
@testable import Skinalyze

/// App-hosted tests. Pure logic lives in `SkinalyzeKit` and is tested there (`swift test`);
/// this target covers app-side glue that must run inside the app host.
@Suite("App smoke")
struct AppSmokeTests {
    @Test("App links SkinalyzeKit")
    func linksKit() {
        #expect(!SkinalyzeKit.version.isEmpty)
    }

    @Test("Shared context round-trips through the App Group and drives verdicts for extensions/Siri")
    func sharedContext() throws {
        let context = SharedContext(skinTypeRaw: "Oily", sensitivityRaw: "Very sensitive",
                                    latestCounts: ["blackheads": 6, "whiteheads": 3], routineIngredients: ["retinol"])
        context.save()
        let loaded = try #require(SharedContext.load())
        #expect(loaded == context)
        let result = loaded.verdict(forIngredientText: "Ingredients: Aqua, Parfum, Coconut Oil, Isopropyl Myristate, Glycolic Acid")
        #expect(result.verdict == .probablyNotForYou)
        #expect(result.reasons.contains { $0.ruleID == "sensitive.fragrance" })
        #expect(result.reasons.contains { $0.ruleID == "conflict.acid-retinoid" })
    }

    @Test("Shared page titles match catalog products")
    func titleMatching() {
        #expect(ProductCatalog.shared.bestMatch(forTitle: "Azarine Bodyguard Moisturiser Sunscreen Serum SPF50 | Shop")?.productID == 18)
        #expect(ProductCatalog.shared.bestMatch(forTitle: "zz") == nil)
    }

    @Test("Merged product catalog is bundled and keeps the legacy product IDs")
    func catalogLoads() {
        // product_id 18 is "Bodyguard Moisturiser Sunscreen Serum SPF50" in the legacy catalog that saved scans reference.
        #expect(ProductCatalog.shared.slot(of: 18) == .sunscreen)
        #expect(ProductCatalog.shared.slot(of: -1) == nil)
    }
}
