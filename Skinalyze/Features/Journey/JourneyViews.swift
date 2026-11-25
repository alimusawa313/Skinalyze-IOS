import SwiftData
import SwiftUI
import SkinalyzeKit

// The journey map (E11): Pimpi walking a winding path of stops, moved along by glow points and Skin School XP.
// The same screen holds the 30-day challenges and every recap.

enum JourneyCopy {
    static func stopName(_ stop: Int) -> String {
        switch stop {
        case 1: String(localized: "First step")
        case 2: String(localized: "Getting started")
        case 3: String(localized: "Warming up")
        case 4: String(localized: "On a roll")
        case 5: String(localized: "Good habits")
        case 6: String(localized: "Steady hands")
        case 7: String(localized: "Routine regular")
        case 8: String(localized: "Sunscreen star")
        case 9: String(localized: "Label reader")
        case 10: String(localized: "Skin scholar")
        case 11: String(localized: "Habit hero")
        default: String(localized: "Pimpi's best friend")
        }
    }
}

/// On the Shelf: where you are on the journey and today's challenge.
struct JourneyCard: View {
    @Environment(QuestModel.self) private var quests
    @Environment(SchoolModel.self) private var school
    @Environment(ChallengeModel.self) private var challenges
    @State private var showsJourney = false

    private enum Metrics {
        static let pimpi: CGFloat = 56
    }

    var body: some View {
        let position = Journey.position(xp: Journey.xp(points: quests.ledger.points, schoolXP: school.progress.xp))
        Button { showsJourney = true } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PimpiRow(spacing: Spacing.sm) {
                    Pimpi(mood: .happy).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Stop \(position.stop) · \(JourneyCopy.stopName(position.stop))")
                            .font(.effortRow).foregroundStyle(Color.ds.ink)
                        Group {
                            if let toNext = position.toNext {
                                Text("\(toNext) points to the next stop")
                            } else {
                                Text("You reached the end of the path!")
                            }
                        }
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.ink)
                        .accessibilityHidden(true)
                }
                EffortBar(value: position.progress)
                if let active = challenges.book.active {
                    Label {
                        Text("\(ChallengeCopy.title(active.kind)): day \(active.progress) of \(ChallengeEngine.goalDays)")
                    } icon: {
                        Image(systemName: ChallengeCopy.symbol(active.kind)).foregroundStyle(Color.ds.signal)
                    }
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(.effortRow)
        .accessibilityIdentifier("journeyCard")
        .fullScreenCover(isPresented: $showsJourney) { JourneyView() }
    }
}

struct JourneyView: View {
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?
    @Environment(QuestModel.self) private var quests
    @Environment(SchoolModel.self) private var school
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var opened: RecapPeriod?

    private enum Metrics {
        static let node: CGFloat = 64
        static let nodeBorder: CGFloat = 5
        static let trail: CGFloat = 18
        static let pimpi: CGFloat = 96
        /// How far Pimpi's feet sink into the stop it stands on.
        static let pimpiSink: CGFloat = 8
        static let hop: CGFloat = 8
        static let hopSeconds: Double = 0.75
        /// Where each stop sits across the width: the path winds left, middle, right, middle.
        static let lanes: [CGFloat] = [0.2, 0.5, 0.8, 0.5]
        /// At the largest text sizes the path runs straight down the leading side, so names keep the width.
        static let straightLane: CGFloat = 0.12
    }

    var body: some View {
        journeyBody.onAppear { tutorial?.noteJourneyVisited() }
    }

    @ViewBuilder private var journeyBody: some View {
        let position = Journey.position(xp: Journey.xp(points: quests.ledger.points, schoolXP: school.progress.xp))
        NavigationStack {
            EffortScroll {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Your journey")
                            .font(.ds.display).foregroundStyle(Color.ds.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Every quest, lesson and routine day moves Pimpi along. Nothing ever moves you back.")
                            .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    path(position)
                }
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    SocialEntryRow()
                    ChallengeSection()
                    recaps
                }
            }
            .defaultScrollAnchor(.top)
            .navigationTitle("Your journey")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label {
                        Text("\(position.xp) points").foregroundStyle(Color.ds.ink)
                            .contentTransition(.numericText(value: Double(position.xp)))
                            .dsAnimation(.bouncy, value: position.xp)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Color.ds.signal)
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.effortRow)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sheet(item: $opened) { RecapView(period: $0) }
    }

    // MARK: The path

    private func path(_ position: Journey.Position) -> some View {
        VStack(spacing: Spacing.lg) {
            ForEach(1...Journey.stops, id: \.self) { stop in
                stopView(stop, position: position)
            }
        }
        .frame(maxWidth: .infinity)
        .backgroundPreferenceValue(StopCentres.self) { centres in
            GeometryReader { proxy in
                let points = (1...Journey.stops).compactMap { stop in centres[stop].map { proxy[$0] } }
                let style = StrokeStyle(lineWidth: Metrics.trail, lineCap: .round, lineJoin: .round)
                ZStack {
                    Trail(points: points).stroke(Color.ds.surface, style: style)
                    Trail(points: Array(points.prefix(position.stop))).stroke(Color.ds.positive, style: style)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func stopView(_ stop: Int, position: Journey.Position) -> some View {
        let reached = stop <= position.stop
        let isHere = stop == position.stop
        let straight = typeSize.isAccessibilitySize
        let lane = straight ? Metrics.straightLane : Metrics.lanes[(stop - 1) % Metrics.lanes.count]
        let nameLeads = lane > Metrics.lanes[1]
        return StopLayout(lane: lane, nameLeads: nameLeads, spacing: Spacing.sm) {
            node(stop, reached: reached, isHere: isHere)
            VStack(alignment: nameLeads ? .trailing : .leading, spacing: Spacing.xxs) {
                if isHere {
                    Text("Stop \(stop) · \(JourneyCopy.stopName(stop))")
                    Group {
                        if let toNext = position.toNext {
                            Text("\(toNext) points to the next stop")
                        } else {
                            Text("You reached the end of the path!")
                        }
                    }
                    .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                } else {
                    Text(JourneyCopy.stopName(stop))
                }
            }
            .font(.effortRow)
            .foregroundStyle(reached ? Color.ds.ink : Color.ds.inkSecondary)
            .multilineTextAlignment(nameLeads ? .trailing : .leading)
        }
        // Room above the stop for Pimpi to stand on it without covering the stop before.
        .padding(.top, isHere ? Metrics.pimpi - Metrics.pimpiSink - Metrics.node / 2 - Spacing.lg : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stop \(stop): \(JourneyCopy.stopName(stop))"))
        .accessibilityValue(isHere ? Text("You are here") : reached ? Text("Reached") : Text("Not reached yet"))
        .accessibilityIdentifier("journeyStop.\(stop)")
    }

    /// A round stop: a green check once passed, Pimpi hopping on the one you're at, a lock on the ones ahead.
    private func node(_ stop: Int, reached: Bool, isHere: Bool) -> some View {
        let fill = isHere ? Color.ds.pimpiBody : reached ? Color.ds.positive : Color.ds.surfaceRaised
        return Circle().fill(fill)
            .overlay {
                if !isHere {
                    Image(systemName: reached ? "checkmark" : "lock.fill")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(reached ? Color.ds.canvas : Color.ds.inkTertiary)
                }
            }
            .padding(Metrics.nodeBorder)
            .background(Circle().fill(Color.ds.surface))
            .frame(width: Metrics.node, height: Metrics.node)
            .anchorPreference(key: StopCentres.self, value: .center) { [stop: $0] }
            .background(Circle().fill(isHere ? Color.ds.pimpiEdge : Color.ds.edge).offset(y: Chunk.depth))
            .overlay(alignment: .bottom) {
                if isHere {
                    PokablePimpi(mood: .excited, size: Metrics.pimpi)
                        .keyframeAnimator(initialValue: CGFloat(0), repeating: !reduceMotion) { pimpi, lift in
                            pimpi.offset(y: Metrics.pimpiSink - Metrics.node / 2 - (reduceMotion ? 0 : lift))
                        } keyframes: { _ in
                            KeyframeTrack {
                                CubicKeyframe(Metrics.hop, duration: Metrics.hopSeconds)
                                CubicKeyframe(0, duration: Metrics.hopSeconds)
                            }
                        }
                }
            }
    }

    // MARK: Recaps

    private var recaps: some View {
        let calendar = Calendar.current
        let now = RecapData.now
        let today = DayStamp(now, calendar: calendar)
        // On Monday "your week" is the one that just ended; otherwise this week so far.
        let week = RecapEngine.dueWeek(now: now, calendar: calendar) ?? RecapEngine.week(containing: today, calendar: calendar)
        let lastMonth = RecapEngine.previousMonth(now: now, calendar: calendar)
        let wrapped = RecapEngine.latestWrapped(now: now, calendar: calendar)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("Recaps")
            recapRow(week, symbol: "calendar")
            recapRow(lastMonth, symbol: "calendar.badge.checkmark")
            recapRow(wrapped, symbol: "gift.fill")
            if today.month == 12 || today.month == 1 {
                recapRow(.year(today.month == 1 ? today.year - 1 : today.year), symbol: "sparkles")
            }
        }
    }

    private func recapRow(_ period: RecapPeriod, symbol: String) -> some View {
        Button { opened = period } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: symbol).font(.title3.weight(.bold)).foregroundStyle(Color.ds.signal)
                    .frame(minWidth: EffortMetrics.mark)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(RecapCopy.title(period)).font(.effortRow).foregroundStyle(Color.ds.ink)
                    Text(RecapCopy.dates(period)).font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.ink)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.effortRow)
        .accessibilityIdentifier("recap.\(period.kind.rawValue)")
    }
}

/// Where each stop's centre is, so the trail can be drawn through them.
private struct StopCentres: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGPoint>] = [:]

    static func reduce(value: inout [Int: Anchor<CGPoint>], nextValue: () -> [Int: Anchor<CGPoint>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The trail: straight legs from stop to stop.
private struct Trail: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }
}

/// One stop of the path: the stop itself sits at `lane` (a share of the width) and its name takes the room beside
/// it, on the leading side when `nameLeads`. The first subview is the stop, the second its name.
private struct StopLayout: Layout {
    let lane: CGFloat
    let nameLeads: Bool
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let stop = subviews[0].sizeThatFits(.unspecified)
        guard let width = proposal.width, width.isFinite else {
            let name = subviews[1].sizeThatFits(.unspecified)
            return CGSize(width: stop.width + spacing + name.width, height: max(stop.height, name.height))
        }
        let name = subviews[1].sizeThatFits(ProposedViewSize(width: nameWidth(in: width, stop: stop), height: nil))
        return CGSize(width: width, height: max(stop.height, name.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let stop = subviews[0].sizeThatFits(.unspecified)
        let centre = bounds.minX + centreX(in: bounds.width, stop: stop)
        subviews[0].place(at: CGPoint(x: centre, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(stop))
        let room = ProposedViewSize(width: nameWidth(in: bounds.width, stop: stop), height: nil)
        if nameLeads {
            subviews[1].place(at: CGPoint(x: centre - stop.width / 2 - spacing, y: bounds.midY), anchor: .trailing, proposal: room)
        } else {
            subviews[1].place(at: CGPoint(x: centre + stop.width / 2 + spacing, y: bounds.midY), anchor: .leading, proposal: room)
        }
    }

    private func centreX(in width: CGFloat, stop: CGSize) -> CGFloat {
        min(max(width * lane, stop.width / 2), max(width - stop.width / 2, stop.width / 2))
    }

    private func nameWidth(in width: CGFloat, stop: CGSize) -> CGFloat {
        let centre = centreX(in: width, stop: stop)
        return max((nameLeads ? centre : width - centre) - stop.width / 2 - spacing, 0)
    }
}
