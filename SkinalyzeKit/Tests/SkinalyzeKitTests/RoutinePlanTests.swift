import Foundation
import Testing
@testable import SkinalyzeKit

/// P5 routine builder rules and the P14 watch check-off.
@Suite("Routine builder")
struct RoutinePlanTests {
    let retinol = RoutineItem(label: "Retinol serum", categories: [.retinoid])
    let bha = RoutineItem(label: "BHA toner", categories: [.exfoliantBHA])
    let aha = RoutineItem(label: "AHA peel", categories: [.exfoliantAHA])
    let bp = RoutineItem(label: "BP gel", categories: [.benzoylPeroxide])
    let vitC = RoutineItem(label: "Vitamin C", categories: [.vitaminC])
    let spf = RoutineItem(label: "SPF", categories: [], isSunscreen: true)
    let moisturizer = RoutineItem(label: "Cream", categories: [.humectant])

    func kinds(_ items: [RoutineItem], _ part: RoutinePart) -> [RoutineWarning.Kind] {
        RoutineAdvisor.warnings(for: items, part: part).map(\.kind)
    }

    @Test("Evening: retinoid with an acid, retinoid with benzoyl peroxide, two acids")
    func evening() {
        #expect(kinds([retinol, bha], .evening) == [.retinoidWithAcid])
        #expect(kinds([retinol, bp], .evening) == [.retinoidWithBenzoyl])
        #expect(kinds([bha, aha, moisturizer], .evening) == [.doubleExfoliation])
        #expect(kinds([moisturizer, retinol], .evening).isEmpty)
    }

    @Test("Vitamin C with an acid or benzoyl peroxide is flagged, naming both")
    func vitaminC() {
        let warnings = RoutineAdvisor.warnings(for: [vitC, bp, spf], part: .morning)
        #expect(warnings.map(\.kind) == [.vitaminCWithAcidOrBenzoyl])
        #expect(warnings[0].items == ["Vitamin C", "BP gel"])
    }

    @Test("Morning: retinoid is an evening step, and acids need sunscreen")
    func morning() {
        #expect(kinds([retinol, spf], .morning) == [.retinoidInMorning])
        #expect(kinds([bha], .morning) == [.morningWithoutSunscreen])
        #expect(kinds([bha, spf], .morning).isEmpty)
        #expect(kinds([moisturizer], .morning).isEmpty)
    }

    @Test("A plan keeps at most six extra steps per part and survives a round trip")
    func plan() throws {
        var plan = RoutinePlan.empty
        plan[.evening] = (0..<9).map { RoutineStep(id: "\($0)", kind: .serum) }
        #expect(plan.evening.count == RoutinePlan.maximumExtraSteps)
        let decoded = try JSONDecoder().decode(RoutinePlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded == plan)
    }
}
