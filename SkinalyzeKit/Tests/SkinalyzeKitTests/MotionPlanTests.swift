import Foundation
import Testing
@testable import SkinalyzeKit

/// Timing for the before/after slider video and the shimmering card video.
@Suite("Motion export plans")
struct MotionPlanTests {
    @Test("The slider starts showing mostly the earlier photo, sweeps to mostly the later one, and comes back")
    func wipeSweeps() {
        let plan = WipePlan()
        let splits = (0..<plan.frameCount).map(plan.split(at:))
        #expect(abs(splits[0] - WipePlan.range.upperBound) < 0.01)
        #expect(abs((splits.min() ?? 1) - WipePlan.range.lowerBound) < 0.01)
        #expect(abs(splits[plan.frameCount - 1] - WipePlan.range.upperBound) < 0.02)
        #expect(splits.allSatisfy { WipePlan.range.contains($0) })
    }

    @Test("The slider never jumps between frames")
    func wipeIsSmooth() {
        let plan = WipePlan()
        let splits = (0...plan.frameCount).map(plan.split(at:))
        let largest = zip(splits, splits.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        #expect(largest < 0.03)
    }

    @Test("The sheen crosses the card fully, twice, and the video loops")
    func shimmerCrosses() {
        let plan = ShimmerPlan()
        let positions = (0..<plan.frameCount).map(plan.sheen(at:))
        #expect((positions.min() ?? 0) <= -0.3)
        #expect((positions.max() ?? 0) >= 1.3)
        #expect(abs(plan.sheen(at: 0) - plan.sheen(at: plan.frameCount)) < 1e-9)
        let crossings = zip(positions, positions.dropFirst()).filter { $0 > $1 }.count
        #expect(crossings == 1) // one wrap inside the video = two passes
    }

    @Test("Both videos are short, 30 frames a second")
    func lengths() {
        #expect(WipePlan().frameCount == 5 * ReelPlan.framesPerSecond)
        #expect(ShimmerPlan().frameCount == 4 * ReelPlan.framesPerSecond)
    }
}
