import Foundation
import OSLog
import SkinalyzeKit

/// One product from the bundled, merged catalog (`ProductCatalog.json`, built by `scripts/merge_catalog.py`).
struct CatalogProduct: Codable, Identifiable, Hashable, Sendable {
    let productID: Int
    let name: String
    let brand: String
    let category: String?
    let photo: String
    let link: String?
    let ingredients: String?
    /// EAN/UPC barcode (products imported from Open Beauty Facts have one).
    let barcode: String?
    /// Where the product's data comes from, when it must be credited ("Open Beauty Facts").
    let source: String?

    var id: Int { productID }
    var slot: ProductCatalog.Slot? { category.flatMap(ProductCatalog.Slot.init(rawValue:)) }
    var kind: ProductCatalog.Kind? { category.flatMap(ProductCatalog.Kind.init(rawValue:)) }
    var isFromOpenBeautyFacts: Bool { source == ProductCatalog.openBeautyFacts }
    var photoURL: URL? { URL(string: photo) }

    /// Ingredient list split into names (INCI order).
    var ingredientList: [String] {
        (ingredients ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case name
        case brand = "brand_name"
        case category, photo, link, ingredients, barcode, source
    }
}

/// Read-only product catalog, decoded once.
final class ProductCatalog: Sendable {
    enum Slot: String, CaseIterable, Identifiable, Sendable {
        case cleanser = "Cleanser"
        case toner = "Toner"
        case moisturizer = "Moisturizer"
        case sunscreen = "Sunscreen"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cleanser: String(localized: "Cleanser")
            case .toner: String(localized: "Toner")
            case .moisturizer: String(localized: "Moisturizer")
            case .sunscreen: String(localized: "Sunscreen")
            }
        }

        var systemImage: String {
            switch self {
            case .cleanser: "bubbles.and.sparkles"
            case .toner: "drop.halffull"
            case .moisturizer: "drop.fill"
            case .sunscreen: "sun.max"
            }
        }

        /// `@AppStorage` key holding the product ID for this slot.
        var storageKey: String {
            switch self {
            case .cleanser: UserProfile.Key.cleanserID
            case .toner: UserProfile.Key.tonerID
            case .moisturizer: UserProfile.Key.moisturizerID
            case .sunscreen: UserProfile.Key.sunscreenID
            }
        }
    }

    /// Every kind of product in the catalog: the four shelf slots plus the extra routine steps.
    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case cleanser = "Cleanser"
        case toner = "Toner"
        case serum = "Serum"
        case exfoliant = "Exfoliant"
        case spotCare = "Spot care"
        case moisturizer = "Moisturizer"
        case eyeCare = "Eye care"
        case mask = "Mask"
        case sunscreen = "Sunscreen"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cleanser: String(localized: "Cleanser")
            case .toner: String(localized: "Toner")
            case .serum: String(localized: "Serum")
            case .exfoliant: String(localized: "Exfoliant")
            case .spotCare: String(localized: "Spot care")
            case .moisturizer: String(localized: "Moisturizer")
            case .eyeCare: String(localized: "Eye care")
            case .mask: String(localized: "Mask")
            case .sunscreen: String(localized: "Sunscreen")
            }
        }

        var systemImage: String {
            switch self {
            case .cleanser: "bubbles.and.sparkles"
            case .toner: "drop.halffull"
            case .serum: "eyedropper"
            case .exfoliant: "circle.dotted"
            case .spotCare: "bandage"
            case .moisturizer: "drop.fill"
            case .eyeCare: "eye"
            case .mask: "theatermask.and.paintbrush"
            case .sunscreen: "sun.max"
            }
        }

        /// The shelf slot this kind fills, if any.
        var slot: Slot? { Slot(rawValue: rawValue) }

        /// The routine-builder step this kind becomes when it isn't a shelf slot.
        var extraStep: ExtraStepKind? {
            switch self {
            case .serum: .serum
            case .exfoliant: .exfoliant
            case .spotCare: .spotTreatment
            case .eyeCare: .eyeCream
            case .mask: .mask
            case .cleanser, .toner, .moisturizer, .sunscreen: nil
            }
        }
    }

    /// Credited wherever its products appear (Open Database License).
    static let openBeautyFacts = "Open Beauty Facts"

    static let shared = ProductCatalog()
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Catalog")

    let products: [CatalogProduct]
    private let byID: [Int: CatalogProduct]
    private let byBarcode: [String: CatalogProduct]
    /// What matching rules (dupes, shop links) need, in catalog order.
    let facts: [ProductFacts]

    init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "ProductCatalog", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            products = try JSONDecoder().decode([CatalogProduct].self, from: Data(contentsOf: url))
        } catch {
            Self.logger.error("Product catalog failed to load: \(error.localizedDescription)")
            products = []
        }
        byID = Dictionary(products.map { ($0.productID, $0) }, uniquingKeysWith: { first, _ in first })
        byBarcode = Dictionary(products.compactMap { product in
            product.barcode.flatMap(Barcode.normalized).map { ($0, product) }
        }, uniquingKeysWith: { first, _ in first })
        facts = products.map(Self.facts(for:))
    }

    func product(id: Int) -> CatalogProduct? { byID[id] }

    func slot(of productID: Int) -> Slot? { byID[productID]?.slot }

    /// The catalog product with this barcode (any EAN/UPC spelling).
    func product(barcode: String) -> CatalogProduct? { Barcode.normalized(barcode).flatMap { byBarcode[$0] } }

    func products(of kind: Kind) -> [CatalogProduct] {
        products.filter { $0.kind == kind }
    }

    /// What the user has now: the four shelf slots, then catalog products added as extra routine steps (each once).
    func shelf(defaults: UserDefaults = .standard, plan: RoutinePlan?) -> [CatalogProduct] {
        let slotIDs = Slot.allCases.map { defaults.integer(forKey: $0.storageKey) }.filter { $0 > 0 }
        let stepIDs = (plan.map { $0.morning + $0.evening } ?? []).compactMap(\.productID)
        var seen = Set<Int>()
        return (slotIDs + stepIDs).filter { seen.insert($0).inserted }.compactMap(product(id:))
    }

    func products(in slot: Slot) -> [CatalogProduct] {
        products.filter { $0.slot == slot }
    }

    /// Best catalog product for a shared page/product title (all title words found in name + brand).
    func bestMatch(forTitle title: String) -> CatalogProduct? {
        let words = title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 2 }
        guard !words.isEmpty else { return nil }
        return products
            .map { product -> (CatalogProduct, Int) in
                let haystack = "\(product.name) \(product.brand)".lowercased()
                return (product, words.filter(haystack.contains).count)
            }
            .filter { $0.1 >= max(2, words.count * 2 / 3) }
            .max { $0.1 < $1.1 }?.0
    }

    static func facts(for product: CatalogProduct) -> ProductFacts {
        ProductFacts(id: product.productID, brand: product.brand, name: product.name, category: product.category ?? "",
                     ingredients: product.ingredientList.map { $0.lowercased() })
    }

    /// A product from a shopping-app link or shared text (TikTok Shop, Shopee, Tokopedia), read without fetching.
    func shopMatch(url: URL?, text: String?) -> (title: String, product: CatalogProduct?)? {
        let title = url.flatMap(ShopLinkParser.title(from:)) ?? text.flatMap(ShopLinkParser.title(fromText:))
        guard let title else { return nil }
        let match = ShopLinkParser.bestMatch(title: title, in: facts).flatMap { product(id: $0.id) } ?? bestMatch(forTitle: title)
        return (title, match)
    }

    /// Matches name, brand **and** ingredients (the old search matched brand only).
    func search(_ query: String, in slot: Slot? = nil) -> [CatalogProduct] {
        let pool = slot.map(products(in:)) ?? products
        let terms = query.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return pool }
        return pool.filter { product in
            let haystack = "\(product.name) \(product.brand) \(product.ingredients ?? "")".lowercased()
            return terms.allSatisfy(haystack.contains)
        }
    }
}
