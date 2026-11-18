import SwiftUI

// MARK: - Buttons

/// The one filled, accent-coloured button style. Press: slight scale + darken; honours Reduce Motion.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.lg)
            .background(Capsule().fill(isEnabled ? Color.ds.signal : Color.ds.inkTertiary))
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.ds.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Spacing.lg)
            .background(Capsule().strokeBorder(Color.ds.hairline, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var dsPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var dsSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Surfaces

public extension View {
    /// Quiet card: surface fill, hairline border, no drop shadow (PLAN.md §6.7).
    func dsCard(padding: CGFloat = Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).strokeBorder(Color.ds.hairline))
    }

    /// App background.
    func dsCanvas() -> some View {
        background(Color.ds.canvas.ignoresSafeArea())
    }
}

// MARK: - Chips

/// Multi-select filter chip. The selected fill slides between chips via a shared namespace.
public struct Chip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                if let systemImage { Image(systemName: systemImage).imageScale(.small) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.ds.signal : Color.ds.inkSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(isSelected ? Color.ds.signalSoft : Color.clear))
            .overlay(Capsule().strokeBorder(isSelected ? Color.ds.signal.opacity(0.4) : Color.ds.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(Haptic.toggle, trigger: isSelected)
    }
}

// MARK: - Data display

/// ▲/▼ change badge. Uses glyph + colour + text, never colour alone. Lower is better for breakouts.
public struct DeltaBadge: View {
    let delta: Int
    let lowerIsBetter: Bool

    public init(delta: Int, lowerIsBetter: Bool = true) {
        self.delta = delta
        self.lowerIsBetter = lowerIsBetter
    }

    private var isImprovement: Bool { lowerIsBetter ? delta < 0 : delta > 0 }

    public var body: some View {
        let symbol = delta == 0 ? "equal" : (delta < 0 ? "arrow.down" : "arrow.up")
        let tint: Color = delta == 0 ? .ds.inkSecondary : (isImprovement ? .ds.positive : .ds.caution)
        Label {
            Text(delta == 0 ? "Same" : "\(abs(delta))").monospacedDigit()
        } icon: {
            Image(systemName: symbol)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Capsule().fill(tint.opacity(0.12)))
        .contentTransition(.numericText(value: Double(delta)))
        .accessibilityLabel(delta == 0 ? Text("No change") : Text("\(abs(delta)) \(delta < 0 ? "fewer" : "more")"))
    }
}

/// Band pill: colour swatch + word (never colour alone).
public struct BandPill: View {
    let band: BreakoutBand

    public init(_ band: BreakoutBand) {
        self.band = band
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(Color.ds.band(band)).frame(width: 8, height: 8)
            Text(BandCopy.title(band))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.ds.ink)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Capsule().fill(Color.ds.band(band).opacity(0.22)))
        .accessibilityElement(children: .combine)
    }
}

/// Plain-language, non-diagnostic band names (PLAN.md §15.1).
public enum BandCopy {
    public static func title(_ band: BreakoutBand) -> String {
        switch band {
        case .calm: String(localized: "Calm")
        case .mild: String(localized: "Mild")
        case .active: String(localized: "Active")
        case .flared: String(localized: "Flared")
        }
    }

    public static func summary(_ band: BreakoutBand) -> String {
        switch band {
        case .calm: String(localized: "Your skin looks calm — nothing active stood out.")
        case .mild: String(localized: "A few spots are active. Small changes add up — keep tracking.")
        case .active: String(localized: "Several spots are active. Watch how this zone changes over the next scans.")
        case .flared: String(localized: "A lot is active right now. If it's painful or persistent, a dermatologist can help.")
        }
    }
}

/// Lesion-type glyphs + plain names (until custom SF Symbols ship in Phase 7).
public enum LesionGlyph {
    public static func symbolName(for type: LesionType) -> String {
        switch type {
        case .blackhead: "circle.fill"
        case .whitehead: "circle"
        case .papule: "circle.circle"
        case .pustule: "smallcircle.filled.circle"
        case .nodule: "circle.circle.fill"
        case .darkSpot: "circle.lefthalf.filled"
        }
    }

    public static func displayName(for type: LesionType) -> String {
        switch type {
        case .blackhead: String(localized: "Blackheads")
        case .whitehead: String(localized: "Whiteheads")
        case .papule: String(localized: "Papules")
        case .pustule: String(localized: "Pustules")
        case .nodule: String(localized: "Nodules")
        case .darkSpot: String(localized: "Dark spots")
        }
    }

    public static func explanation(for type: LesionType) -> String {
        switch type {
        case .blackhead: String(localized: "Open pores filled with oil and dead skin; the dark colour is oxidation, not dirt.")
        case .whitehead: String(localized: "Closed, clogged pores that sit just under the surface.")
        case .papule: String(localized: "Small, firm, red bumps without a visible white tip.")
        case .pustule: String(localized: "Raised spots with a white or yellow centre, often with redness around them.")
        case .nodule: String(localized: "Larger, deeper, firm bumps under the skin. If they hurt or linger, consider seeing a dermatologist.")
        case .darkSpot: String(localized: "Marks left behind after spots heal or from sun exposure. They fade over time.")
        }
    }
}

// MARK: - Capture ring

/// Segmented ring around the face guide: one segment per quality gate, plus an inner hold-progress arc.
public struct CaptureRing: View {
    let segments: [Bool]
    let holdProgress: Double

    public init(segments: [Bool], holdProgress: Double) {
        self.segments = segments
        self.holdProgress = holdProgress
    }

    public var body: some View {
        let count = max(segments.count, 1)
        let gap = 0.012
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, passed in
                let start = Double(index) / Double(count) + gap
                let end = Double(index + 1) / Double(count) - gap
                Circle()
                    .trim(from: start, to: end)
                    .stroke(passed ? Color.ds.signal : Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .dsAnimation(.snappy, value: passed)
            }
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(10)
                .dsAnimation(.smooth, value: holdProgress)
        }
        .rotationEffect(.degrees(-90))
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state & motif

public struct EmptyStateView<Action: View>: View {
    let title: String
    let message: String
    let action: Action

    public init(title: String, message: String, @ViewBuilder action: () -> Action) {
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            ContourMotif()
                .stroke(Color.ds.hairline, lineWidth: 1)
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text(title).font(.ds.title).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
            Text(message).font(.ds.body).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
            action
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
    }
}

/// Signature motif: nested, gently irregular contour rings (topographic). `phase` drifts them for ambient motion.
public struct ContourMotif: Shape {
    public var phase: Double
    public var rings: Int

    public init(phase: Double = 0, rings: Int = 7) {
        self.phase = phase
        self.rings = rings
    }

    public var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let steps = 96
        for ring in 1...max(rings, 1) {
            let base = maxRadius * Double(ring) / Double(rings)
            for step in 0...steps {
                let theta = Double(step) / Double(steps) * 2 * .pi
                let wobble = 1
                    + 0.06 * sin(3 * theta + phase + Double(ring))
                    + 0.04 * sin(5 * theta - phase * 0.7 + Double(ring) * 1.7)
                let point = CGPoint(
                    x: center.x + cos(theta) * base * wobble,
                    y: center.y + sin(theta) * base * wobble * 1.15
                )
                step == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
        return path
    }
}
