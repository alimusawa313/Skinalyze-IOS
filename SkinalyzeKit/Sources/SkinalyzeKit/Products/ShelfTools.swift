import Foundation

// Phase 10, batch A: small product utilities. All on-device, all deterministic.

// MARK: - P6 Patch test

/// "Day 3 of 14: anything changed?" for a new product. A reported change ends the test with a gentle "stop using it".
public struct PatchTest: Codable, Equatable, Sendable, Identifiable {
    public let productID: Int
    public let started: DayStamp
    /// Day → whether something changed on the test spot that day.
    public var checks: [DayStamp: Bool]
    public var id: String { "\(productID)-\(started.string)" }

    public init(productID: Int, started: DayStamp, checks: [DayStamp: Bool] = [:]) {
        self.productID = productID
        self.started = started
        self.checks = checks
    }
}

public enum PatchTestEngine {
    public static let days = 14

    public enum Status: Equatable, Sendable {
        /// Running; `day` is 1-based. `checkedToday` once today's question is answered.
        case running(day: Int, checkedToday: Bool)
        /// Something changed on `day`.
        case changed(day: Int)
        /// Fourteen days with nothing reported.
        case clear
    }

    public static func day(of test: PatchTest, today: DayStamp, calendar: Calendar) -> Int {
        let start = test.started.date(in: calendar), now = today.date(in: calendar)
        return (calendar.dateComponents([.day], from: start, to: now).day ?? 0) + 1
    }

    public static func status(_ test: PatchTest, today: DayStamp, calendar: Calendar) -> Status {
        if let firstChange = test.checks.filter(\.value).keys.min() {
            return .changed(day: day(of: PatchTest(productID: test.productID, started: test.started), today: firstChange, calendar: calendar))
        }
        let current = day(of: test, today: today, calendar: calendar)
        if current > days { return .clear }
        return .running(day: max(1, current), checkedToday: test.checks[today] != nil)
    }

    /// Only days inside the test, and not in the future, can be answered.
    public static func answering(_ test: PatchTest, changed: Bool, on day: DayStamp, today: DayStamp,
                                 calendar: Calendar) -> PatchTest {
        let index = self.day(of: test, today: day, calendar: calendar)
        guard day <= today, (1...days).contains(index) else { return test }
        var updated = test
        updated.checks[day] = changed
        return updated
    }
}

// MARK: - P7 Expiry

/// When a product was opened and how long it keeps once open (the "12M" jar symbol).
public struct OpenedProduct: Codable, Equatable, Sendable {
    public let productID: Int
    public var openedOn: DayStamp
    public var monthsAfterOpening: Int

    public init(productID: Int, openedOn: DayStamp, monthsAfterOpening: Int) {
        self.productID = productID
        self.openedOn = openedOn
        self.monthsAfterOpening = monthsAfterOpening
    }
}

public enum ExpiryEngine {
    /// The most common period-after-opening, used until the user sets what the jar's symbol says.
    public static let defaultMonths = 12
    public static let soonDays = 30
    public static let monthChoices = [3, 6, 9, 12, 18, 24, 36]

    public enum Status: Equatable, Sendable {
        case fresh(daysLeft: Int)
        case soon(daysLeft: Int)
        case expired(daysAgo: Int)
    }

    public static func expiry(of product: OpenedProduct, calendar: Calendar) -> DayStamp {
        let opened = product.openedOn.date(in: calendar)
        let end = calendar.date(byAdding: .month, value: product.monthsAfterOpening, to: opened) ?? opened
        return DayStamp(end, calendar: calendar)
    }

    public static func status(of product: OpenedProduct, today: DayStamp, calendar: Calendar) -> Status {
        let end = expiry(of: product, calendar: calendar).date(in: calendar)
        let days = calendar.dateComponents([.day], from: today.date(in: calendar), to: end).day ?? 0
        if days < 0 { return .expired(daysAgo: -days) }
        return days <= soonDays ? .soon(daysLeft: days) : .fresh(daysLeft: days)
    }
}

// MARK: - P9 Dupe finder

/// A product, as far as matching needs to know it.
public struct ProductFacts: Sendable, Hashable {
    public let id: Int
    public let brand: String
    public let name: String
    public let category: String
    public let ingredients: [String]

    public init(id: Int, brand: String, name: String, category: String, ingredients: [String]) {
        self.id = id
        self.brand = brand
        self.name = name
        self.category = category
        self.ingredients = ingredients
    }
}

public struct Dupe: Sendable, Equatable {
    public let id: Int
    /// 0…1.
    public let similarity: Double
    /// Known actives both share (display names).
    public let sharedActives: [String]
}

/// Products in the same category with the same key ingredients. The catalog has no prices, so this never claims
/// "cheaper" — it says "similar formula".
public enum DupeFinder {
    /// The first ingredients make up most of a formula.
    public static let leadingIngredients = 10
    public static let minimumSimilarity = 0.35
    public static let maximumResults = 5

    static func key(_ product: ProductFacts) -> (lead: Set<String>, actives: Set<String>) {
        let normalized = product.ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let actives = Set(normalized.compactMap { IngredientKnowledge.match($0) }
            .filter { !$0.categories.isDisjoint(with: activeCategories) }.map(\.name))
        return (Set(normalized.prefix(leadingIngredients)), actives)
    }

    static let activeCategories: Set<IngredientCategory> = [
        .exfoliantAHA, .exfoliantBHA, .retinoid, .benzoylPeroxide, .azelaicAcid, .niacinamide, .vitaminC, .barrier, .soothing,
    ]

    /// Half the score from the leading ingredients, half from the actives (Jaccard each).
    public static func similarity(_ a: ProductFacts, _ b: ProductFacts) -> Double {
        let ka = key(a), kb = key(b)
        func jaccard(_ x: Set<String>, _ y: Set<String>) -> Double {
            let union = x.union(y)
            return union.isEmpty ? 0 : Double(x.intersection(y).count) / Double(union.count)
        }
        let activesScore = ka.actives.isEmpty && kb.actives.isEmpty ? 1 : jaccard(ka.actives, kb.actives)
        return 0.5 * jaccard(ka.lead, kb.lead) + 0.5 * activesScore
    }

    public static func dupes(for product: ProductFacts, in catalog: [ProductFacts]) -> [Dupe] {
        let actives = key(product).actives
        return catalog
            .filter { $0.id != product.id && $0.category == product.category && !$0.ingredients.isEmpty }
            .map { other in
                Dupe(id: other.id, similarity: similarity(product, other),
                     sharedActives: actives.intersection(key(other).actives).sorted())
            }
            .filter { $0.similarity >= minimumSimilarity }
            .sorted { $0.similarity != $1.similarity ? $0.similarity > $1.similarity : $0.id < $1.id }
            .prefix(maximumResults)
            .map { $0 }
    }
}

// MARK: - G10 Shop links

/// Turns a product link or shared text from TikTok Shop, Shopee or Tokopedia into words to match against the catalog.
/// Nothing is fetched: only the link and text the user shared are read.
public enum ShopLinkParser {
    public enum Shop: String, Sendable { case tokopedia, shopee, tiktok, other }

    public static func shop(of url: URL) -> Shop {
        let host = url.host()?.lowercased() ?? ""
        if host.contains("tokopedia") { return .tokopedia }
        if host.contains("shopee") { return .shopee }
        if host.contains("tiktok") { return .tiktok }
        return .other
    }

    /// The product title in a link, if the link carries one.
    public static func title(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch shop(of: url) {
        case .tokopedia:
            // tokopedia.com/<shop>/<product-slug>
            guard parts.count >= 2 else { return nil }
            return words(fromSlug: parts[1])
        case .shopee:
            // shopee.co.id/<Product-Name>-i.<shop>.<item>
            guard let slug = parts.first(where: { $0.contains("-i.") }) else { return nil }
            return words(fromSlug: String(slug[..<slug.range(of: "-i.")!.lowerBound]))
        case .tiktok, .other:
            return nil
        }
    }

    /// Shared text minus links, prices and shop boilerplate (TikTok Shop shares the title as text).
    public static func title(fromText text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: #"https?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(rp|idr)\s?[\d.,]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)(check out|cek|lihat|this product|produk ini|on tiktok shop|di tiktok shop|on shopee|di shopee|on tokopedia|di tokopedia)"#,
                                  with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^\p{L}\p{N}+%.\- ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.count >= 4 ? cleaned : nil
    }

    static func words(fromSlug slug: String) -> String? {
        let decoded = slug.removingPercentEncoding ?? slug
        let text = decoded.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"\s\d{6,}$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// The catalog product whose brand and name best cover the title's words. Needs the brand and at least half the
    /// name's words, so a vague title matches nothing rather than the wrong product.
    public static func bestMatch(title: String, in catalog: [ProductFacts]) -> ProductFacts? {
        let tokens = Set(tokenize(title))
        guard !tokens.isEmpty else { return nil }
        let scored = catalog.compactMap { product -> (ProductFacts, Double)? in
            let brand = tokenize(product.brand), name = tokenize(product.name)
            guard !brand.isEmpty, brand.allSatisfy(tokens.contains), !name.isEmpty else { return nil }
            let covered = Double(name.filter(tokens.contains).count) / Double(name.count)
            return covered >= 0.5 ? (product, covered) : nil
        }
        return scored.max { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.id > $1.0.id }?.0
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }
}

// MARK: - P12 Scan-quality coach

/// How a scan's front photo was lit: brightness 0…1 and warmth (red minus blue, −1…1).
public struct ScanLighting: Codable, Equatable, Sendable {
    public let brightness: Double
    public let warmth: Double

    public init(brightness: Double, warmth: Double) {
        self.brightness = brightness
        self.warmth = warmth
    }
}

public enum LightingCoach {
    public enum Tip: Equatable, Sendable {
        case tooDark, tooBright, warmerThanUsual, coolerThanUsual
    }

    /// Absolute limits, then differences from the user's usual (median of earlier scans).
    public static let darkBelow = 0.28
    public static let brightAbove = 0.82
    public static let brightnessDrift = 0.12
    public static let warmthDrift = 0.08
    /// Earlier scans needed before "than usual" tips appear.
    public static let minimumHistory = 3

    public static func tips(for scan: ScanLighting, history: [ScanLighting]) -> [Tip] {
        var tips: [Tip] = []
        if scan.brightness < darkBelow { tips.append(.tooDark) } else if scan.brightness > brightAbove { tips.append(.tooBright) }
        guard history.count >= minimumHistory else { return tips }
        let usualBrightness = median(history.map(\.brightness)), usualWarmth = median(history.map(\.warmth))
        if tips.isEmpty {
            if scan.brightness < usualBrightness - brightnessDrift { tips.append(.tooDark) }
            if scan.brightness > usualBrightness + brightnessDrift { tips.append(.tooBright) }
        }
        if scan.warmth > usualWarmth + warmthDrift { tips.append(.warmerThanUsual) }
        if scan.warmth < usualWarmth - warmthDrift { tips.append(.coolerThanUsual) }
        return tips
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
