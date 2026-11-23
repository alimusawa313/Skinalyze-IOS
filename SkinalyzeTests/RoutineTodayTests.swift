import Foundation
import Testing
@testable import Skinalyze
import SkinalyzeKit

/// Ticking the routine outside the checklist: Siri / Shortcuts and the Apple Watch (P14), plus the builder's steps (P5).
@MainActor
@Suite("Routine outside the app")
struct RoutineTodayTests {
    private func defaults(withProducts: Bool = true) -> UserDefaults {
        let defaults = freshDefaults()
        if withProducts {
            defaults.set(18, forKey: ProductCatalog.Slot.sunscreen.storageKey)
            defaults.set(1, forKey: ProductCatalog.Slot.cleanser.storageKey)
        }
        return defaults
    }

    @Test("Steps follow the checklist order, with extra steps between toner and moisturizer")
    func order() throws {
        let defaults = defaults()
        let plan = RoutinePlan(morning: [RoutineStep(id: "serum-1", kind: .serum, customName: "Vit C")], evening: [])
        defaults.set(try JSONEncoder().encode(plan), forKey: "routinePlan")
        #expect(RoutineToday.steps(for: .morning, defaults: defaults).map(\.slot) == ["Cleanser", "serum-1", "Sunscreen"])
        #expect(RoutineToday.steps(for: .evening, defaults: defaults).map(\.slot) == ["Cleanser"])
    }

    @Test("Siri's check-off ticks every step once and counts the day for the streak")
    func completeAll() {
        let defaults = defaults()
        #expect(RoutineToday.completeAll(.morning, defaults: defaults) == 2)
        #expect(RoutineToday.completeAll(.morning, defaults: defaults) == 0)
        #expect(EngagementStore(defaults: defaults).doneDays.contains(DayStamp(.now, calendar: .current)))
    }

    @Test("A watch tick applies today, unticks too, and is ignored for another day")
    func watchTicks() {
        let defaults = defaults()
        let today = DayStamp(.now, calendar: .current).string
        #expect(RoutineToday.apply(WatchCheckOff(day: today, stepID: "morning.Sunscreen", done: true), defaults: defaults))
        #expect(RoutineToday.isDone(.morning, slot: "Sunscreen", defaults: defaults))
        RoutineToday.apply(WatchCheckOff(day: today, stepID: "morning.Sunscreen", done: false), defaults: defaults)
        #expect(!RoutineToday.isDone(.morning, slot: "Sunscreen", defaults: defaults))
        #expect(!EngagementStore(defaults: defaults).doneDays.contains(DayStamp(.now, calendar: .current)))
        #expect(!RoutineToday.apply(WatchCheckOff(day: "2001-01-01", stepID: "morning.Sunscreen", done: true), defaults: defaults))
        #expect(!RoutineToday.apply(WatchCheckOff(day: today, stepID: "noon.Sunscreen", done: true), defaults: defaults))
    }

    @Test("What the watch gets lists both routines with today's ticks")
    func watchState() {
        let defaults = defaults()
        RoutineToday.set(.morning, slot: "Cleanser", done: true, defaults: defaults)
        let state = RoutineToday.watchState(defaults: defaults)
        #expect(state.morning.map(\.id) == ["morning.Cleanser", "morning.Sunscreen"])
        #expect(state.morning.map(\.done) == [true, false])
        #expect(state.evening.map(\.id) == ["evening.Cleanser"])
    }

    @Test("The builder warns about a typed-in retinoid next to a BHA step")
    func builderWarnings() {
        let model = RoutineModel(defaults: defaults(withProducts: false))
        model.add(RoutineStep(kind: .treatment, customName: "Night retinol", actives: [.retinoid]), to: .evening)
        model.add(RoutineStep(kind: .exfoliant, customName: "BHA liquid", actives: [.exfoliantBHA]), to: .evening)
        #expect(model.warnings(for: .evening).map(\.kind) == [.retinoidWithAcid])
        #expect(model.warnings(for: .morning).isEmpty)
    }
}
