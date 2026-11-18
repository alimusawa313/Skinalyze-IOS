import SwiftUI

/// Motion tokens (PLAN.md §7.2). Springs only; every token has a Reduce Motion fallback.
public enum MotionToken: CaseIterable, Sendable, Hashable {
    case snappy
    case smooth
    case expressive
    case gentle
    case reduced

    public var animation: Animation {
        switch self {
        case .snappy: .spring(duration: 0.28, bounce: 0.12)
        case .smooth: .spring(duration: 0.45, bounce: 0)
        case .expressive: .spring(duration: 0.6, bounce: 0.3)
        case .gentle: .spring(duration: 0.9, bounce: 0)
        case .reduced: .easeInOut(duration: 0.2)
        }
    }

    public func resolved(reduceMotion: Bool) -> MotionToken {
        reduceMotion ? .reduced : self
    }

    /// Delay for the n-th item of a staggered reveal (capped so long lists don't drag).
    public static func stagger(_ index: Int) -> Double {
        Double(min(index, 10)) * 0.035
    }
}

public extension View {
    /// Animates `value` changes with a motion token, honouring Reduce Motion automatically.
    func dsAnimation<V: Equatable>(_ token: MotionToken, value: V) -> some View {
        modifier(DSAnimationModifier(token: token, value: value))
    }
}

private struct DSAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let token: MotionToken
    let value: V

    func body(content: Content) -> some View {
        content.animation(token.resolved(reduceMotion: reduceMotion).animation, value: value)
    }
}

/// Runs `body` in a motion-token transaction that respects Reduce Motion.
@MainActor
public func withDSAnimation<Result>(_ token: MotionToken, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(token.resolved(reduceMotion: reduceMotion).animation, body)
}

/// Haptic vocabulary (PLAN.md §7.3). Use with `.sensoryFeedback(_:trigger:)`; never from a repeating timer.
public enum Haptic {
    public static let scrub = SensoryFeedback.selection
    public static let toggle = SensoryFeedback.impact(weight: .light)
    public static let gatePassed = SensoryFeedback.impact(flexibility: .soft, intensity: 0.5)
    public static let gateLost = SensoryFeedback.warning
    public static let capture = SensoryFeedback.impact(weight: .medium)
    public static let success = SensoryFeedback.success
    public static let failure = SensoryFeedback.error
}
