import Foundation

/// The quality checks a frame must pass before it's captured (PLAN.md §11.1).
public enum CaptureGate: String, CaseIterable, Sendable, Hashable {
    case distance
    case centering
    case angle
    case light
    case sharpness
    case stillness
}

/// One instruction shown/spoken to the user — always the most important failing gate.
public enum GuidanceHint: String, Sendable, Hashable {
    case noFace
    case moveCloser
    case moveBack
    case centerFace
    case faceForward
    case turnHeadLeft
    case turnHeadRight
    case levelHead
    case needMoreLight
    case tooBright
    case holdStill
}

/// Face geometry for one frame (Vision/ARKit), in upright image space.
public struct FaceMeasurement: Sendable, Hashable {
    public let bounds: ImageRect
    public let yawDegrees: Double
    public let pitchDegrees: Double
    public let rollDegrees: Double

    public init(bounds: ImageRect, yawDegrees: Double, pitchDegrees: Double, rollDegrees: Double) {
        self.bounds = bounds
        self.yawDegrees = yawDegrees
        self.pitchDegrees = pitchDegrees
        self.rollDegrees = rollDegrees
    }
}

/// Image-quality measurements for the face region of one frame.
public struct FrameQuality: Sendable, Hashable {
    /// Mean luma (0–255) inside the face box.
    public let meanLuma: Double
    /// Fraction of face pixels that are crushed or blown out.
    public let clippedFraction: Double
    /// Laplacian variance of the face crop (higher = sharper).
    public let sharpness: Double
    /// Face-centre movement in normalized units per second.
    public let motion: Double

    public init(meanLuma: Double, clippedFraction: Double, sharpness: Double, motion: Double) {
        self.meanLuma = meanLuma
        self.clippedFraction = clippedFraction
        self.sharpness = sharpness
        self.motion = motion
    }
}

/// Thresholds calibrated for real front cameras (the first set was far too strict: natural breathing failed the
/// stillness gate and the photo never fired). Framing is lenient; blur/motion only reject clearly bad frames.
public struct GateThresholds: Sendable, Hashable {
    public var faceWidth: ClosedRange<Double> = 0.22...0.85
    public var centerTolerance: Double = 0.18
    public var frontMaxYaw: Double = 15
    public var frontMaxPitch: Double = 18
    public var frontMaxRoll: Double = 15
    public var sideYaw: ClosedRange<Double> = 18...65
    public var sideMaxPitch: Double = 22
    public var sideMaxRoll: Double = 20
    public var luma: ClosedRange<Double> = 55...225
    public var maxClippedFraction: Double = 0.3
    public var minSharpness: Double = 4
    public var maxMotion: Double = 0.6
    /// Sign of the yaw reported when the head turns to the subject's right. Calibrate per sensor on device.
    public var rightTurnYawSign: Double = 1

    public static let `default` = GateThresholds()

    public init() {}

    public func yawSign(for angle: CaptureAngle) -> Double {
        switch angle {
        case .front: 0
        case .right: rightTurnYawSign
        case .left: -rightTurnYawSign
        }
    }
}

public struct GateReport: Sendable, Hashable {
    public let passed: Set<CaptureGate>
    public let hint: GuidanceHint?

    public init(passed: Set<CaptureGate>, hint: GuidanceHint?) {
        self.passed = passed
        self.hint = hint
    }

    public var allPassed: Bool { passed.count == CaptureGate.allCases.count }
}

public enum GateEvaluator {
    public static func evaluate(
        face: FaceMeasurement?,
        quality: FrameQuality,
        angle: CaptureAngle,
        thresholds: GateThresholds = .default
    ) -> GateReport {
        guard let face else { return GateReport(passed: [], hint: .noFace) }

        // Ordered by priority: the first failing gate provides the single hint shown to the user.
        let checks: [(CaptureGate, GuidanceHint?)] = [
            (.distance, distanceHint(face, thresholds)),
            (.centering, centeringHint(face, thresholds)),
            (.angle, poseHint(face, angle, thresholds)),
            (.light, lightHint(quality, thresholds)),
            (.sharpness, quality.sharpness >= thresholds.minSharpness ? nil : .holdStill),
            (.stillness, quality.motion <= thresholds.maxMotion ? nil : .holdStill),
        ]
        let passed = Set(checks.filter { $0.1 == nil }.map(\.0))
        let hint = checks.lazy.compactMap(\.1).first
        return GateReport(passed: passed, hint: hint)
    }

    /// Hint asking the user to turn their head toward the given side.
    public static func turnHint(towards angle: CaptureAngle) -> GuidanceHint {
        angle == .left ? .turnHeadLeft : .turnHeadRight
    }

    private static func distanceHint(_ face: FaceMeasurement, _ t: GateThresholds) -> GuidanceHint? {
        if face.bounds.width < t.faceWidth.lowerBound { return .moveCloser }
        if face.bounds.width > t.faceWidth.upperBound { return .moveBack }
        return nil
    }

    private static func centeringHint(_ face: FaceMeasurement, _ t: GateThresholds) -> GuidanceHint? {
        let centerX = face.bounds.x + face.bounds.width / 2
        let centerY = face.bounds.y + face.bounds.height / 2
        let offCenter = abs(centerX - 0.5) > t.centerTolerance || abs(centerY - 0.5) > t.centerTolerance
        return offCenter ? .centerFace : nil
    }

    private static func poseHint(_ face: FaceMeasurement, _ angle: CaptureAngle, _ t: GateThresholds) -> GuidanceHint? {
        switch angle {
        case .front:
            if abs(face.yawDegrees) > t.frontMaxYaw { return .faceForward }
            if abs(face.pitchDegrees) > t.frontMaxPitch || abs(face.rollDegrees) > t.frontMaxRoll { return .levelHead }
            return nil
        case .left, .right:
            let signedYaw = face.yawDegrees * t.yawSign(for: angle)
            if signedYaw < t.sideYaw.lowerBound { return turnHint(towards: angle) }
            if signedYaw > t.sideYaw.upperBound { return turnHint(towards: angle == .left ? .right : .left) }
            if abs(face.pitchDegrees) > t.sideMaxPitch || abs(face.rollDegrees) > t.sideMaxRoll { return .levelHead }
            return nil
        }
    }

    private static func lightHint(_ q: FrameQuality, _ t: GateThresholds) -> GuidanceHint? {
        if q.meanLuma < t.luma.lowerBound { return .needMoreLight }
        if q.meanLuma > t.luma.upperBound || q.clippedFraction > t.maxClippedFraction { return .tooBright }
        return nil
    }
}

/// Requires every gate to hold continuously for `holdDuration` before capturing. Immutable: `updated` returns a copy.
public struct StabilityTracker: Sendable, Hashable {
    public let holdDuration: TimeInterval
    private let passingSince: TimeInterval?
    private static let epsilon = 1e-9

    public init(holdDuration: TimeInterval = 0.3) {
        self.init(holdDuration: holdDuration, passingSince: nil)
    }

    private init(holdDuration: TimeInterval, passingSince: TimeInterval?) {
        self.holdDuration = holdDuration
        self.passingSince = passingSince
    }

    public func updated(allPassed: Bool, at time: TimeInterval) -> StabilityTracker {
        StabilityTracker(holdDuration: holdDuration, passingSince: allPassed ? (passingSince ?? time) : nil)
    }

    /// 0…1 — drives the closing animation of the capture ring.
    public func progress(at time: TimeInterval) -> Double {
        guard let passingSince, holdDuration > 0 else { return 0 }
        return min(max((time - passingSince) / holdDuration, 0), 1)
    }

    public func isReady(at time: TimeInterval) -> Bool {
        guard let passingSince else { return false }
        return time - passingSince + Self.epsilon >= holdDuration
    }
}

/// Shows one instruction at a time without flicker: a new hint must persist for `delay` before it replaces the current
/// one. Clearing (nil = all good) and the very first hint show immediately. Immutable: `updated` returns a copy.
public struct HintStabilizer: Sendable, Hashable {
    public let delay: TimeInterval
    public private(set) var displayed: GuidanceHint?
    private var candidate: GuidanceHint?
    private var candidateSince: TimeInterval?
    private var hasShown = false

    public init(delay: TimeInterval = 0.6) {
        self.delay = delay
    }

    public func updated(candidate new: GuidanceHint?, at time: TimeInterval) -> HintStabilizer {
        var next = self
        if new == nil || !hasShown {
            next.displayed = new
            next.candidate = new
            next.candidateSince = time
            next.hasShown = next.hasShown || new != nil
            return next
        }
        if new == displayed {
            next.candidate = new
            next.candidateSince = time
            return next
        }
        if new != candidate {
            next.candidate = new
            next.candidateSince = time
        } else if let since = candidateSince, time - since >= delay {
            next.displayed = new
        }
        return next
    }
}
