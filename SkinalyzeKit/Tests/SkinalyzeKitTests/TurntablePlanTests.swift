import Testing
@testable import SkinalyzeKit

/// The 3D turntable's motion: front → one side → front → other side → front, never past what was captured.
@Suite("3D turntable plan")
struct TurntablePlanTests {
    private let range = -0.6...0.9

    @Test("It starts facing the front and loops back to the front")
    func startsAndEndsAtFront() {
        let plan = TurntablePlan(range: range)
        #expect(abs(plan.yaw(at: 0)) < 1e-9)
        #expect(abs(plan.yaw(at: plan.frameCount)) < 1e-9)
    }

    @Test("It reaches each side's limit and never passes it")
    func staysInsideTheCapturedRange() {
        let plan = TurntablePlan(range: range)
        let yaws = (0..<plan.frameCount).map(plan.yaw(at:))
        #expect(yaws.allSatisfy { $0 >= range.lowerBound - 1e-9 && $0 <= range.upperBound + 1e-9 })
        #expect(abs((yaws.max() ?? 0) - range.upperBound) < 0.01)
        #expect(abs((yaws.min() ?? 0) - range.lowerBound) < 0.01)
    }

    @Test("The turn is smooth: no frame jumps more than a couple of degrees")
    func movesSmoothly() {
        let plan = TurntablePlan(range: -1.57...1.57)
        let yaws = (0...plan.frameCount).map(plan.yaw(at:))
        let largestStep = zip(yaws, yaws.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        #expect(largestStep < 0.07)
    }

    @Test("The video runs six seconds")
    func length() {
        #expect(TurntablePlan(range: range).frameCount == 6 * ReelPlan.framesPerSecond)
    }
}
