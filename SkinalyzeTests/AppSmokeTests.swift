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
}
