import Foundation

// P8 barcode scan and P10 UV nudge.

// MARK: - Barcodes

public enum Barcode {
    /// EAN-13, EAN-8, UPC-A (12) and UPC-E (8) digits with a valid check digit. Normalises UPC-A to EAN-13.
    public static func normalized(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard digits.count == raw.trimmingCharacters(in: .whitespaces).count, [8, 12, 13].contains(digits.count),
              hasValidCheckDigit(digits) else { return nil }
        return digits.count == 12 ? "0" + digits : digits
    }

    static func hasValidCheckDigit(_ digits: String) -> Bool {
        let numbers = digits.compactMap { $0.wholeNumberValue }
        guard let check = numbers.last else { return false }
        let body = numbers.dropLast().reversed()
        let sum = body.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
        return (10 - sum % 10) % 10 == check
    }
}

/// What a public product database returned for a barcode (Open Beauty Facts). Only the barcode is ever sent.
public struct OnlineProduct: Sendable, Equatable {
    public let barcode: String
    public let name: String
    public let brand: String?
    public let ingredients: String?

    public init(barcode: String, name: String, brand: String?, ingredients: String?) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.ingredients = ingredients
    }
}

public enum OpenBeautyFacts {
    public static func url(for barcode: String) -> URL? {
        guard let code = Barcode.normalized(barcode) else { return nil }
        return URL(string: "https://world.openbeautyfacts.org/api/v2/product/\(code).json?fields=product_name,brands,ingredients_text,ingredients_text_en")
    }

    /// Never trusts the response: a missing product or name is nil, texts are trimmed and capped.
    public static func parse(_ data: Data, barcode: String) -> OnlineProduct? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any] else { return nil }
        func text(_ key: String, limit: Int) -> String? {
            guard let value = (product[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return String(value.prefix(limit))
        }
        guard let name = text("product_name", limit: 120) else { return nil }
        let brand = text("brands", limit: 60)?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return OnlineProduct(barcode: barcode, name: name, brand: brand,
                             ingredients: text("ingredients_text_en", limit: 4000) ?? text("ingredients_text", limit: 4000))
    }
}

// MARK: - UV

public enum UVAdvice {
    public enum Level: Int, Sendable, Comparable {
        case low, moderate, high, veryHigh, extreme

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// WHO UV index bands.
    public static func level(for index: Int) -> Level {
        switch index {
        case ..<3: .low
        case 3...5: .moderate
        case 6...7: .high
        case 8...10: .veryHigh
        default: .extreme
        }
    }

    /// Nudge from moderate up: the band where sunscreen is generally recommended.
    public static func shouldNudge(_ index: Int) -> Bool { level(for: index) >= .moderate }
}
