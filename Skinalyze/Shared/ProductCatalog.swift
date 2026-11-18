import Foundation
import OSLog

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
    }

    func product(id: Int) -> CatalogProduct? { byID[id] }

    func slot(of productID: Int) -> Slot? { byID[productID]?.slot }

    func products(in slot: Slot) -> [CatalogProduct] {
        products.filter { $0.slot == slot }
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
