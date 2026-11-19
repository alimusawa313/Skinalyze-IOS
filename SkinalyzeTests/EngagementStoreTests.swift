import Foundation
import Testing
import SkinalyzeKit
@testable import Skinalyze

/// Where streak inputs are kept: the days a routine step was checked off, and the freeze ledger.
@Suite("Engagement store")
struct EngagementStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "engagement-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let today = DayStamp(year: 2026, month: 11, day: 19)

    @Test("A day becomes done with its first checked step and stops being done when every step is unchecked")
    func tracksDoneDays() {
        let store = EngagementStore(defaults: makeDefaults())
        store.setDone(true, on: today)
        #expect(store.doneDays == [today])
        store.setDone(true, on: today) // idempotent
        #expect(store.doneDays == [today])
        store.setDone(false, on: today)
        #expect(store.doneDays.isEmpty)
    }

    @Test("Existing check-offs in the old routine log are imported once, and importing again changes nothing")
    func importsRoutineLogOnce() {
        let defaults = makeDefaults()
        let store = EngagementStore(defaults: defaults)
        let log = "2026-11-17:morning.Cleanser|2026-11-18:evening.Toner|2026-11-18:morning.Cleanser"
        store.importRoutineLogIfNeeded(raw: log)
        #expect(store.doneDays == [DayStamp(year: 2026, month: 11, day: 17), DayStamp(year: 2026, month: 11, day: 18)])
        // A later import (even with different content) is ignored: the store is now the source of truth.
        store.setDone(false, on: DayStamp(year: 2026, month: 11, day: 17))
        store.importRoutineLogIfNeeded(raw: log)
        #expect(store.doneDays == [DayStamp(year: 2026, month: 11, day: 18)])
    }

    @Test("Done days are kept well beyond the old log's two months (a 100-day streak must be countable)")
    func keepsLongHistory() {
        let store = EngagementStore(defaults: makeDefaults())
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        for offset in 0..<150 { store.setDone(true, on: DayStamp(calendar.date(byAdding: .day, value: offset, to: start)!, calendar: calendar)) }
        #expect(store.doneDays.count == 150)
    }

    @Test("The freeze ledger round-trips, and a new user starts with one freeze")
    func ledgerPersists() {
        let defaults = makeDefaults()
        let store = EngagementStore(defaults: defaults)
        #expect(store.ledger == FreezeLedger(available: EngagementStore.startingFreezes))
        var ledger = store.ledger
        ledger.available = 0
        ledger.usedDays = [today]
        store.ledger = ledger
        #expect(EngagementStore(defaults: defaults).ledger == ledger)
    }
}
