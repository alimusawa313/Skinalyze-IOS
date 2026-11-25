import SwiftUI
import SkinalyzeKit

/// The signature moment after a scan: your photo → you lift out of it → a white die-cut edge grows → the sticker peels
/// up and floats (holo foil) while the analysis runs → your result's colour card slides in and the sticker slaps onto
/// it. Then the result opens. Reduce Motion: the same steps as cross-fades. The moment stays dark by design (the dusk
/// palette, in the day palette too).
struct StickerMakingView: View {
    let photo: UIImage?
    /// nil while analysing; the result band once saved (drives the card colour and the "stick").
    let band: BreakoutBand?
    let onDone: () -> Void

    enum Phase: Int, Comparable {
        case photo, lifted, outlined, floating, stuck, filed
        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .photo
    @State private var art: StickerArt?
    @State private var didFinish = false
    /// Live copy of `band`. The sequence runs in a long-lived task whose captured `self` never sees later `band`
    /// values — reading this @State instead is what lets a fast analysis (done before the float) still stick.
    @State private var resultBand: BreakoutBand?

    private var motion: Animation { MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation }

    private enum Metrics {
        static let cardRatio: CGFloat = 0.78
        /// How small the finished card gets as it drops into the Deck.
        static let filedScale: CGFloat = 0.08
        /// Where the card waits below the sticker before there is a result, in card heights.
        static let cardWaitOffset: CGFloat = 1.4
        static let liftBlur: CGFloat = 18
        static let liftScale: CGFloat = 1.06
        static let floatScale: CGFloat = 1.08
        static let floatTilt: Double = 10
        static let floatLift: CGFloat = -24
        static let bob: CGFloat = -6
        static let bobSeconds = 1.1
        static let stuckTilt: Double = -3
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.md)
            ZStack {
                card
                sticker
            }
            .aspectRatio(Metrics.cardRatio, contentMode: .fit)
            .padding(.horizontal, Spacing.xl)
            // Filed: the finished card drops into the Deck (the middle of the dock) before the result opens.
            .scaleEffect(phase == .filed ? Metrics.filedScale : 1, anchor: .bottom)
            .offset(y: phase == .filed ? Self.fileDrop : 0)
            .opacity(phase == .filed ? 0 : 1)
            Text(caption)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.smooth, value: caption)
                .accessibilityIdentifier("stickerCaption")
            Spacer(minLength: Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .task { await run() }
        .onChange(of: band, initial: true) { _, newBand in
            resultBand = newBand
            stickIfReady()
        }
        .task(id: resultBand) {
            // Safety net: once there is a result, never keep the user waiting on the animation.
            guard resultBand != nil else { return }
            try? await Task.sleep(for: .seconds(Self.maxWaitAfterResult))
            stick(force: true)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phase == .lifted)
        .sensoryFeedback(.impact(weight: .light), trigger: phase == .outlined)
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase >= .stuck)
        .accessibilityElement(children: .combine)
    }

    // MARK: Layers

    /// The result's colour card with its hard bottom edge; waits below until there is a result, then slides up
    /// behind the sticker.
    private var card: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
            shape
                .fill(Color.ds.band(resultBand ?? .calm))
                .background(shape.fill(Color.ds.edge).offset(y: Chunk.depth))
                .offset(y: phase >= .stuck ? 0 : proxy.size.height * Metrics.cardWaitOffset)
                .opacity(phase >= .stuck ? 1 : 0)
        }
    }

    private var sticker: some View {
        let lifted = phase >= .lifted
        let outlined = phase >= .outlined
        let floating = phase == .floating
        let stuck = phase >= .stuck
        return ZStack {
            if let photo = art?.photo ?? photo {
                Image(uiImage: photo).resizable().scaledToFit()
                    .opacity(lifted ? 0 : 1)
                    .blur(radius: lifted ? Metrics.liftBlur : 0)
                    .scaleEffect(lifted && !reduceMotion ? Metrics.liftScale : 1)
            }
            if let art {
                StickerLayers(art: art, showsBacking: outlined, showsSubject: lifted, liftGlow: phase == .lifted)
            }
        }
        .padding(stuck ? Spacing.lg : 0)
        .scaleEffect(floating && !reduceMotion ? Metrics.floatScale : 1)
        .rotation3DEffect(.degrees(floating && !reduceMotion ? Metrics.floatTilt : 0), axis: (x: 1, y: -0.4, z: 0), perspective: 0.5)
        .rotationEffect(.degrees(stuck && !reduceMotion ? Metrics.stuckTilt : 0))
        .offset(y: floating && !reduceMotion ? Metrics.floatLift : 0)
        .phaseAnimator(floating && !reduceMotion ? [0.0, 1.0] : [0.0]) { content, bob in
            content.offset(y: Metrics.bob * bob)
        } animation: { _ in .easeInOut(duration: Metrics.bobSeconds) }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: stuck) { content, squash in
            content.scaleEffect(x: 2 - squash, y: squash) // slap: flatten, then settle
        } keyframes: { _ in
            if stuck && !reduceMotion {
                CubicKeyframe(1, duration: 0.18)
                SpringKeyframe(0.9, duration: 0.08, spring: .snappy)
                SpringKeyframe(1, duration: 0.5, spring: .bouncy(extraBounce: 0.25))
            } else {
                LinearKeyframe(1, duration: 0.01)
            }
        }
    }

    private var caption: String {
        switch phase {
        case .photo, .lifted: String(localized: "Lifting you out…")
        case .outlined, .floating: String(localized: "Reading your skin…")
        case .stuck, .filed: resultBand.map { BandCopy.title($0) } ?? ""
        }
    }

    // MARK: Sequence

    private func run() async {
        guard let photo else { return }
        art = await PortraitCutout.shared.liftArt(from: photo)?.full
        try? await Task.sleep(for: .seconds(0.35))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.7, bounce: 0.2)) { phase = .lifted }
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(motion) { phase = .outlined }
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.8, bounce: 0.35)) { phase = .floating }
        try? await Task.sleep(for: .seconds(0.5))
        stickIfReady()
    }

    private static let maxWaitAfterResult: Double = 4
    /// How far the finished card drops toward the dock when it is filed into the Deck.
    private static let fileDrop: CGFloat = 220

    private func stickIfReady() {
        guard phase == .floating || photo == nil else { return }
        stick(force: false)
    }

    private func stick(force: Bool) {
        guard resultBand != nil, !didFinish else { return }
        if force, art == nil { phase = .floating } // cut-out never arrived: stick the photo itself
        didFinish = true
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.55, bounce: 0.3)) { phase = .stuck }
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.5, bounce: 0.15)) { phase = .filed }
            try? await Task.sleep(for: .seconds(0.5))
            onDone()
        }
    }
}
