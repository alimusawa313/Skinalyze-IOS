import Foundation
import Testing
@testable import SkinalyzeKit

@Suite("Capture gates")
struct CaptureGateTests {
    private let good = FrameQuality(meanLuma: 130, clippedFraction: 0.01, sharpness: 400, motion: 0.005)

    private func face(width: Double = 0.55, centerX: Double = 0.5, centerY: Double = 0.5,
                      yaw: Double = 0, pitch: Double = 0, roll: Double = 0) -> FaceMeasurement {
        FaceMeasurement(
            bounds: ImageRect(x: centerX - width / 2, y: centerY - width * 0.65, width: width, height: width * 1.3),
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
          arguments: [(0.15, GuidanceHint.moveCloser), (0.95, GuidanceHint.moveBack)])
    func distance(width: Double, hint: GuidanceHint) {
        let report = GateEvaluator.evaluate(face: face(width: width), quality: good, angle: .front)
        #expect(!report.passed.contains(.distance))
        #expect(report.hint == hint)
    }

    @Test("Off-centre face fails centering")
    func centering() {
        let report = GateEvaluator.evaluate(face: face(centerX: 0.75), quality: good, angle: .front)
        #expect(!report.passed.contains(.centering))
        #expect(report.hint == .centerFace)
    }

    @Test("Front capture needs a level, forward-facing head")
    func frontPose() {
        #expect(GateEvaluator.evaluate(face: face(yaw: 25), quality: good, angle: .front).hint == .faceForward)
        #expect(GateEvaluator.evaluate(face: face(roll: 20), quality: good, angle: .front).hint == .levelHead)
        #expect(GateEvaluator.evaluate(face: face(pitch: -25), quality: good, angle: .front).hint == .levelHead)
    }

    @Test("Side captures need the head turned into the target yaw range, in the right direction")
    func sidePose() {
        let target = GateThresholds.default.sideYaw
        let rightYaw = GateThresholds.default.yawSign(for: .right) * (target.lowerBound + 5)
        #expect(GateEvaluator.evaluate(face: face(yaw: rightYaw), quality: good, angle: .right).allPassed)
        let notEnough = GateEvaluator.evaluate(face: face(yaw: 0), quality: good, angle: .right)
        #expect(notEnough.hint == GateEvaluator.turnHint(towards: .right))
        // A full profile is welcome; only past the range (a physically implausible reading) asks to turn back.
        let beyond = GateThresholds.default.yawSign(for: .right) * (target.upperBound + 10)
        let tooFar = GateEvaluator.evaluate(face: face(yaw: beyond), quality: good, angle: .right)
        #expect(tooFar.hint == GateEvaluator.turnHint(towards: .left))
        #expect(GateEvaluator.turnHint(towards: .right) != GateEvaluator.turnHint(towards: .left))
    }

    @Test("Light gate: too dark, too bright, too many clipped pixels")
    func light() {
        let dark = FrameQuality(meanLuma: 50, clippedFraction: 0, sharpness: 400, motion: 0)
        let bright = FrameQuality(meanLuma: 245, clippedFraction: 0, sharpness: 400, motion: 0)
        let clipped = FrameQuality(meanLuma: 130, clippedFraction: 0.4, sharpness: 400, motion: 0)
        #expect(GateEvaluator.evaluate(face: face(), quality: dark, angle: .front).hint == .needMoreLight)
        #expect(GateEvaluator.evaluate(face: face(), quality: bright, angle: .front).hint == .tooBright)
        #expect(GateEvaluator.evaluate(face: face(), quality: clipped, angle: .front).hint == .tooBright)
    }

    @Test("Blur or motion asks the user to hold still")
    func stillness() {
        let blurry = FrameQuality(meanLuma: 130, clippedFraction: 0, sharpness: 1, motion: 0)
        let moving = FrameQuality(meanLuma: 130, clippedFraction: 0, sharpness: 400, motion: 1.5)
        #expect(GateEvaluator.evaluate(face: face(), quality: blurry, angle: .front).hint == .holdStill)
        #expect(GateEvaluator.evaluate(face: face(), quality: moving, angle: .front).hint == .holdStill)
        #expect(!GateEvaluator.evaluate(face: face(), quality: blurry, angle: .front).passed.contains(.sharpness))
    }

    @Test("Hints follow priority: framing before light before stillness")
    func hintPriority() {
        let bad = FrameQuality(meanLuma: 40, clippedFraction: 0, sharpness: 5, motion: 1)
        #expect(GateEvaluator.evaluate(face: face(width: 0.1), quality: bad, angle: .front).hint == .moveCloser)
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
        let a = ImageRect(x: 0.40, y: 0.40, width: 0.2, height: 0.2)
        let b = ImageRect(x: 0.41, y: 0.40, width: 0.2, height: 0.2)
        #expect(abs(FrameAnalysis.motion(from: a, to: b, elapsed: 0.5) - 0.02) < 0.0001)
        #expect(FrameAnalysis.motion(from: a, to: b, elapsed: 0) == 0)
    }
}

@Suite("Calibrated for real phones")
struct RealWorldGateTests {
    @Test("Natural micro-movement and an unremarkable selfie pass every gate")
    func naturalSelfie() {
        let face = FaceMeasurement(bounds: ImageRect(x: 0.32, y: 0.3, width: 0.36, height: 0.45),
                                   yawDegrees: 6, pitchDegrees: -8, rollDegrees: 4)
        let quality = FrameQuality(meanLuma: 115, clippedFraction: 0.06, sharpness: 25, motion: 0.12)
        #expect(GateEvaluator.evaluate(face: face, quality: quality, angle: .front).allPassed)
    }

    private let quality = FrameQuality(meanLuma: 115, clippedFraction: 0.06, sharpness: 25, motion: 0.12)

    @Test("A full side profile captures: the face box is narrow and off-centre there, and roll estimates are noisy")
    func extremeProfileCaptures() {
        // Measured on device at near-full profile: Vision box 0.22 wide and shrinking, centre x ≈ 0.66–0.72, roll −11…−24.
        let profile = FaceMeasurement(bounds: ImageRect(x: 0.62, y: 0.38, width: 0.16, height: 0.17),
                                      yawDegrees: 74, pitchDegrees: 7, rollDegrees: -24)
        #expect(GateEvaluator.evaluate(face: profile, quality: quality, angle: .right).allPassed)
        let mirrored = FaceMeasurement(bounds: ImageRect(x: 0.22, y: 0.38, width: 0.16, height: 0.17),
                                       yawDegrees: -74, pitchDegrees: 7, rollDegrees: 24)
        #expect(GateEvaluator.evaluate(face: mirrored, quality: quality, angle: .left).allPassed)
    }

    @Test("A real turn captures; a slight one asks for more (the 3D sides come from these photos)")
    func sideNeedsARealTurn() {
        let turned = FaceMeasurement(bounds: ImageRect(x: 0.24, y: 0.34, width: 0.32, height: 0.24),
                                     yawDegrees: -36, pitchDegrees: 9, rollDegrees: -20)
        #expect(GateEvaluator.evaluate(face: turned, quality: quality, angle: .left).allPassed)
        let slight = FaceMeasurement(bounds: ImageRect(x: 0.24, y: 0.34, width: 0.32, height: 0.24),
                                     yawDegrees: -22, pitchDegrees: 9, rollDegrees: -10)
        #expect(GateEvaluator.evaluate(face: slight, quality: quality, angle: .left).hint == GateEvaluator.turnHint(towards: .left))
    }

    @Test("Side leniency doesn't loosen the front photo: a narrow, off-centre face is still rejected there")
    func frontStaysStrict() {
        let small = FaceMeasurement(bounds: ImageRect(x: 0.62, y: 0.38, width: 0.16, height: 0.17),
                                    yawDegrees: 2, pitchDegrees: 3, rollDegrees: 1)
        #expect(!GateEvaluator.evaluate(face: small, quality: quality, angle: .front).allPassed)
    }
}

@Suite("Hint stabiliser")
struct HintStabilizerTests {
    @Test("A new hint only shows after it has persisted, so text never flickers")
    func debounce() {
        var stabilizer = HintStabilizer(delay: 0.6)
        stabilizer = stabilizer.updated(candidate: .moveCloser, at: 0)
        #expect(stabilizer.displayed == .moveCloser, "first hint shows immediately")
        stabilizer = stabilizer.updated(candidate: .holdStill, at: 0.1)
        stabilizer = stabilizer.updated(candidate: .moveCloser, at: 0.2)
        stabilizer = stabilizer.updated(candidate: .holdStill, at: 0.3)
        #expect(stabilizer.displayed == .moveCloser, "flapping candidates never reach the screen")
        stabilizer = stabilizer.updated(candidate: .holdStill, at: 1.0)
        #expect(stabilizer.displayed == .holdStill)
    }

    @Test("Clearing to 'all good' is immediate")
    func clears() {
        let stabilizer = HintStabilizer(delay: 0.6).updated(candidate: .moveCloser, at: 0).updated(candidate: nil, at: 0.05)
        #expect(stabilizer.displayed == nil)
    }
}
