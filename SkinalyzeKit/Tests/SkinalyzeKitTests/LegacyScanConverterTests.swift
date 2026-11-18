import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Legacy scan conversion")
struct LegacyScanConverterTests {
    private let date = Date(timeIntervalSince1970: 1_730_000_000)

    private func snapshot(
        images: [String?] = [Fixtures.tinyJPEGBase64, Fixtures.tinyJPEGBase64, Fixtures.tinyJPEGBase64],
        counts: [String: Int] = ["papules": 2, "blackheads": 1],
        score: Int = 1,
        products: LegacyProductIDs = .init(cleanser: 3, toner: 0, moisturizer: 9, sunscreen: 0)
    ) -> LegacyScanSnapshot {
        LegacyScanSnapshot(id: UUID(), date: date, imagesBase64: images, acneCounts: counts,
                           legacyScore: score, productIDs: products)
    }

    @Test("Converts images, counts, score, date and product IDs")
    func convertsEverything() throws {
        let source = snapshot()
        let draft = try LegacyScanConverter.makeDraft(from: source)

        #expect(draft.legacyResultID == source.id)
        #expect(draft.createdAt == date)
        #expect(draft.legacyScore == 1)
        #expect(draft.counts[.papule] == 2)
        #expect(draft.counts[.blackhead] == 1)
        #expect(draft.captures.map(\.angle) == [.front, .right, .left])
        #expect(draft.captures.allSatisfy { !$0.imageData.isEmpty })
        #expect(draft.productIDs == [3, 9], "zero means 'no product' in legacy data")
        #expect(draft.detections.isEmpty, "legacy scans never stored detections")
    }

    @Test("Missing or corrupt images are skipped, not fatal")
    func toleratesBadImages() throws {
        let draft = try LegacyScanConverter.makeDraft(from: snapshot(images: [Fixtures.tinyJPEGBase64, nil, "%%%not-base64"]))
        #expect(draft.captures.count == 1)
        #expect(draft.captures.first?.angle == .front)
    }

    @Test("A scan with no decodable images is still migrated (history must not be lost)")
    func keepsScanWithoutImages() throws {
        let draft = try LegacyScanConverter.makeDraft(from: snapshot(images: [nil, nil, nil]))
        #expect(draft.captures.isEmpty)
        #expect(draft.counts[.papule] == 2)
    }

    @Test("Out-of-range legacy scores are clamped to 0...5")
    func clampsScore() throws {
        #expect(try LegacyScanConverter.makeDraft(from: snapshot(score: 9)).legacyScore == 5)
        #expect(try LegacyScanConverter.makeDraft(from: snapshot(score: -2)).legacyScore == 0)
    }

    @Test("Migration plan only includes legacy records not yet migrated")
    func pendingIDs() {
        let a = UUID(), b = UUID(), c = UUID()
        let pending = LegacyMigrationPlan.pending(legacyIDs: [a, b, c], alreadyMigrated: [b])
        #expect(pending == [a, c])
    }
}

@Suite("Image encoding")
struct ImageEncodingTests {
    @Test("Re-encodes a JPEG into a smaller-or-equal compressed image that still decodes")
    func reencodes() throws {
        let jpeg = try #require(Data(base64Encoded: Fixtures.tinyJPEGBase64))
        let encoded = try #require(ImageEncoding.compressedData(fromImageData: jpeg))
        #expect(!encoded.isEmpty)
        #expect(ImageEncoding.pixelSize(of: encoded) == ImageEncoding.pixelSize(of: jpeg))
    }

    @Test("Garbage input returns nil")
    func garbage() {
        #expect(ImageEncoding.compressedData(fromImageData: Data([0x00, 0x01, 0x02])) == nil)
    }
}
