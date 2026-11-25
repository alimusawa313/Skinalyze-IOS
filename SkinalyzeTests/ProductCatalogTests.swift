import Foundation
import Testing
@testable import Skinalyze
import SkinalyzeKit

/// The bundled catalog: every product has a known kind, IDs stay unique, imported products are credited and findable
/// by barcode.
@Suite("Product catalog")
struct ProductCatalogTests {
    private let catalog = ProductCatalog.shared

    @Test("Every product has a known kind and a unique ID")
    func kindsAndIDs() {
        #expect(!catalog.products.isEmpty)
        #expect(catalog.products.allSatisfy { $0.kind != nil })
        #expect(Set(catalog.products.map(\.productID)).count == catalog.products.count)
    }

    @Test("The four shelf kinds are slots; the others become routine steps")
    func kindsMapToSlotsOrSteps() {
        for kind in ProductCatalog.Kind.allCases {
            #expect((kind.slot == nil) != (kind.extraStep == nil), "\(kind) must be exactly one of slot or step")
        }
        #expect(ProductCatalog.Kind.serum.extraStep == .serum)
        #expect(ProductCatalog.Kind.sunscreen.slot == .sunscreen)
    }

    @Test("Imported products link their source, and any barcode they carry is valid and finds them, in any EAN/UPC spelling")
    func barcodeLookup() throws {
        let imported = catalog.products.filter(\.isFromOpenBeautyFacts)
        #expect(imported.allSatisfy { $0.link != nil })
        // A barcode is kept only when it's a valid EAN/UPC.
        #expect(imported.compactMap(\.barcode).allSatisfy { Barcode.normalized($0) != nil })
        guard let product = imported.first(where: { $0.barcode != nil }), let barcode = product.barcode else { return }
        #expect(catalog.product(barcode: barcode)?.productID == product.productID)
        if barcode.count == 13, barcode.hasPrefix("0") {
            #expect(catalog.product(barcode: String(barcode.dropFirst()))?.productID == product.productID)
        }
    }

    @Test("Original products keep their IDs (saved scans and shelf slots point at them)")
    func legacyIDsStable() {
        #expect(catalog.product(id: 1)?.brand == "Biore")
        #expect(catalog.product(id: 18)?.slot == .sunscreen)
        #expect(catalog.products.filter { !$0.isFromOpenBeautyFacts }.allSatisfy { $0.productID < 10_001 })
        #expect(catalog.product(barcode: "0000000000000") == nil)
    }
}
