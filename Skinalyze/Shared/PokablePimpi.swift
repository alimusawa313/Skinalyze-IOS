import SwiftUI
import SkinalyzeKit

/// Pimpi big enough to poke — the one version every screen uses, so it feels the same everywhere.
///
/// - A poke squashes and stretches it, makes it hop, and gives a light tap. Without `onPoke` it also tries another
///   mood; with `onPoke` the screen decides what a poke changes (a line, a mood) and passes the new `mood` back in.
/// - It hops whenever `cheer` changes, so a screen can make it react to what the user just did (a quest, an answer,
///   a tag, an unlock). It reacts to effort only — never to how skin looks.
/// - Under Reduce Motion it stays still; the mood still changes.
struct PokablePimpi<Cheer: Equatable>: View {
    let mood: MascotMood
    let size: CGFloat
    let cheer: Cheer
    let onPoke: (() -> Void)?

    @State private var pokes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: MascotMood = .happy, size: CGFloat, cheer: Cheer, onPoke: (() -> Void)? = nil) {
        self.mood = mood
        self.size = size
        self.cheer = cheer
        self.onPoke = onPoke
    }

    private struct Frame {
        var x: CGFloat = 1
        var y: CGFloat = 1
        var lift: CGFloat = 0
    }

    /// Changes on every poke and every cheer — both play the same hop.
    private struct Beat: Equatable {
        let pokes: Int
        let cheer: Cheer
    }

    private var shownMood: MascotMood {
        guard onPoke == nil, pokes > 0 else { return mood }
        return PokeMetrics.pokeMoods[(pokes - 1) % PokeMetrics.pokeMoods.count]
    }

    var body: some View {
        Button {
            pokes += 1
            onPoke?()
        } label: {
            Pimpi(mood: shownMood)
                .frame(width: size, height: size)
                .keyframeAnimator(initialValue: Frame(), trigger: Beat(pokes: pokes, cheer: cheer)) { content, frame in
                    content
                        .scaleEffect(x: reduceMotion ? 1 : frame.x, y: reduceMotion ? 1 : frame.y, anchor: .bottom)
                        .offset(y: reduceMotion ? 0 : -frame.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.x) {
                        SpringKeyframe(PokeMetrics.squashWide, duration: PokeMetrics.squashTime, spring: .snappy)
                        SpringKeyframe(PokeMetrics.stretchNarrow, duration: PokeMetrics.stretchTime, spring: .snappy)
                        SpringKeyframe(1, duration: PokeMetrics.landTime, spring: .bouncy(extraBounce: 0.2))
                    }
                    KeyframeTrack(\.y) {
                        SpringKeyframe(PokeMetrics.squashLow, duration: PokeMetrics.squashTime, spring: .snappy)
                        SpringKeyframe(PokeMetrics.stretchTall, duration: PokeMetrics.stretchTime, spring: .snappy)
                        SpringKeyframe(1, duration: PokeMetrics.landTime, spring: .bouncy(extraBounce: 0.2))
                    }
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(0, duration: PokeMetrics.squashTime)
                        SpringKeyframe(size * PokeMetrics.hop, duration: PokeMetrics.stretchTime, spring: .snappy)
                        SpringKeyframe(0, duration: PokeMetrics.landTime, spring: .bouncy(extraBounce: 0.25))
                    }
                }
        }
        .buttonStyle(.bouncy(PokeMetrics.pressScale))
        .sensoryFeedback(Haptic.toggle, trigger: pokes)
        .onChange(of: mood) { pokes = 0 } // a new reaction from the screen wins over a poke
        .accessibilityLabel(Text("Pimpi"))
        .accessibilityHint(Text("Says something else"))
    }
}

extension PokablePimpi where Cheer == Int {
    /// Pimpi that reacts to pokes only.
    init(mood: MascotMood = .happy, size: CGFloat, onPoke: (() -> Void)? = nil) {
        self.init(mood: mood, size: size, cheer: 0, onPoke: onPoke)
    }
}

/// Sizes and timings for `PokablePimpi` (at file scope: a generic type can't hold static stored properties).
private enum PokeMetrics {
    static let pokeMoods: [MascotMood] = [.excited, .curious, .happy, .sleepy]
    static let pressScale: CGFloat = 0.9
    static let squashWide: CGFloat = 1.14
    static let squashLow: CGFloat = 0.84
    static let stretchNarrow: CGFloat = 0.94
    static let stretchTall: CGFloat = 1.08
    /// How high it hops, as a share of its size.
    static let hop: CGFloat = 0.16
    static let squashTime: Double = 0.12
    static let stretchTime: Double = 0.18
    static let landTime: Double = 0.42
}
