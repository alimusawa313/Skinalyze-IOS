import SwiftUI
import SkinalyzeKit

// The little things Pimpi holds during onboarding, in the same no-outline vector style as Pimpi: a path it walks
// along (progress), a name tag, a backpack the goals go into, a promise box, the plan card. Decorative pieces are
// hidden from VoiceOver; the scene's own text and buttons carry the meaning.

/// Progress as Pimpi's head walking along a dotted path.
struct PimpiPathProgress: View {
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let height: CGFloat = 26
        static let track: CGFloat = 6
        static let walker: CGFloat = 26
        static let dots = 10
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - Metrics.walker
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<Metrics.dots, id: \.self) { index in
                        Circle()
                            .fill(Double(index) / Double(Metrics.dots - 1) <= progress ? Color.ds.ink : Color.ds.edge)
                            .frame(width: Metrics.track, height: Metrics.track)
                        if index < Metrics.dots - 1 { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, Metrics.walker / 2)
                Pimpi(mood: .happy)
                    .frame(width: Metrics.walker, height: Metrics.walker)
                    .offset(x: width * progress)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Metrics.height)
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

/// The tag Pimpi holds up on "Hello": blank, then your name in Pimpi's handwriting.
struct NameTag: View {
    let name: String

    /// The tag grows with the text size, so its words never have to shrink.
    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 118
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 64
    @ScaledMetric(relativeTo: .caption2) private var band: CGFloat = 18

    private enum Metrics {
        static let tilt: Double = -6
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("HELLO")
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.surface)
                .frame(maxWidth: .infinity, minHeight: band)
                .background(Color.ds.signal)
            Text(name.isEmpty ? " " : name)
                .font(.ds.pimpiSmall)
                .foregroundStyle(Color.ds.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, Spacing.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentTransition(.interpolate)
        }
        .frame(width: width, height: height)
        .background(Color.ds.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.ds.edge).offset(y: Chunk.depthSmall))
        .rotationEffect(.degrees(Metrics.tilt))
        .accessibilityHidden(true)
    }
}

/// Pimpi's backpack: each picked goal pops in and peeks out of the top; the bag squashes as it lands.
struct GoalBackpack: View {
    let goals: [UserProfile.Goal]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let width: CGFloat = 88
        static let height: CGFloat = 96
        static let icon: CGFloat = 30
    }

    var body: some View {
        ZStack(alignment: .top) {
            // What's packed, peeking out of the top.
            HStack(spacing: -8) {
                ForEach(goals) { goal in
                    Image(systemName: goal.systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ds.ink)
                        .frame(width: Metrics.icon, height: Metrics.icon)
                        .background(Circle().fill(Color.ds.surface))
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .scale(scale: 0.3)))
                }
            }
            .offset(y: -Metrics.icon * 0.45)
            .zIndex(0)
            bag.zIndex(1)
        }
        .frame(width: Metrics.width, height: Metrics.height, alignment: .bottom)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: goals.count) { content, squash in
            content.scaleEffect(x: reduceMotion ? 1 : 2 - squash, y: reduceMotion ? 1 : squash, anchor: .bottom)
        } keyframes: { _ in
            SpringKeyframe(0.86, duration: 0.1, spring: .snappy)
            SpringKeyframe(1, duration: 0.4, spring: .bouncy(extraBounce: 0.25))
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: goals)
        .accessibilityHidden(true)
    }

    /// A backpack, not a block: a carry handle, a rounded body, a top flap with a buckle, and a front pocket.
    private var bag: some View {
        let body = Color.ds.positive
        let dark = body.mix(with: .black, by: 0.22)
        return ZStack(alignment: .top) {
            Capsule()
                .stroke(dark, lineWidth: 5)
                .frame(width: Metrics.width * 0.34, height: Metrics.height * 0.2)
                .offset(y: Metrics.height * 0.1)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(body)
                UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 14, bottomTrailingRadius: 14,
                                       topTrailingRadius: 26, style: .continuous)
                    .fill(dark)
                    .frame(height: Metrics.height * 0.3)
                Capsule()
                    .fill(Color.ds.caution)
                    .frame(width: Metrics.width * 0.18, height: Metrics.height * 0.1)
                    .offset(y: Metrics.height * 0.24)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(body.mix(with: .white, by: 0.25))
                    .frame(width: Metrics.width * 0.6, height: Metrics.height * 0.22)
                    .offset(y: Metrics.height * 0.46)
            }
            .frame(width: Metrics.width, height: Metrics.height * 0.8)
            .offset(y: Metrics.height * 0.2)
        }
        .frame(width: Metrics.width, height: Metrics.height, alignment: .top)
    }
}

/// A little box with a lid and a lock: open until the promise is sealed, then shut with a click.
struct PromiseBox: View {
    let isSealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let width: CGFloat = 92
        static let height: CGFloat = 70
        static let lidOpen: Double = -38
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ds.ink)
                .frame(width: Metrics.width, height: Metrics.height * 0.72)
            // The lid hinges on its leading edge.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.ds.ink.mix(with: .white, by: 0.15))
                .frame(width: Metrics.width + 8, height: Metrics.height * 0.24)
                .rotationEffect(.degrees(isSealed ? 0 : Metrics.lidOpen), anchor: .bottomLeading)
                .offset(y: -Metrics.height * 0.72)
            Image(systemName: isSealed ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color.ds.caution)
                .contentTransition(.symbolEffect(.replace))
                .offset(y: -Metrics.height * 0.2)
        }
        .frame(width: Metrics.width + 8, height: Metrics.height + 16, alignment: .bottom)
        .animation(reduceMotion ? .default : .spring(duration: 0.35, bounce: 0.45), value: isSealed)
        .accessibilityHidden(true)
    }
}

/// Press and hold to seal the promise: a ring fills and the haptic grows; letting go early starts over. A plain tap
/// (and VoiceOver's action) seals it for anyone who can't hold.
struct HoldToSeal: View {
    @Binding var isSealed: Bool
    var tapSeals: Bool

    @State private var progress: Double = 0
    @State private var holding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let size: CGFloat = 112
        static let ring: CGFloat = 8
        static let holdSeconds: Double = 1.2
    }

    var body: some View {
        ZStack {
            Circle().fill(isSealed ? Color.ds.positive : Color.ds.surface)
            Circle().stroke(Color.ds.edge, lineWidth: Metrics.ring)
            Circle()
                .trim(from: 0, to: isSealed ? 1 : progress)
                .stroke(Color.ds.positive, style: StrokeStyle(lineWidth: Metrics.ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: isSealed ? "checkmark" : "hand.point.up.left.fill")
                    .font(.title2.weight(.heavy))
                    .contentTransition(.symbolEffect(.replace))
                Text(isSealed ? "Sealed" : "Hold")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
            }
            .foregroundStyle(isSealed ? Color.ds.surface : Color.ds.ink)
        }
        .frame(width: Metrics.size, height: Metrics.size)
        .scaleEffect(holding && !reduceMotion ? 0.94 : 1)
        .animation(.easeOut(duration: 0.15), value: holding)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: tapSeals ? 0 : Metrics.holdSeconds, maximumDistance: 40) {
            seal()
        } onPressingChanged: { pressing in
            guard !isSealed else { return }
            holding = pressing
            if tapSeals { return }
            if pressing {
                withAnimation(.linear(duration: Metrics.holdSeconds)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: holding) { _, new in new }
        .sensoryFeedback(.success, trigger: isSealed) { _, new in new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isSealed ? "Promise sealed" : "Seal the promise"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { seal() }
        .accessibilityIdentifier("holdToSeal")
    }

    private func seal() {
        guard !isSealed else { return }
        holding = false
        withDSAnimation(.bouncy, reduceMotion: reduceMotion) {
            progress = 1
            isSealed = true
        }
    }
}

/// The starter plan, slapped onto the hill like the scan sticker: your focus, two ingredients to look for, and the
/// first-week path with today's step lit.
struct StarterPlanCard: View {
    let plan: StarterPlan
    let skinType: SkinType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    private enum Metrics {
        static let tilt: Double = -2
        static let dropScale: CGFloat = 1.25
        static let dot: CGFloat = 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your starter plan")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color.ds.signal)
            Text(PlanCopy.focus(plan.focus))
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Look for (good for \(skinType.title.lowercased()) skin)")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
                ForEach(plan.lookFor) { note in
                    Label(note.name, systemImage: "checkmark.circle.fill")
                        .font(.system(.callout, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                }
            }
            if plan.patchTestFirst {
                Label("Patch-test new products first. I'll remind you how.", systemImage: "bandage.fill")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Your first week")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(plan.firstWeek.enumerated()), id: \.element) { index, _ in
                        Circle()
                            .fill(index == 0 ? Color.ds.signal : Color.ds.edge)
                            .frame(width: Metrics.dot, height: Metrics.dot)
                    }
                }
                .accessibilityHidden(true)
                Text("Today: your first scan.")
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(radius: Radius.medium)
        .rotationEffect(.degrees(landed ? Metrics.tilt : 0))
        .scaleEffect(landed || reduceMotion ? 1 : Metrics.dropScale)
        .opacity(landed ? 1 : 0)
        .onAppear {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { landed = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: landed)
        .accessibilityElement(children: .combine)
    }
}

/// What each focus reads as on the plan card.
enum PlanCopy {
    static func focus(_ goal: UserProfile.Goal) -> LocalizedStringKey {
        switch goal {
        case .fewerBreakouts: "Focus: fewer breakouts, one small habit at a time"
        case .fadeMarks: "Focus: helping dark marks fade (sunscreen is your best friend)"
        case .understand: "Focus: getting to know your skin, scan by scan"
        case .checkProducts: "Focus: knowing what's in your products"
        case .buildRoutine: "Focus: a simple routine you'll actually keep"
        }
    }
}
