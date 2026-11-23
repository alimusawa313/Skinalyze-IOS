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

    var id: Int { productID }
    var slot: ProductCatalog.Slot? { category.flatMap(ProductCatalog.Slot.init(rawValue:)) }
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
        case category, photo, link, ingredients
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

    static let shared = ProductCatalog()
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Catalog")

    let products: [CatalogProduct]
    private let byID: [Int: CatalogProduct]
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
        facts = products.map(Self.facts(for:))
    }

    func product(id: Int) -> CatalogProduct? { byID[id] }

    func slot(of productID: Int) -> Slot? { byID[productID]?.slot }

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
