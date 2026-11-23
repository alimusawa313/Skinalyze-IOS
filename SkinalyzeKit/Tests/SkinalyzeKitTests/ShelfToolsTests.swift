import Foundation
import Testing
@testable import SkinalyzeKit

/// Phase 10 batch A: patch tests, expiry, dupes, shop links, scan lighting.
@Suite("Shelf tools")
struct ShelfToolsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()
    func day(_ y: Int, _ m: Int, _ d: Int) -> DayStamp { DayStamp(year: y, month: m, day: d) }

    // MARK: Patch test

    @Test("A patch test counts days from the start and is clear after fourteen quiet days")
    func patchTestDays() {
        let test = PatchTest(productID: 1, started: day(2026, 11, 1))
        #expect(PatchTestEngine.status(test, today: day(2026, 11, 1), calendar: calendar) == .running(day: 1, checkedToday: false))
        #expect(PatchTestEngine.status(test, today: day(2026, 11, 14), calendar: calendar) == .running(day: 14, checkedToday: false))
        #expect(PatchTestEngine.status(test, today: day(2026, 11, 15), calendar: calendar) == .clear)
    }

    @Test("Answering: today counts, the future and days outside the test don't, and a change ends the test")
    func patchTestAnswers() {
        let today = day(2026, 11, 3)
        var test = PatchTest(productID: 1, started: day(2026, 11, 1))
        test = PatchTestEngine.answering(test, changed: false, on: today, today: today, calendar: calendar)
        #expect(PatchTestEngine.status(test, today: today, calendar: calendar) == .running(day: 3, checkedToday: true))
        #expect(PatchTestEngine.answering(test, changed: true, on: day(2026, 11, 4), today: today, calendar: calendar) == test)
        #expect(PatchTestEngine.answering(test, changed: true, on: day(2026, 10, 31), today: today, calendar: calendar) == test)
        test = PatchTestEngine.answering(test, changed: true, on: today, today: today, calendar: calendar)
        #expect(PatchTestEngine.status(test, today: day(2026, 11, 20), calendar: calendar) == .changed(day: 3))
    }

    // MARK: Expiry

    @Test("Expiry is opened date plus the months on the jar; soon within 30 days; then expired")
    func expiry() {
        let jar = OpenedProduct(productID: 1, openedOn: day(2026, 1, 31), monthsAfterOpening: 6)
        #expect(ExpiryEngine.expiry(of: jar, calendar: calendar) == day(2026, 7, 31))
        #expect(ExpiryEngine.status(of: jar, today: day(2026, 3, 1), calendar: calendar) == .fresh(daysLeft: 152))
        #expect(ExpiryEngine.status(of: jar, today: day(2026, 7, 21), calendar: calendar) == .soon(daysLeft: 10))
        #expect(ExpiryEngine.status(of: jar, today: day(2026, 8, 2), calendar: calendar) == .expired(daysAgo: 2))
    }

    // MARK: Dupes

    func product(_ id: Int, _ ingredients: [String], category: String = "Moisturizer") -> ProductFacts {
        ProductFacts(id: id, brand: "B\(id)", name: "P\(id)", category: category, ingredients: ingredients)
    }

    @Test("Dupes share the category and key ingredients, best first; unrelated formulas don't count")
    func dupes() {
        let base = product(1, ["water", "glycerin", "niacinamide", "ceramide np", "squalane"])
        let close = product(2, ["water", "glycerin", "niacinamide", "ceramide np", "dimethicone"])
        let far = product(3, ["water", "alcohol denat", "parfum", "salicylic acid"])
        let otherCategory = product(4, base.ingredients, category: "Cleanser")
        let found = DupeFinder.dupes(for: base, in: [base, close, far, otherCategory])
        #expect(found.map(\.id) == [2])
        #expect(found[0].sharedActives == ["Ceramides", "Niacinamide"])
    }

    // MARK: Shop links

    @Test("Titles come out of Tokopedia and Shopee links and out of shared TikTok text")
    func shopTitles() {
        #expect(ShopLinkParser.title(from: URL(string: "https://www.tokopedia.com/skintific/skintific-5x-ceramide-barrier-moisture-gel-30g")!)
                == "skintific 5x ceramide barrier moisture gel 30g")
        #expect(ShopLinkParser.title(from: URL(string: "https://shopee.co.id/Wardah-Lightening-Day-Cream-30ml-i.123456.7890123")!)
                == "Wardah Lightening Day Cream 30ml")
        #expect(ShopLinkParser.title(from: URL(string: "https://shop.tiktok.com/view/product/1729384756")!) == nil)
        #expect(ShopLinkParser.title(fromText: "Check out Biore UV Aqua Rich Watery Essence Rp 89.000 https://vt.tiktok.com/ZS123/")
                == "Biore UV Aqua Rich Watery Essence")
    }

    @Test("A title matches only with the brand and most of the name")
    func shopMatch() {
        let catalog = [ProductFacts(id: 1, brand: "Biore", name: "UV Aqua Rich Watery Essence", category: "Sunscreen", ingredients: []),
                       ProductFacts(id: 2, brand: "Biore", name: "Facial Foam", category: "Cleanser", ingredients: [])]
        #expect(ShopLinkParser.bestMatch(title: "BIORE uv aqua rich watery essence spf50 50g", in: catalog)?.id == 1)
        #expect(ShopLinkParser.bestMatch(title: "aqua rich watery essence", in: catalog) == nil) // no brand
        #expect(ShopLinkParser.bestMatch(title: "biore something else", in: catalog) == nil)
    }

    // MARK: Lighting

    @Test("Lighting tips: absolute limits first, then drift from the user's usual light")
    func lighting() {
        let usual = Array(repeating: ScanLighting(brightness: 0.55, warmth: 0.05), count: 4)
        #expect(LightingCoach.tips(for: ScanLighting(brightness: 0.2, warmth: 0.05), history: usual) == [.tooDark])
        #expect(LightingCoach.tips(for: ScanLighting(brightness: 0.4, warmth: 0.05), history: usual) == [.tooDark])
        #expect(LightingCoach.tips(for: ScanLighting(brightness: 0.55, warmth: 0.2), history: usual) == [.warmerThanUsual])
        #expect(LightingCoach.tips(for: ScanLighting(brightness: 0.56, warmth: 0.04), history: usual).isEmpty)
        #expect(LightingCoach.tips(for: ScanLighting(brightness: 0.4, warmth: 0.2), history: []).isEmpty)
    }
}
