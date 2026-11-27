import Foundation
import Testing
@testable import Skinalyze
import SkinalyzeKit

/// The links the App Store's in-app events open: `skinalyze://wrapped` and `skinalyze://challenge/<kind>`.
@MainActor
@Suite("Event deep links")
struct DeepLinkTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    @Test("In the first week of January, wrapped opens last year's Wrapped")
    func wrappedInJanuary() {
        let model = AppModel()
        model.open(URL(string: "skinalyze://wrapped")!, now: date(2027, 1, 3), calendar: calendar)
        #expect(model.pendingRecap?.kind == .year)
        #expect(model.pendingRecap?.first == DayStamp(year: 2026, month: 1, day: 1))
    }

    @Test("Outside that week, wrapped opens the last finished quarter")
    func wrappedLater() {
        let model = AppModel()
        model.open(URL(string: "skinalyze://wrapped")!, now: date(2027, 2, 20), calendar: calendar)
        #expect(model.pendingRecap?.kind == .quarter)
        #expect(model.pendingRecap?.first == DayStamp(year: 2026, month: 10, day: 1))
    }

    @Test("challenge/sunscreen offers the sunscreen challenge")
    func challenge() {
        let model = AppModel()
        model.open(URL(string: "skinalyze://challenge/sunscreen")!)
        #expect(model.pendingChallenge?.kind == .sunscreen)
    }

    @Test("An unknown challenge is ignored and goes to Today")
    func unknownChallenge() {
        let model = AppModel()
        model.selectedTab = .products
        model.open(URL(string: "skinalyze://challenge/marathon")!)
        #expect(model.pendingChallenge == nil)
        #expect(model.selectedTab == .today)
    }
}
