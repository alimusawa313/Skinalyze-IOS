import SwiftUI
import SkinalyzeKit

// Pimpi's coach marks (ONBOARDING-PLAN.md §5.2): a soft spotlight on one thing, Pimpi pointing at it, one sentence and
// "Got it". Targets mark themselves with `.coachTarget(_:)`; the nearest `.coachHost()` (the app shell, or a sheet's
// root) draws the coach over them. Tap anywhere to dismiss. VoiceOver reads the sentence and offers "Got it".

/// Where each coach target sits, in the host's coordinate space.
struct CoachAnchorKey: PreferenceKey {
    static let defaultValue: [Coach: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Coach: Anchor<CGRect>], nextValue: () -> [Coach: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks the view a coach mark points at (one view can carry several).
    func coachTarget(_ coach: Coach) -> some View {
        transformAnchorPreference(key: CoachAnchorKey.self, value: .bounds) { $0[coach] = $1 }
    }

    /// The screen offers these coaches (the first one the rules allow) a moment after it appears.
    func offersCoach(_ coaches: [Coach]) -> some View {
        modifier(CoachOffer(coaches: coaches))
    }

    /// A coach for something further down a scrolling page: offered once it's on screen.
    func offersCoachWhenVisible(_ coach: Coach) -> some View {
        modifier(VisibleCoachOffer(coach: coach))
    }

    /// Draws the current coach mark over this view's coach targets. `showsFreeStanding`: also the coaches that point
    /// at nothing (only one host on screen should).
    func coachHost(showsFreeStanding: Bool = false) -> some View {
        modifier(CoachHost(showsFreeStanding: showsFreeStanding))
    }
}

private enum CoachTiming {
    /// Let the screen settle before Pimpi points at something.
    static let settle: Duration = .seconds(0.9)
}

private struct CoachOffer: ViewModifier {
    let coaches: [Coach]
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?

    func body(content: Content) -> some View {
        content
            .task {
                try? await Task.sleep(for: CoachTiming.settle)
                guard !Task.isCancelled else { return }
                tutorial?.offerFirst(coaches)
            }
            .onDisappear { coaches.forEach { tutorial?.withdraw($0) } }
    }
}

private struct VisibleCoachOffer: ViewModifier {
    let coach: Coach
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: 0.9) { isVisible = $0 }
            .task(id: isVisible) {
                guard isVisible else {
                    tutorial?.withdraw(coach)
                    return
                }
                try? await Task.sleep(for: CoachTiming.settle)
                guard !Task.isCancelled else { return }
                tutorial?.offerFirst([coach])
            }
    }
}

/// What each coach says (Pimpi's voice, effort only, never about skin).
enum CoachCopy {
    static func line(_ coach: Coach) -> LocalizedStringKey {
        switch coach {
        case .homePimpi: "Poke me any time. I've got tips."
        case .homeStreak: "Show up each day and this grows. Skin doesn't count, showing up does."
        case .homeToday: "Three small things a day: scan, routine, one lesson."
        case .shelf: "Ask me \u{201C}Is it good for me?\u{201D} about any product."
        case .productPage: "This is how well it fits what you told me. A guide, not a rule."
        case .deckCompare: "Two scans! Tap Compare to see them side by side."
        case .chest: "You earned a chest! Tap it to open."
        case .school: "Two-minute lessons. Finish one for points."
        case .journey: "Every point moves you along. All effort, never skin."
        case .routineBuilder: "Add your extras. I'll flag pairs that don't mix."
        case .resultIndex: "This is your starting point, not a grade."
        case .resultChapters: "Further down: what changed, what we noticed and what helps. Swipe between them."
        case .resultHead: "Tap a dot to see what it is, or drag the 3D head to turn it."
        case .resultDone: "That's it! Come back tomorrow and we'll compare."
        }
    }

    /// Coaches that don't point at anything: shown in the middle, no spotlight.
    static func isFreeStanding(_ coach: Coach) -> Bool { coach == .resultDone }
}

private struct CoachHost: ViewModifier {
    let showsFreeStanding: Bool

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            CoachLayer(anchors: anchors, showsFreeStanding: showsFreeStanding)
        }
    }
}

/// The current coach over its target (or in the middle, for one that points at nothing).
private struct CoachLayer: View {
    let anchors: [Coach: Anchor<CGRect>]
    let showsFreeStanding: Bool
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?

    var body: some View {
        GeometryReader { proxy in
            if let tutorial, let coach = tutorial.current, let target = target(for: coach, in: proxy) {
                let skip: (() -> Void)? = coach.isResultTour ? { tutorial.skipResultTour() } : nil
                CoachOverlay(coach: coach, target: target, bounds: proxy.size, dismiss: { tutorial.dismiss() }, skip: skip)
                    .id(coach)
                    .transition(.opacity)
            }
        }
    }

    private func target(for coach: Coach, in proxy: GeometryProxy) -> CGRect? {
        let middle = CGRect(x: proxy.size.width / 2, y: proxy.size.height * 0.42, width: 0, height: 0)
        if let anchor = anchors[coach] {
            // A target scrolled out of sight: say it in the middle instead of pointing off screen.
            let rect = proxy[anchor]
            return CGRect(origin: .zero, size: proxy.size).intersects(rect) ? rect : middle
        }
        guard showsFreeStanding, CoachCopy.isFreeStanding(coach) else { return nil }
        return middle
    }
}

/// The dimmed screen with a rounded hole over the target, and Pimpi's bubble above or below it.
private struct CoachOverlay: View {
    let coach: Coach
    let target: CGRect
    let bounds: CGSize
    let dismiss: () -> Void
    /// The result tour can be skipped as a whole.
    let skip: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private enum Metrics {
        static let holePadding: CGFloat = 8
        static let holeRadius: CGFloat = 22
        static let dim: Double = 0.55
        static let pimpi: CGFloat = 64
        static let bubbleWidth: CGFloat = 340
        static let gap: CGFloat = 14
    }

    var body: some View {
        let hole = target.isEmpty ? target : target.insetBy(dx: -Metrics.holePadding, dy: -Metrics.holePadding)
        let below = hole.midY < bounds.height / 2
        ZStack(alignment: .topLeading) {
            // Not `ignoresSafeArea`: that would shift the hole away from the target. The shape itself reaches far past
            // its frame, so the dim still covers the whole screen.
            Spotlight(hole: hole, radius: Metrics.holeRadius)
                .fill(Color.black.opacity(Metrics.dim), style: FillStyle(eoFill: true))
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)
            RoundedRectangle(cornerRadius: Metrics.holeRadius, style: .continuous)
                .strokeBorder(Color.ds.surface, lineWidth: hole.isEmpty ? 0 : 3)
                .frame(width: hole.width, height: hole.height)
                .offset(x: hole.minX, y: hole.minY)
                .scaleEffect(appeared || reduceMotion ? 1 : 1.08)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            bubble
                .frame(maxWidth: min(Metrics.bubbleWidth, bounds.width - Spacing.lg * 2))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.lg)
                .alignmentGuide(.top) { dimensions in
                    // Beside the target, but always fully on screen.
                    let wanted = below ? hole.maxY + Metrics.gap : hole.minY - Metrics.gap - dimensions.height
                    return -min(max(wanted, Spacing.lg), bounds.height - dimensions.height - Spacing.lg)
                }
                .scaleEffect(appeared || reduceMotion ? 1 : 0.85, anchor: below ? .top : .bottom)
                .opacity(appeared ? 1 : 0)
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .onAppear {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { appeared = true }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var bubble: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Pimpi(mood: .happy)
                .environment(\.pimpiPose, .point)
                .frame(width: Metrics.pimpi, height: Metrics.pimpi)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(CoachCopy.line(coach))
                    .font(.ds.pimpiSmall)
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.sm) {
                    Button(coach.nextInTour == nil ? "Got it" : "Next", action: dismiss)
                        .buttonStyle(.chunky(.filled, fullWidth: false))
                        .accessibilityIdentifier("coachGotIt")
                    if let skip, coach.nextInTour != nil {
                        Button("Skip tour", action: skip)
                            .buttonStyle(PlaceTextButtonStyle())
                            .accessibilityIdentifier("coachSkipTour")
                    }
                }
            }
        }
        .padding(Spacing.md)
        .dsSurface(radius: Radius.medium)
    }
}

/// A full-screen rectangle with a rounded hole (filled even-odd).
private struct Spotlight: Shape {
    let hole: CGRect
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -2000, dy: -2000))
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

/// Profile: Pimpi's tips on or off, and the whole tour again.
struct TipsSettingsRows: View {
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?
    @State private var replayed = false

    var body: some View {
        if let tutorial {
            Toggle(isOn: Binding(get: { !tutorial.tipsOff }, set: { tutorial.setTipsOff(!$0) })) {
                Text("Pimpi's tips").font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
            }
            .tint(Color.ds.positive)
            .placeSurfaceRow()
            .sensoryFeedback(Haptic.toggle, trigger: tutorial.tipsOff)
            .accessibilityIdentifier("tipsToggle")
            Button {
                tutorial.replayTour()
                replayed = true
            } label: {
                Label(replayed ? "Tour starts again as you go" : "Replay the tour",
                      systemImage: replayed ? "checkmark" : "arrow.counterclockwise")
            }
            .labelStyle(PlaceLinkLabelStyle())
            .buttonStyle(ChunkyRowStyle())
            .disabled(replayed)
            .accessibilityIdentifier("replayTour")
        }
    }
}
