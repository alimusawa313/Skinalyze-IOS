import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Capture gates")
struct CaptureGateTests {
    private let good = FrameQuality(meanLuma: 130, clippedFraction: 0.01, sharpness: 400, motion: 0.005)

    private func face(width: Double = 0.55, centerX: Double = 0.5, centerY: Double = 0.5,
                      yaw: Double = 0, pitch: Double = 0, roll: Double = 0) -> FaceMeasurement {
        FaceMeasurement(
            bounds: NormalizedRect(x: centerX - width / 2, y: centerY - width * 0.65, width: width, height: width * 1.3),
            yawDegrees: yaw, pitchDegrees: pitch, rollDegrees: roll
        )
    }

    @Test("A well-framed, still, bright, sharp frontal face passes every gate")
    func allPass() {
        let report = GateEvaluator.evaluate(face: face(), quality: good, angle: .front)
        #expect(report.allPassed)
        #expect(report.hint == nil)
    }

    @Test("No face gives the noFace hint and passes nothing")
    func noFace() {
        let report = GateEvaluator.evaluate(face: nil, quality: good, angle: .front)
        #expect(report.passed.isEmpty)
        #expect(report.hint == .noFace)
    }

    @Test("Distance: too small asks to move closer, too big asks to move back",
          arguments: [(0.30, GuidanceHint.moveCloser), (0.80, GuidanceHint.moveBack)])
    func distance(width: Double, hint: GuidanceHint) {
        let report = GateEvaluator.evaluate(face: face(width: width), quality: good, angle: .front)
        #expect(!report.passed.contains(.distance))
        #expect(report.hint == hint)
    }

    @Test("Off-centre face fails centering")
    func centering() {
        let report = GateEvaluator.evaluate(face: face(centerX: 0.7), quality: good, angle: .front)
        #expect(!report.passed.contains(.centering))
        #expect(report.hint == .centerFace)
    }

    @Test("Front capture needs a level, forward-facing head")
    func frontPose() {
        #expect(GateEvaluator.evaluate(face: face(yaw: 20), quality: good, angle: .front).hint == .faceForward)
        #expect(GateEvaluator.evaluate(face: face(roll: 15), quality: good, angle: .front).hint == .levelHead)
        #expect(GateEvaluator.evaluate(face: face(pitch: -18), quality: good, angle: .front).hint == .levelHead)
    }

    @Test("Side captures need the head turned into the target yaw range, in the right direction")
    func sidePose() {
        let target = GateThresholds.default.sideYaw
        let rightYaw = GateThresholds.default.yawSign(for: .right) * (target.lowerBound + 5)
        #expect(GateEvaluator.evaluate(face: face(yaw: rightYaw), quality: good, angle: .right).allPassed)
        let notEnough = GateEvaluator.evaluate(face: face(yaw: 0), quality: good, angle: .right)
        #expect(notEnough.hint == GateEvaluator.turnHint(towards: .right))
        let tooFar = GateEvaluator.evaluate(face: face(yaw: rightYaw * 3), quality: good, angle: .right)
        #expect(tooFar.hint == GateEvaluator.turnHint(towards: .left))
        #expect(GateEvaluator.turnHint(towards: .right) != GateEvaluator.turnHint(towards: .left))
    }

    @Test("Light gate: too dark, too bright, too many clipped pixels")
    func light() {
        let dark = FrameQuality(meanLuma: 50, clippedFraction: 0, sharpness: 400, motion: 0)
        let bright = FrameQuality(meanLuma: 220, clippedFraction: 0, sharpness: 400, motion: 0)
        let clipped = FrameQuality(meanLuma: 130, clippedFraction: 0.2, sharpness: 400, motion: 0)
        #expect(GateEvaluator.evaluate(face: face(), quality: dark, angle: .front).hint == .needMoreLight)
        #expect(GateEvaluator.evaluate(face: face(), quality: bright, angle: .front).hint == .tooBright)
        #expect(GateEvaluator.evaluate(face: face(), quality: clipped, angle: .front).hint == .tooBright)
    }

    @Test("Blur or motion asks the user to hold still")
    func stillness() {
        let blurry = FrameQuality(meanLuma: 130, clippedFraction: 0, sharpness: 10, motion: 0)
        let moving = FrameQuality(meanLuma: 130, clippedFraction: 0, sharpness: 400, motion: 0.2)
        #expect(GateEvaluator.evaluate(face: face(), quality: blurry, angle: .front).hint == .holdStill)
        #expect(GateEvaluator.evaluate(face: face(), quality: moving, angle: .front).hint == .holdStill)
        #expect(!GateEvaluator.evaluate(face: face(), quality: blurry, angle: .front).passed.contains(.sharpness))
    }

    @Test("Hints follow priority: framing before light before stillness")
    func hintPriority() {
        let bad = FrameQuality(meanLuma: 40, clippedFraction: 0, sharpness: 5, motion: 1)
        #expect(GateEvaluator.evaluate(face: face(width: 0.2), quality: bad, angle: .front).hint == .moveCloser)
        #expect(GateEvaluator.evaluate(face: face(), quality: bad, angle: .front).hint == .needMoreLight)
    }
}

@Suite("Stability hold")
struct StabilityTrackerTests {
    @Test("Ready only after all gates hold continuously for the hold duration")
    func holdDuration() {
        var tracker = StabilityTracker(holdDuration: 0.7)
        tracker = tracker.updated(allPassed: true, at: 10.0)
        #expect(!tracker.isReady(at: 10.5))
        #expect(abs(tracker.progress(at: 10.35) - 0.5) < 0.0001)
        #expect(tracker.isReady(at: 10.7))
    }

    @Test("Any failed frame resets the hold")
    func reset() {
        let tracker = StabilityTracker(holdDuration: 0.7)
            .updated(allPassed: true, at: 0)
            .updated(allPassed: false, at: 0.5)
            .updated(allPassed: true, at: 0.6)
        #expect(!tracker.isReady(at: 1.2))
        #expect(tracker.isReady(at: 1.3))
    }

    @Test("Updating returns a new value and never mutates the original")
    func immutable() {
        let original = StabilityTracker(holdDuration: 0.7)
        _ = original.updated(allPassed: true, at: 1)
        #expect(original.progress(at: 5) == 0)
    }
}

@Suite("Frame quality measurement")
struct FrameAnalysisTests {
    private func image(_ width: Int, _ height: Int, _ pixel: (Int, Int) -> UInt8) -> GrayImage {
        GrayImage(width: width, height: height, pixels: (0..<height).flatMap { y in (0..<width).map { x in pixel(x, y) } })
    }

    @Test("Mean luma and clipped fraction")
    func luma() {
        let half = image(10, 10) { x, _ in x < 5 ? 0 : 255 }
        #expect(FrameAnalysis.meanLuma(half) == 127.5)
        #expect(FrameAnalysis.clippedFraction(half) == 1.0)
        let mid = image(4, 4) { _, _ in 120 }
        #expect(FrameAnalysis.clippedFraction(mid) == 0)
    }

    @Test("A sharp checkerboard scores far higher than a flat or smooth image")
    func sharpness() {
        let checker = image(32, 32) { x, y in (x + y) % 2 == 0 ? 0 : 255 }
        let flat = image(32, 32) { _, _ in 128 }
        let gradient = image(32, 32) { x, _ in UInt8(x * 8) }
        #expect(FrameAnalysis.laplacianVariance(flat) == 0)
        #expect(FrameAnalysis.laplacianVariance(checker) > FrameAnalysis.laplacianVariance(gradient) * 100)
    }

    @Test("Tiny images don't crash")
    func tiny() {
        let one = image(1, 1) { _, _ in 9 }
        #expect(FrameAnalysis.laplacianVariance(one) == 0)
        #expect(FrameAnalysis.meanLuma(GrayImage(width: 0, height: 0, pixels: [])) == 0)
    }

    @Test("Motion is the face-centre displacement normalised per second")
    func motion() {
        let a = NormalizedRect(x: 0.40, y: 0.40, width: 0.2, height: 0.2)
        let b = NormalizedRect(x: 0.41, y: 0.40, width: 0.2, height: 0.2)
        #expect(abs(FrameAnalysis.motion(from: a, to: b, elapsed: 0.5) - 0.02) < 0.0001)
        #expect(FrameAnalysis.motion(from: a, to: b, elapsed: 0) == 0)
    }
}
