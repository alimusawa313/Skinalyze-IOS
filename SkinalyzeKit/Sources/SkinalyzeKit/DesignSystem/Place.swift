import SwiftUI

// "Pimpi's Place" building blocks: the hill, pressable surfaces with a hard bottom edge, Pimpi's speech bubble and
// the pill picker. Screens compose these; none of them hard-codes a colour or a size outside the tokens.

// MARK: - Ground

/// What a surface sits on. It decides the colour of its pressed-in bottom edge.
public enum DSGround: Sendable {
    case sky
    case hill

    var edge: Color {
        switch self {
        case .sky: Color.ds.edge
        case .hill: Color.ds.edgeOnHill
        }
    }
}

public extension EnvironmentValues {
    /// Set to `.hill` on content laid over the hill, so surfaces there get the hill's edge colour.
    @Entry var dsGround: DSGround = .sky
}

/// How far a pressable thing stands proud of the ground, and how far it sinks when pressed.
public enum Chunk {
    public static let depth: CGFloat = 5
    public static let depthSmall: CGFloat = 4
    /// Smallest comfortable control height.
    public static let controlHeight: CGFloat = 52
    public static let iconButton: CGFloat = 44
}

// MARK: - Hill

/// A soft hill: flat sides rising to a rounded crest. `crest` is where the top sits, as a fraction of the height.
public struct HillShape: Shape {
    public var crest: CGFloat
    public var rise: CGFloat

    public init(crest: CGFloat, rise: CGFloat = 44) {
        self.crest = crest
        self.rise = rise
    }

    public var animatableData: CGFloat {
        get { crest }
        set { crest = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let top = rect.minY + rect.height * crest
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top + rise))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + rise), control: CGPoint(x: rect.midX, y: top - rise))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The place itself: sky, a far hill and the hill content stands on. Decorative.
public struct HillBackdrop: View {
    let crest: CGFloat
    let rise: CGFloat
    let showsFarHill: Bool

    public init(crest: CGFloat = 0.5, rise: CGFloat = 44, showsFarHill: Bool = false) {
        self.crest = crest
        self.rise = rise
        self.showsFarHill = showsFarHill
    }

    public var body: some View {
        ZStack {
            Color.ds.canvas
            if showsFarHill {
                HillShape(crest: crest - 0.045, rise: rise * 1.5)
                    .fill(Color.ds.hillFar)
                    .scaleEffect(x: 1.25, anchor: .leading)
            }
            HillShape(crest: crest, rise: rise).fill(Color.ds.hill)
        }
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Sky with a hill behind the content. `crest` is the fraction of the screen height where the hill begins.
    func dsHill(crest: CGFloat = 0.5, rise: CGFloat = 44, showsFarHill: Bool = false) -> some View {
        background(HillBackdrop(crest: crest, rise: rise, showsFarHill: showsFarHill).ignoresSafeArea())
    }

    /// Marks this content as sitting on the hill.
    func onHill() -> some View {
        environment(\.dsGround, .hill)
    }
}

// MARK: - Pressable surfaces

/// A capsule button that stands proud of the ground and sinks when pressed. `filled` is the one primary action.
public struct ChunkyButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        case filled
        case plain
    }

    let kind: Kind
    let fullWidth: Bool
    let minHeight: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    public init(_ kind: Kind = .filled, fullWidth: Bool = true, minHeight: CGFloat = Chunk.controlHeight) {
        self.kind = kind
        self.fullWidth = fullWidth
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(kind == .filled ? Color.ds.canvas : Color.ds.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minHeight)
            .background(Capsule().fill(kind == .filled ? Color.ds.ink : Color.ds.surface))
            .offset(y: pressed ? Chunk.depth : 0)
            .background(Capsule().fill(kind == .filled ? Color.ds.inkEdge : ground.edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(Capsule())
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

/// A round button with the same pressed-in edge. Give it `fill` and `edge` for the one coloured action (scan).
public struct ChunkyIconButtonStyle: ButtonStyle {
    let filled: Bool
    let fill: Color?
    let edge: Color?
    let depth: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    public init(filled: Bool = false, fill: Color? = nil, edge: Color? = nil, depth: CGFloat = Chunk.depthSmall) {
        self.filled = filled
        self.fill = fill
        self.edge = edge
        self.depth = depth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(filled ? Color.ds.canvas : Color.ds.ink)
            .frame(minWidth: Chunk.iconButton, minHeight: Chunk.iconButton)
            .background(Circle().fill(fill ?? (filled ? Color.ds.ink : Color.ds.surface)))
            .offset(y: pressed ? depth : 0)
            .background(Circle().fill(edge ?? (filled ? Color.ds.inkEdge : ground.edge)).offset(y: depth))
            .padding(.bottom, depth)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(Circle())
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

public extension ButtonStyle where Self == ChunkyButtonStyle {
    /// The filled primary action, as wide as its container.
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle(.filled) }
    /// A white, quieter action.
    static var chunkyPlain: ChunkyButtonStyle { ChunkyButtonStyle(.plain) }
    /// Hugs its label instead of filling the width.
    static func chunky(_ kind: ChunkyButtonStyle.Kind, fullWidth: Bool, minHeight: CGFloat = Chunk.iconButton) -> ChunkyButtonStyle {
        ChunkyButtonStyle(kind, fullWidth: fullWidth, minHeight: minHeight)
    }
}

public extension ButtonStyle where Self == ChunkyIconButtonStyle {
    static var chunkyIcon: ChunkyIconButtonStyle { ChunkyIconButtonStyle() }
    static var chunkyIconFilled: ChunkyIconButtonStyle { ChunkyIconButtonStyle(filled: true) }
}

/// A resting surface (row, panel, bubble): white, rounded, with the hard bottom edge.
struct ChunkySurface: ViewModifier {
    let radius: CGFloat
    let fill: Color
    @Environment(\.dsGround) private var ground

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .background(shape.fill(ground.edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
    }
}

public extension View {
    /// White rounded surface with the hard bottom edge. Use for rows and panels; pad the content first.
    func dsSurface(radius: CGFloat = Radius.large, fill: Color = Color.ds.surface) -> some View {
        modifier(ChunkySurface(radius: radius, fill: fill))
    }
}

// MARK: - Pimpi's voice

/// Pimpi's line in a bubble. Pair it with the mascot; the tail points at it.
public struct SpeechBubble: View {
    public enum Tail: Sendable {
        case down
        case leading
        case up
        case none
    }

    let text: Text
    let tail: Tail
    @Environment(\.dsGround) private var ground

    public init(_ text: Text, tail: Tail = .down) {
        self.text = text
        self.tail = tail
    }

    public var body: some View {
        text
            .font(.ds.pimpi)
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(minHeight: Chunk.controlHeight)
            .background(alignment: tailAlignment) { tailShape }
            .dsSurface(radius: Radius.large)
            .accessibilityElement(children: .combine)
    }

    private var tailAlignment: Alignment {
        switch tail {
        case .down, .none: .bottom
        case .up: .top
        case .leading: .leading
        }
    }

    @ViewBuilder private var tailShape: some View {
        if tail != .none {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.ds.surface)
                .frame(width: Spacing.lg, height: Spacing.lg)
                .rotationEffect(.degrees(45))
                .offset(x: tail == .leading ? -Spacing.xs : 0,
                        y: tail == .down ? Spacing.xs : (tail == .up ? -Spacing.xs : 0))
        }
    }
}

// MARK: - Pill picker

/// Two or three choices in one white capsule; the choice is a filled pill that slides between them.
public struct PillPicker<Value: Hashable & Sendable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    public init(_ options: [(value: Value, title: String)], selection: Binding<Value>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selected ? Color.ds.canvas : Color.ds.ink)
                        .padding(.horizontal, Spacing.xs)
                        .frame(maxWidth: .infinity, minHeight: Chunk.iconButton)
                        .background {
                            if selected { Capsule().fill(Color.ds.ink).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(Spacing.xxs)
        .background(Capsule().fill(Color.ds.surface))
        .background(Capsule().fill(ground.edge).offset(y: Chunk.depthSmall))
        .padding(.bottom, Chunk.depthSmall)
        .sensoryFeedback(Haptic.toggle, trigger: selection)
    }
}
