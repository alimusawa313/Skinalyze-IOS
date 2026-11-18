import Testing
@testable import SkinalyzeKit

@Suite("Skin-type guidance")
struct GuidanceTests {
    @Test("Parses stored skin-type strings case-insensitively; unknown falls back to normal",
          arguments: [("Oily", SkinType.oily), ("dry", .dry), ("COMBINATION", .combination), ("Normal", .normal), ("", .normal)])
    func parsing(raw: String, expected: SkinType) {
        #expect(SkinType(stored: raw) == expected)
    }

    @Test("Every skin type has ingredients to look for, to avoid, and cited sources")
    func complete() {
        for type in SkinType.allCases {
            let guidance = SkinTypeGuidance.for(type)
            #expect(guidance.lookFor.count >= 3)
            #expect(guidance.avoid.count >= 2)
            #expect(!guidance.sources.isEmpty)
            #expect(guidance.sources.allSatisfy { $0.url.hasPrefix("https://") })
        }
    }
}
