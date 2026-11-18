import SwiftUI
import SkinalyzeKit

/// The signature moment after a scan: your photo → you lift out of it → a white die-cut edge grows → the sticker peels
/// up and floats (holo foil) while the analysis runs → your result's colour card slides in and the sticker slaps onto
/// it. Then the result opens. Reduce Motion: the same steps as cross-fades.
struct StickerMakingView: View {
    let photo: UIImage?
    /// nil while analysing; the result band once saved (drives the card colour and the "stick").
    let band: BreakoutBand?
    let onDone: () -> Void

    enum Phase: Int, Comparable {
        case photo, lifted, outlined, floating, stuck
        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .photo
    @State private var art: StickerArt?
    @State private var didFinish = false

    private var motion: Animation { MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.md)
            ZStack {
                card
                sticker
            }
            .aspectRatio(0.78, contentMode: .fit)
            .padding(.horizontal, Spacing.xl)
            Text(caption)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.smooth, value: caption)
                .accessibilityIdentifier("stickerCaption")
            Spacer(minLength: Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9).ignoresSafeArea())
        .task { await run() }
        .onChange(of: band) { _, _ in stickIfReady() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phase == .lifted)
        .sensoryFeedback(.impact(weight: .light), trigger: phase == .outlined)
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase == .stuck)
        .accessibilityElement(children: .combine)
    }

    // MARK: Layers

    /// The result's colour card; waits below until there is a result, then slides up behind the sticker.
    private var card: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(LinearGradient(colors: [Color.ds.band(band ?? .calm), Color.ds.band(band ?? .calm).opacity(0.55)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.ds.band(band ?? .calm).opacity(0.5), radius: 24, y: 14)
                .offset(y: phase == .stuck ? 0 : proxy.size.height * 1.4)
                .opacity(phase == .stuck ? 1 : 0)
        }
    }

    private var sticker: some View {
        let lifted = phase >= .lifted
        let outlined = phase >= .outlined
        let floating = phase == .floating
        let stuck = phase == .stuck
        return ZStack {
            if let photo = art?.photo ?? photo {
                Image(uiImage: photo).resizable().scaledToFit()
                    .opacity(lifted ? 0 : 1)
                    .blur(radius: lifted ? 18 : 0)
                    .scaleEffect(lifted && !reduceMotion ? 1.06 : 1)
            }
            if let art {
                StickerLayers(art: art, showsBacking: outlined, showsSubject: lifted, liftGlow: phase == .lifted)
                    .shadow(color: .black.opacity(floating ? 0.45 : 0.25), radius: floating ? 28 : 6, y: floating ? 26 : 4)
            }
        }
        .padding(stuck ? Spacing.lg : 0)
        .scaleEffect(floating && !reduceMotion ? 1.08 : 1)
        .rotation3DEffect(.degrees(floating && !reduceMotion ? 10 : 0), axis: (x: 1, y: -0.4, z: 0), perspective: 0.5)
        .rotationEffect(.degrees(stuck && !reduceMotion ? -3 : 0))
        .offset(y: floating && !reduceMotion ? -24 : 0)
        .phaseAnimator(floating && !reduceMotion ? [0.0, 1.0] : [0.0]) { content, bob in
            content.offset(y: -6 * bob)
        } animation: { _ in .easeInOut(duration: 1.1) }
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
        case .stuck: band.map { BandCopy.title($0) } ?? ""
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

    private func stickIfReady() {
        guard band != nil, phase == .floating || photo == nil, !didFinish else { return }
        didFinish = true
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.55, bounce: 0.3)) { phase = .stuck }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            onDone()
        }
    }
}
