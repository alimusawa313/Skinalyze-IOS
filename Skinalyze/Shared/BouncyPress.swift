import SwiftUI
import SkinalyzeKit

/// Squishes on touch-down and springs back with an overshoot — the V2 press feel for every big tappable object.
struct BouncyPress: ButtonStyle {
    var pressedScale: CGFloat = 0.92
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension ButtonStyle where Self == BouncyPress {
    static var bouncy: BouncyPress { BouncyPress() }
    static func bouncy(_ scale: CGFloat) -> BouncyPress { BouncyPress(pressedScale: scale) }
}

/// Pops in from small with an overshoot the first time it appears (fades under Reduce Motion).
struct PopIn: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
}
