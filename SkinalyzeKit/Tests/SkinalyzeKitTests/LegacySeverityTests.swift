import Testing
@testable import SkinalyzeKit

@Suite("LesionType label parsing")
struct LesionTypeTests {
    @Test("Parses every model label, ignoring case and surrounding whitespace",
          arguments: [
            ("blackheads", LesionType.blackhead),
            ("Whiteheads ", .whitehead),
            ("PAPULES", .papule),
            ("pustules", .pustule),
            ("nodules", .nodule),
            ("dark spot", .darkSpot),
          ])
    func parsesModelLabels(label: String, expected: LesionType) {
        #expect(LesionType(modelLabel: label) == expected)
    }

    @Test("Unknown labels return nil")
    func unknownLabel() {
        #expect(LesionType(modelLabel: "freckle") == nil)
        #expect(LesionType(modelLabel: "") == nil)
    }

    @Test("Model label round-trips through modelLabel")
    func roundTrip() {
        for type in LesionType.allCases {
            #expect(LesionType(modelLabel: type.modelLabel) == type)
        }
    }
}

@Suite("LesionCounts")
struct LesionCountsTests {
    @Test("Counts labels and ignores unknown ones")
    func countsLabels() {
        let counts = LesionCounts(modelLabels: ["papules", "papules", "dark spot", "unknown"])
        #expect(counts[.papule] == 2)
        #expect(counts[.darkSpot] == 1)
        #expect(counts[.nodule] == 0)
        #expect(counts.total == 3)
    }

    @Test("Converts to and from the legacy string-keyed dictionary without loss")
    func legacyDictionaryRoundTrip() {
        let legacy = ["blackheads": 3, "dark spot": 1, "nodules": 0, "papules": 2, "pustules": 0, "whiteheads": 4]
        let counts = LesionCounts(legacyDictionary: legacy)
        #expect(counts[.blackhead] == 3)
        #expect(counts.legacyDictionary == legacy)
    }

    @Test("Adding counts is immutable and sums per type")
    func adding() {
        let a = LesionCounts(modelLabels: ["papules"])
        let b = LesionCounts(modelLabels: ["papules", "nodules"])
        let sum = a.adding(b)
        #expect(sum[.papule] == 2)
        #expect(sum[.nodule] == 1)
        #expect(a[.papule] == 1, "original must not be mutated")
    }
}

@Suite("Legacy severity scale (kept for existing scans)")
struct LegacySeverityTests {
    private func score(_ labels: [String: Int]) -> Int {
        LegacySeverityScale.score(for: LesionCounts(legacyDictionary: labels))
    }

    @Test("No lesions scores 0 (healthy)")
    func healthy() {
        #expect(score([:]) == 0)
    }

    @Test("Blackheads are counted — regression for the \"blackhead\" key bug")
    func blackheadsCount() {
        #expect(score(["blackheads": 11]) == 2, "more than 10 blackheads is moderate")
        #expect(score(["blackheads": 1]) == 1, "any blackhead is at least mild, never healthy")
    }

    @Test("Dark spots alone do not raise the breakout score")
    func darkSpotsIgnored() {
        #expect(score(["dark spot": 30]) == 0)
    }

    @Test("Thresholds match the original scale",
          arguments: [
            (["papules": 1], 1),
            (["papules": 6], 2),
            (["whiteheads": 11], 2),
            (["papules": 11], 3),
            (["pustules": 6], 3),
            (["pustules": 11], 4),
            (["nodules": 6], 4),
            (["nodules": 11], 5),
            (["pustules": 16], 5),
          ])
    func thresholds(labels: [String: Int], expected: Int) {
        #expect(score(labels) == expected)
    }

    @Test("Score always stays within 0...5")
    func bounded() {
        let extreme = ["blackheads": 999, "papules": 999, "pustules": 999, "nodules": 999, "whiteheads": 999]
        #expect((0...5).contains(score(extreme)))
    }
}
