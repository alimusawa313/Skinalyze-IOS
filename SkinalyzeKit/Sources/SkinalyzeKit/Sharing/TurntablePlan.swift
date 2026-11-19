import Foundation

/// The 3D turntable's motion. The head starts facing the viewer, swings to one captured limit, back through the
/// front to the other, and returns — so the video loops cleanly and never shows a side that was not scanned.
public struct TurntablePlan: Sendable, Equatable {
    public static let seconds = 6.0

    /// How far the head may turn each way, in radians (from the viewer's turn limits).
    public let range: ClosedRange<Double>
    public let frameCount: Int

    public init(range: ClosedRange<Double>) {
        self.range = range
        frameCount = Int((Self.seconds * Double(ReelPlan.framesPerSecond)).rounded())
    }

    /// Turn angle (radians) at `frame`. Frames past the end wrap, so the motion loops.
    public func yaw(at frame: Int) -> Double {
        let phase = Double(((frame % frameCount) + frameCount) % frameCount) / Double(frameCount)
        let swing = sin(2 * .pi * phase)
        // First half swings towards the upper limit, second half towards the lower one.
        return swing >= 0 ? range.upperBound * swing : range.lowerBound * -swing
    }
}
