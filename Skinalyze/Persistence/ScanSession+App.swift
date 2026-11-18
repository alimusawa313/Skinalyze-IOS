import UIKit
import SkinalyzeKit

/// App-side conveniences that let the current (legacy-styled) screens read `ScanSession`.
/// These shims go away when the screens are rebuilt in Phase 3.
extension ScanSession {
    var currentDate: Date { createdAt }
    var geaScale: Int { legacyScore }
    var acneCounts: [String: Int] { counts.legacyDictionary }

    /// Decoded photo for the capture at `index` (front, right, left order), or `nil`.
    func uiImage(at index: Int) -> UIImage? {
        let captures = sortedCaptures
        guard captures.indices.contains(index), let data = captures[index].imageData else { return nil }
        return UIImage(data: data)
    }

    var uiImages: [UIImage] {
        sortedCaptures.compactMap { $0.imageData.flatMap(UIImage.init(data:)) }
    }

    /// Angle of the capture at `index`, used to look up its detections.
    func captureAngle(at index: Int) -> CaptureAngle? {
        let captures = sortedCaptures
        return captures.indices.contains(index) ? captures[index].angle : nil
    }

    /// Product used in a routine slot at scan time, resolved through the catalog's category.
    func productID(in slot: ProductCatalog.Slot) -> Int {
        productIDs.first { ProductCatalog.shared.slot(of: $0) == slot } ?? 0
    }
}

/// Read-only product catalog lookup (bundled JSON), loaded once.
final class ProductCatalog: Sendable {
    enum Slot: String, Sendable {
        case cleanser = "Cleanser"
        case toner = "Toner"
        case moisturizer = "Moisturizer"
        case sunscreen = "Sunscreen"
    }

    static let shared = ProductCatalog()

    private let slotsByID: [Int: Slot]

    private init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "FinalSkincareProductElFinale", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let products = try? JSONDecoder().decode([SkincareProduct].self, from: data)
        else {
            AppPersistence.logger.error("Product catalog failed to load")
            slotsByID = [:]
            return
        }
        slotsByID = Dictionary(
            products.compactMap { product in product.category.flatMap(Slot.init(rawValue:)).map { (product.product_id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func slot(of productID: Int) -> Slot? { slotsByID[productID] }
}
