import Foundation
import SwiftUI
import SkinalyzeKit

/// Gathers what recaps count from the stores that already exist (routine days, quest ledger, scans, shelf history),
/// and remembers which recaps were seen.
@MainActor
enum RecapData {
    private static let seenKey = "seenRecaps"

    static func history(scans: [ScanSession], quests: QuestModel) -> ActivityHistory {
        ActivityHistory(routineDays: EngagementStore().doneDays, scanDates: scans.map(\.createdAt),
                        quests: quests.ledger.completed)
    }

    static func shelf() -> [ShelfStint] {
        RoutineHistory.all().map { ShelfStint(productID: $0.key, started: $0.value.startedAt, stopped: $0.value.stoppedAt) }
    }

    /// "Today" for deciding which recap is due. Debug builds can pretend with `-recapToday yyyy-MM-dd`.
    static var now: Date {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "recapToday"), let day = DayStamp(string: raw) {
            return day.date(in: .current)
        }
        #endif
        return .now
    }

    /// The recap to offer on the Shelf: Wrapped first, then the month, then the week — only one at a time, and only
    /// when something happened in it and it hasn't been opened or dismissed.
    static func due(history: ActivityHistory, calendar: Calendar = .current) -> RecapPeriod? {
        let now = Self.now
        let candidates = [RecapEngine.dueWrapped(now: now, calendar: calendar),
                          RecapEngine.dueMonth(now: now, calendar: calendar),
                          RecapEngine.dueWeek(now: now, calendar: calendar)].compactMap { $0 }
        let seen = seenIDs
        return candidates.first { period in
            !seen.contains(period.id) && !RecapEngine.recap(period, history: history, calendar: calendar).isEmpty
        }
    }

    static var seenIDs: Set<String> { Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? []) }

    static func markSeen(_ period: RecapPeriod) {
        UserDefaults.standard.set(Array(seenIDs.union([period.id])).sorted(), forKey: seenKey)
    }
}

extension RecapPeriod: @retroactive Identifiable {}

/// Titles and Pimpi's words for a recap. All copy here is about effort.
enum RecapCopy {
    static func title(_ period: RecapPeriod) -> String {
        let calendar = Calendar.current
        let start = period.first.date(in: calendar)
        switch period.kind {
        case .week: return String(localized: "Your week")
        case .month: return String(localized: "Your \(start.formatted(.dateTime.month(.wide)))")
        case .quarter: return String(localized: "Your Skin Wrapped")
        case .year: return String(localized: "Your \(start.formatted(.dateTime.year())) Wrapped")
        }
    }

    static func dates(_ period: RecapPeriod) -> String {
        let calendar = Calendar.current
        let start = period.first.date(in: calendar), end = period.last.date(in: calendar)
        switch period.kind {
        case .week, .quarter:
            return (start..<end).formatted(.interval.day().month(.abbreviated).year())
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .year: return start.formatted(.dateTime.year())
        }
    }

    static func cheer(_ cheer: RecapCheer) -> String {
        switch cheer {
        case .everyDay: String(localized: "Every single day! I'm so proud of you.")
        case .mostDays: String(localized: "You showed up most days. That's how habits stick.")
        case .keptLooking: String(localized: "You kept checking in. Every little bit counts.")
        case .freshStart: String(localized: "A quiet stretch, and that's okay. Let's start fresh together.")
        }
    }

    static func mood(_ cheer: RecapCheer) -> MascotMood {
        switch cheer {
        case .everyDay, .mostDays: .excited
        case .keptLooking: .happy
        case .freshStart: .curious
        }
    }

    static func isWrapped(_ period: RecapPeriod) -> Bool { period.kind == .quarter || period.kind == .year }
}

/// Pimpi beside the words normally; above them at accessibility text sizes, so the words keep the full width.
struct PimpiRow<Content: View>: View {
    var spacing: CGFloat = Spacing.md
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}

// MARK: - Pimpi's Place pieces shared by the showing-up screens (streaks, journey, school, journal, friends)

/// Sizes those screens share.
enum EffortMetrics {
    /// How far the hill's sides sit below its crest.
    static let hillRise: CGFloat = 40
    /// The hill keeps going under the scroll view's bounce.
    static let hillOverscroll: CGFloat = 1200
    /// How far the hill rises behind the feet of whoever stands on it.
    static let heroOverlap: CGFloat = 28
    /// Where the hill starts on two-pane layouts, as a share of the height.
    static let wideCrest: CGFloat = 0.62
    /// Widest comfortable column.
    static let readable: CGFloat = 640
    static let bar: CGFloat = 12
    static let mark: CGFloat = 32
    static let markLarge: CGFloat = 44
    static let ring: CGFloat = 3
    static let dimmed: Double = 0.45
    /// A mark not yet done sits a touch smaller, so ticking it pops.
    static let markRest: CGFloat = 0.92
}

/// The hill under a screen's pressable content: from the top of that content down past the bottom of the screen.
struct EffortHill: View {
    var body: some View {
        HillShape(crest: 0, rise: EffortMetrics.hillRise)
            .fill(Color.ds.hill)
            .padding(.bottom, -EffortMetrics.hillOverscroll)
            .ignoresSafeArea(edges: .horizontal)
            .accessibilityHidden(true)
    }
}

/// A scrolling screen in Pimpi's Place: `sky` holds what to look at, `ground` what to press, on a hill that runs to
/// the bottom. On regular widths the two become panes side by side (either side of the fold on iPhone Duo).
struct EffortScroll<Sky: View, Ground: View>: View {
    @ViewBuilder let sky: Sky
    @ViewBuilder let ground: Ground
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            AdaptivePair(.split) {
                ScrollView { column(sky) }
            } secondary: {
                ScrollView { column(ground) }
            }
            .dsHill(crest: EffortMetrics.wideCrest, rise: EffortMetrics.hillRise)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    column(sky)
                    column(ground)
                        .padding(.top, EffortMetrics.hillRise / 2)
                        .background(alignment: .top) { EffortHill() }
                        .onHill()
                }
            }
            .background(Color.ds.canvas.ignoresSafeArea())
        }
    }

    private func column(_ content: some View) -> some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: EffortMetrics.readable)
            .frame(maxWidth: .infinity)
    }
}

/// A screen with one moment on it: `hero` stands on the hill and `ground` (the buttons) sits on it. It fills the
/// screen when everything fits and scrolls when it doesn't (landscape, large text).
struct EffortStage<Hero: View, Ground: View>: View {
    @ViewBuilder let hero: Hero
    @ViewBuilder let ground: Ground

    var body: some View {
        ViewThatFits(in: .vertical) {
            layout(fills: true)
            ScrollView { layout(fills: false) }
        }
        .background(Color.ds.canvas.ignoresSafeArea())
    }

    private func layout(fills: Bool) -> some View {
        VStack(spacing: 0) {
            hero
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .frame(maxWidth: EffortMetrics.readable)
                .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .bottom)
                .zIndex(1) // whoever stands here is in front of the hill rising behind their feet
            ground
                .padding(Spacing.lg)
                .frame(maxWidth: EffortMetrics.readable)
                .frame(maxWidth: .infinity)
                .background(alignment: .top) { EffortHill().padding(.top, -EffortMetrics.heroOverlap) }
                .onHill()
        }
    }
}

/// A row you tap: a white rounded surface that stands proud of the ground and sinks when pressed. `filled` is the
/// one ink row on a screen; `fill` recolours it (a right or wrong answer).
struct EffortRowButtonStyle: ButtonStyle {
    var filled = false
    var fill: Color?
    var dimsWhenDisabled = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        configuration.label
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Chunk.controlHeight, alignment: .leading)
            .background(shape.fill(fill ?? (filled ? Color.ds.ink : Color.ds.surface)))
            .offset(y: pressed ? Chunk.depth : 0)
            .background(shape.fill(edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
            .opacity(isEnabled || !dimsWhenDisabled ? 1 : EffortMetrics.dimmed)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(shape)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }

    private var edge: Color {
        if filled, fill == nil { return Color.ds.inkEdge }
        return ground == .hill ? Color.ds.edgeOnHill : Color.ds.edge
    }
}

extension ButtonStyle where Self == EffortRowButtonStyle {
    /// A white pressable row.
    static var effortRow: EffortRowButtonStyle { EffortRowButtonStyle() }
}

/// The round mark at the start of a row: a green check once done, otherwise a quiet ring around `glyph`.
struct EffortMark<Glyph: View>: View {
    let done: Bool
    @ScaledMetric private var side: CGFloat
    @ViewBuilder let glyph: Glyph

    init(done: Bool, side: CGFloat = EffortMetrics.mark, @ViewBuilder glyph: () -> Glyph) {
        self.done = done
        self._side = ScaledMetric(wrappedValue: side, relativeTo: .body)
        self.glyph = glyph()
    }

    var body: some View {
        ZStack {
            if done {
                Circle().fill(Color.ds.positive)
                Image(systemName: "checkmark").foregroundStyle(Color.ds.canvas)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle().strokeBorder(Color.ds.hairline, lineWidth: EffortMetrics.ring)
                glyph.foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .font(.system(.footnote, design: .rounded).weight(.heavy))
        .frame(width: side, height: side)
        .scaleEffect(done ? 1 : EffortMetrics.markRest)
        .dsAnimation(.bouncy, value: done) // the check pops in
        .accessibilityHidden(true)
    }
}

/// A chunky progress bar. It carries no words: put the number in text beside it.
struct EffortBar: View {
    let value: Double
    var tint = Color.ds.positive

    var body: some View {
        Capsule().fill(Color.ds.surfaceRaised)
            .overlay { Fill(fraction: min(max(value, 0), 1)).fill(tint) }
            .frame(height: EffortMetrics.bar)
            .dsAnimation(.bouncy, value: value) // springs forward
            .accessibilityHidden(true)
    }

    /// The done part: a capsule from the leading edge, never shorter than it is tall (so it stays round).
    private struct Fill: Shape {
        var fraction: Double

        var animatableData: Double {
            get { fraction }
            set { fraction = newValue }
        }

        func path(in rect: CGRect) -> Path {
            guard fraction > 0 else { return Path() }
            let width = max(rect.height, rect.width * fraction)
            return Path(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height),
                        cornerRadius: rect.height / 2)
        }
    }
}

/// A small filled tag ("Pro", "+10"). `quiet` is the soft version for numbers; `onInk` flips it for a filled row.
struct EffortTag: View {
    let text: Text
    var quiet = false
    var onInk = false

    var body: some View {
        text
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(quiet || onInk ? Color.ds.ink : Color.ds.canvas)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Capsule().fill(quiet ? Color.ds.surfaceRaised : (onInk ? Color.ds.canvas : Color.ds.ink)))
    }
}

extension Font {
    /// Heavy rounded type for the words on rows and pills.
    static let effortRow = Font.system(.callout, design: .rounded).weight(.heavy)
    static let effortNote = Font.system(.footnote, design: .rounded).weight(.bold)
}

