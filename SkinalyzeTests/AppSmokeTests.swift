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

    @Test("Merged product catalog is bundled and keeps the legacy product IDs")
    func catalogLoads() {
        // product_id 18 is "Bodyguard Moisturiser Sunscreen Serum SPF50" in the legacy catalog that saved scans reference.
        #expect(ProductCatalog.shared.slot(of: 18) == .sunscreen)
        #expect(ProductCatalog.shared.slot(of: -1) == nil)
    }
}
