import Testing
@testable import SkinalyzeKit

/// Timing of the glow-up reel: how long it runs and what is on screen at every frame.
@Suite("Glow-up reel plan")
struct ReelPlanTests {
    @Test("A reel needs at least two scans")
    func needsTwoScans() {
        #expect(ReelPlan(scanCount: 0) == nil)
        #expect(ReelPlan(scanCount: 1) == nil)
        #expect(ReelPlan(scanCount: 2) != nil)
    }

    @Test("The reel always runs between six and twelve seconds", arguments: [2, 3, 5, 8, 10, 20, 60])
    func lengthStaysInRange(count: Int) throws {
        let plan = try #require(ReelPlan(scanCount: count))
        let seconds = Double(plan.frameCount) / Double(ReelPlan.framesPerSecond)
        #expect(seconds >= ReelPlan.minimumSeconds - 0.05)
        #expect(seconds <= ReelPlan.maximumSeconds + 0.05)
    }

    @Test("It starts on the oldest scan and ends holding the newest")
    func startsOldestEndsNewest() throws {
        let plan = try #require(ReelPlan(scanCount: 5))
        let first = plan.frame(at: 0)
        #expect(first.current == 0)
        #expect(first.blend == 0)
        let last = plan.frame(at: plan.frameCount - 1)
        #expect(last.current == 4)
        #expect(last.next == nil)
        #expect(last.isOutro)
    }

    @Test("Scans appear in order and none is skipped")
    func everyScanAppearsInOrder() throws {
        let plan = try #require(ReelPlan(scanCount: 7))
        let order = (0..<plan.frameCount).map { plan.frame(at: $0).current }
        #expect(order == order.sorted())
        #expect(Set(order) == Set(0..<7))
    }

    @Test("Each change is a crossfade: the blend climbs from 0 towards 1, then the next scan takes over")
    func crossfades() throws {
        let plan = try #require(ReelPlan(scanCount: 3))
        let frames = (0..<plan.frameCount).map(plan.frame(at:))
        let firstScan = frames.filter { $0.current == 0 }
        #expect(firstScan.first?.blend == 0)
        #expect(firstScan.contains { $0.blend > 0.5 })
        #expect(firstScan.allSatisfy { $0.blend >= 0 && $0.blend < 1 })
        #expect(firstScan.map(\.blend) == firstScan.map(\.blend).sorted())
        #expect(firstScan.allSatisfy { $0.next == 1 })
    }

    @Test("Frames outside the reel clamp to its ends")
    func clampsOutOfRange() throws {
        let plan = try #require(ReelPlan(scanCount: 4))
        #expect(plan.frame(at: -5) == plan.frame(at: 0))
        #expect(plan.frame(at: plan.frameCount + 50) == plan.frame(at: plan.frameCount - 1))
    }

    @Test("The index counts from one scan's value to the next during a crossfade")
    func countsBetweenValues() {
        #expect(ReelPlan.displayedValue(from: 20, to: 10, blend: 0) == 20)
        #expect(ReelPlan.displayedValue(from: 20, to: 10, blend: 0.5) == 15)
        #expect(ReelPlan.displayedValue(from: 20, to: nil, blend: 0.7) == 20)
        #expect(ReelPlan.displayedValue(from: 3, to: 9, blend: 0.999) == 9)
    }

    @Test("With many scans, an even sample is used that keeps the oldest and the newest")
    func samplesManyScans() {
        #expect(ReelPlan.selection(count: 5) == [0, 1, 2, 3, 4])
        let sample = ReelPlan.selection(count: 100)
        #expect(sample.count == ReelPlan.maximumScans)
        #expect(sample.first == 0)
        #expect(sample.last == 99)
        #expect(sample == sample.sorted())
        #expect(Set(sample).count == sample.count)
    }
}
