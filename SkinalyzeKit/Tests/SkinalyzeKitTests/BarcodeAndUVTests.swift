import Foundation
import Testing
@testable import SkinalyzeKit

/// P8 barcodes (and the public database reply) and P10 UV bands.
@Suite("Barcodes and UV")
struct BarcodeAndUVTests {
    @Test("Valid EAN-13, EAN-8 and UPC-A pass; a wrong check digit or letters fail; UPC-A becomes EAN-13")
    func barcodes() {
        #expect(Barcode.normalized("4005900036728") == "4005900036728") // NIVEA
        #expect(Barcode.normalized("96385074") == "96385074")
        #expect(Barcode.normalized("036000291452") == "0036000291452")
        #expect(Barcode.normalized("4005900036729") == nil)
        #expect(Barcode.normalized("40059000367a8") == nil)
        #expect(Barcode.normalized("12345") == nil)
    }

    @Test("A found product gives name, first brand and English ingredients when present")
    func parseFound() throws {
        let json = #"{"status":1,"product":{"product_name":" Soft Cream ","brands":"NIVEA, Beiersdorf","ingredients_text":"Aqua, Glycerin","ingredients_text_en":"Water, Glycerin"}}"#
        let product = try #require(OpenBeautyFacts.parse(Data(json.utf8), barcode: "4005900036728"))
        #expect(product.name == "Soft Cream")
        #expect(product.brand == "NIVEA")
        #expect(product.ingredients == "Water, Glycerin")
    }

    @Test("Missing products, missing names and junk are nil")
    func parseMissing() {
        #expect(OpenBeautyFacts.parse(Data(#"{"status":0}"#.utf8), barcode: "1") == nil)
        #expect(OpenBeautyFacts.parse(Data(#"{"status":1,"product":{"brands":"X"}}"#.utf8), barcode: "1") == nil)
        #expect(OpenBeautyFacts.parse(Data("not json".utf8), barcode: "1") == nil)
        #expect(OpenBeautyFacts.url(for: "4005900036728")?.host() == "world.openbeautyfacts.org")
        #expect(OpenBeautyFacts.url(for: "123") == nil)
    }

    @Test("UV bands follow the WHO scale and nudge from moderate up")
    func uv() {
        #expect(UVAdvice.level(for: 2) == .low)
        #expect(UVAdvice.level(for: 3) == .moderate)
        #expect(UVAdvice.level(for: 7) == .high)
        #expect(UVAdvice.level(for: 10) == .veryHigh)
        #expect(UVAdvice.level(for: 11) == .extreme)
        #expect(!UVAdvice.shouldNudge(2) && UVAdvice.shouldNudge(3))
    }
}
