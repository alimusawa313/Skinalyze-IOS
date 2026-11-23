import Foundation

/// The before/after slider video: the wipe line starts near the right (mostly the earlier photo), eases across to
/// the left (mostly the later photo) and back, so the video loops.
public struct WipePlan: Sendable, Equatable {
    public static let seconds = 5.0
    /// How far the line travels: share of the width showing the earlier photo.
    public static let range: ClosedRange<Double> = 0.12...0.88

    public let frameCount: Int

    public init() {
        frameCount = Int((Self.seconds * Double(ReelPlan.framesPerSecond)).rounded())
    }

    public func split(at frame: Int) -> Double {
        let phase = Double(((frame % frameCount) + frameCount) % frameCount) / Double(frameCount)
        let middle = (Self.range.lowerBound + Self.range.upperBound) / 2
        let half = (Self.range.upperBound - Self.range.lowerBound) / 2
        return middle + half * cos(2 * .pi * phase)
    }
}

/// The shimmering card video: a holo sheen sweeps across the sticker twice; the video loops.
public struct ShimmerPlan: Sendable, Equatable {
    public static let seconds = 4.0
    public static let passes = 2
    /// The sheen starts and ends this far outside the card (card width = 1).
    public static let overshoot = 0.4

    public let frameCount: Int

    public init() {
        frameCount = Int((Self.seconds * Double(ReelPlan.framesPerSecond)).rounded())
    }

    /// Sheen centre across the card, from −overshoot to 1 + overshoot during each pass.
    public func sheen(at frame: Int) -> Double {
        let framesPerPass = Double(frameCount) / Double(Self.passes)
        let wrapped = Double(((frame % frameCount) + frameCount) % frameCount)
        let within = wrapped.truncatingRemainder(dividingBy: framesPerPass) / framesPerPass
        return -Self.overshoot + within * (1 + 2 * Self.overshoot)
    }
}
