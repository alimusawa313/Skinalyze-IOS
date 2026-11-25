import SwiftData
import SwiftUI
import SkinalyzeKit

/// Home is Pimpi's place: Pimpi on a hill with a line for you, today's three things (morning routine, scan, evening
/// routine), your streak and a signpost to your latest scan. The camera is not running here — it opens when a scan starts.
struct HomePlace: View {
    let latest: ScanSession?
    let name: String
    let scannedToday: Bool
    /// Set when today's free scan is used.
    let nextFreeScan: Date?
    let cameraUnavailable: Bool
    let requestScan: () -> Void
    let showProfile: () -> Void
    let openLatest: () -> Void

    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(RoutineToday.logKey) private var routineLogRaw = ""
    @State private var pokes = 0
    @State private var showsStreak = false
    @State private var routinePart: RoutineChecklist.Part?

    private enum Metrics {
        static let pimpi: CGFloat = 250
        static let pimpiCompact: CGFloat = 170
        static let routineToken: CGFloat = 76
        static let scanToken: CGFloat = 116
        static let scanGlyph: CGFloat = 52
        /// How far the hill rises behind Pimpi's feet.
        static let hillOverlap: CGFloat = 34
        static let hillRise: CGFloat = 54
        static let sun: CGFloat = 124
        /// Room for the floating dock under the buttons.
        static let dockClearance: CGFloat = 96
        static let signWidth: CGFloat = 76
        static let signPost = CGSize(width: 7, height: 30)
        static let signTilt: Double = 5
        /// How high Pimpi hops when today's three are done.
        static let cheerHop: CGFloat = 18
        static let signSway: Double = 3
    }

    /// Pimpi's squash and stretch when poked.
    private struct Squish {
        var x: CGFloat = 1
        var y: CGFloat = 1
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                wide
            } else {
                tall
            }
        }
        .sheet(isPresented: $showsStreak) { StreakSheet() }
        .sheet(item: $routinePart) { part in RoutineTodaySheet(part: part) }
        .onChange(of: engagement.milestone) { _, milestone in
            if milestone != nil { showsStreak = true } // celebrate once, with Pimpi
        }
    }

    // MARK: Layouts

    /// Portrait and every other tall shape: sky on top, the hill under Pimpi's feet.
    private var tall: some View {
        VStack(spacing: 0) {
            HStack {
                streakChip
                Spacer()
                profileButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            bubble
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            pimpi(size: Metrics.pimpi)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .overlay(alignment: .bottomTrailing) {
                    latestSign.padding(.trailing, Spacing.md).padding(.bottom, Spacing.xs)
                }
                .zIndex(1) // Pimpi stands in front of the hill that rises behind its feet
            today
                .padding(.top, Spacing.lg)
                .padding(.bottom, Metrics.dockClearance)
                .frame(maxWidth: .infinity)
                .background(alignment: .top) { hill }
                .onHill()
        }
        .background(Color.ds.canvas.ignoresSafeArea())
    }

    /// Landscape and other short shapes: Pimpi on the left, today's buttons on the right.
    private var wide: some View {
        HStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                bubble
                pimpi(size: Metrics.pimpiCompact)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: Spacing.sm) {
                HStack {
                    streakChip
                    Spacer()
                    latestChip
                    profileButton
                }
                today
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .dsHill(crest: 0.7, rise: Metrics.hillRise, showsFarHill: true)
    }

    /// The hill, anchored to the top of today's buttons so Pimpi always stands on it, whatever the screen height.
    private var hill: some View {
        ZStack(alignment: .top) {
            Circle().fill(Color.ds.sun)
                .frame(width: Metrics.sun, height: Metrics.sun)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -Spacing.md, y: -Metrics.sun * 0.55)
            HillShape(crest: 0, rise: Metrics.hillRise * 1.4)
                .fill(Color.ds.hillFar)
                .scaleEffect(x: 1.3, anchor: .trailing)
                .offset(x: -Metrics.sun, y: -Metrics.hillOverlap)
            HillShape(crest: 0, rise: Metrics.hillRise).fill(Color.ds.hill)
        }
        .padding(.top, -Metrics.hillOverlap)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
        .accessibilityHidden(true)
    }

    // MARK: Pimpi

    private func pimpi(size: CGFloat) -> some View {
        Button {
            pokes += 1
        } label: {
            Pimpi(mood: mood).frame(maxWidth: size, maxHeight: size)
                .keyframeAnimator(initialValue: Squish(), trigger: pokes) { content, squish in
                    content.scaleEffect(x: reduceMotion ? 1 : squish.x, y: reduceMotion ? 1 : squish.y, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.x) {
                        SpringKeyframe(1.14, duration: 0.12, spring: .snappy)
                        SpringKeyframe(0.94, duration: 0.18, spring: .snappy)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy(extraBounce: 0.2))
                    }
                    KeyframeTrack(\.y) {
                        SpringKeyframe(0.84, duration: 0.12, spring: .snappy)
                        SpringKeyframe(1.08, duration: 0.18, spring: .snappy)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy(extraBounce: 0.2))
                    }
                }
                .phaseAnimator(reduceMotion ? [0.0] : [0.0, -Metrics.cheerHop, 0.0], trigger: doneCount == 3) { content, hop in
                    content.offset(y: hop)
                } animation: { _ in .spring(duration: 0.3, bounce: 0.5) }
        }
        .buttonStyle(.bouncy(0.9))
        .sensoryFeedback(.impact(weight: .light), trigger: pokes)
        .accessibilityLabel(Text("Pimpi"))
        .accessibilityHint(Text("Says something else"))
        .accessibilityIdentifier("homePimpi")
    }

    /// Pimpi's bubble. A new line pops in each time it changes.
    private var bubble: some View {
        SpeechBubble(line)
            .id(lineKey)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: lineKey)
    }

    /// Changes whenever Pimpi says something new.
    private var lineKey: String { "\(pokes)-\(doneCount == 3)-\(latest == nil)" }

    /// Effort only: the streak decides Pimpi's mood, and finishing today's three things makes it cheer.
    private var mood: MascotMood {
        if doneCount == 3 { return .excited }
        return pokes == 0 ? engagement.mood : pokedLine.mood
    }

    private var line: Text {
        if pokes > 0 { return Text(verbatim: pokedLine.localized) }
        if doneCount == 3 { return Text("Three for three. Look at us go.") }
        guard latest != nil else {
            return (name.isEmpty ? Text("Hey.") : Text("Hey, \(name).")) + Text(verbatim: " ") + Text("Let's meet your skin.")
        }
        return Text(StreakCopy.routineLine(engagement.routine.status))
    }

    /// What Pimpi says when poked (from the shared pool). About showing up and small habits — never about how the
    /// skin looks.
    private var pokedLine: PimpiLine {
        PimpiLines.shared.line(poke: pokes, place: .home,
                               hasStreak: engagement.routine.count >= PimpiLines.minimumStreakDays)
    }

    // MARK: Top bar

    private var streakChip: some View {
        Button { showsStreak = true } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: hasChest ? "gift.fill" : "flame.fill")
                    .foregroundStyle(hasChest ? Color.ds.positive : Color.ds.signal)
                    .symbolEffect(.bounce, value: hasChest)
                if engagement.routine.count > 0 {
                    Text("\(engagement.routine.count)-day streak")
                        .contentTransition(.numericText(value: Double(engagement.routine.count)))
                } else {
                    Text("Start a streak today")
                }
            }
        }
        .buttonStyle(.chunky(.plain, fullWidth: false))
        .accessibilityLabel(engagement.routine.count > 0
            ? Text("Pimpi. Routine streak: \(engagement.routine.count) days")
            : Text("Pimpi. No routine streak yet"))
        .accessibilityHint("Shows your streaks")
        .accessibilityIdentifier("pimpiStreak")
    }

    private var hasChest: Bool { (quests?.ledger.chestsWaiting ?? 0) > 0 }

    private var profileButton: some View {
        Button(action: showProfile) { Avatar(name: name) }
            .buttonStyle(.chunkyIcon)
            .accessibilityLabel("Profile and settings")
    }

    // MARK: Latest scan

    /// A little signpost planted next to Pimpi: the latest breakout index and its band.
    @ViewBuilder private var latestSign: some View {
        if let latest {
            Button(action: openLatest) {
                VStack(spacing: 0) {
                    signFace(latest)
                        .frame(width: Metrics.signWidth)
                        .padding(.vertical, Spacing.xs)
                        .dsSurface(radius: Radius.small)
                    UnevenRoundedRectangle(bottomLeadingRadius: Spacing.xxs, bottomTrailingRadius: Spacing.xxs)
                        .fill(Color.ds.edgeOnHill)
                        .frame(width: Metrics.signPost.width, height: Metrics.signPost.height)
                }
                .rotationEffect(.degrees(Metrics.signTilt), anchor: .bottom)
                .phaseAnimator(reduceMotion ? [0.0] : [0.0, Metrics.signSway]) { content, sway in
                    content.rotationEffect(.degrees(sway), anchor: .bottom)
                } animation: { _ in .easeInOut(duration: 2) }
            }
            .buttonStyle(.bouncy(0.92))
            .latestScanAccessibility(latest)
        }
    }

    /// The same information as a chip, where there is no room to plant a sign.
    @ViewBuilder private var latestChip: some View {
        if let latest {
            Button(action: openLatest) {
                HStack(spacing: Spacing.xs) {
                    Text(latest.breakoutIndex, format: .number).monospacedDigit()
                    Circle().fill(Color.ds.band(latest.band)).frame(width: Spacing.xs, height: Spacing.xs)
                    Text(BandCopy.title(latest.band))
                }
            }
            .buttonStyle(.chunky(.plain, fullWidth: false))
            .latestScanAccessibility(latest)
        }
    }

    private func signFace(_ latest: ScanSession) -> some View {
        VStack(spacing: 0) {
            Text(latest.breakoutIndex, format: .number)
                .font(.system(.title, design: .rounded).weight(.heavy).monospacedDigit())
                .contentTransition(.numericText(value: Double(latest.breakoutIndex)))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: Spacing.xxs) {
                Circle().fill(Color.ds.band(latest.band)).frame(width: Spacing.xs, height: Spacing.xs)
                Text(BandCopy.title(latest.band)).font(.system(.caption, design: .rounded).weight(.heavy))
            }
        }
        .foregroundStyle(Color.ds.ink)
    }

    // MARK: Today

    private var today: some View {
        VStack(spacing: Spacing.sm) {
            Text("\(doneCount) of 3 today")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.ds.ink)
                .contentTransition(.numericText(value: Double(doneCount)))
            HStack(alignment: .bottom, spacing: Spacing.lg) {
                routineToken(.morning, symbol: "sun.max.fill")
                scanToken
                routineToken(.evening, symbol: "moon.fill")
            }
            scanNote
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: doneCount)
        .sensoryFeedback(Haptic.success, trigger: doneCount) { old, new in new == 3 && old < 3 }
    }

    private func routineToken(_ part: RoutineChecklist.Part, symbol: String) -> some View {
        let done = isDone(part)
        return VStack(spacing: Spacing.xs) {
            Button { routinePart = part } label: {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .frame(width: Metrics.routineToken, height: Metrics.routineToken)
            }
            .buttonStyle(ChunkyIconButtonStyle(filled: done, depth: Chunk.depth))
            .overlay(alignment: .topTrailing) { doneBadge(done) }
            .accessibilityLabel(part == .morning ? Text("Morning routine") : Text("Evening routine"))
            .accessibilityValue(done ? Text("Done") : Text("Not done"))
            .accessibilityIdentifier(part == .morning ? "homeMorning" : "homeEvening")
            Text(part.title).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ds.ink)
        }
    }

    private var scanToken: some View {
        VStack(spacing: Spacing.xs) {
            Button(action: requestScan) {
                Image(systemName: "faceid")
                    .font(.system(size: Metrics.scanGlyph, weight: .semibold))
                    .foregroundStyle(Color.ds.pimpiCheek)
                    .frame(width: Metrics.scanToken, height: Metrics.scanToken)
            }
            .buttonStyle(ChunkyIconButtonStyle(fill: Color.ds.pimpiBodyDeep, edge: Color.ds.pimpiEdge, depth: Chunk.depth + 2))
            .overlay(alignment: .topTrailing) { doneBadge(scannedToday) }
            .disabled(cameraUnavailable && nextFreeScan == nil)
            .accessibilityLabel(Text("Scan my skin"))
            .accessibilityIdentifier("mirrorShutter")
            Text("Scan").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ds.ink)
        }
    }

    @ViewBuilder private func doneBadge(_ done: Bool) -> some View {
        if done {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.ds.canvas, Color.ds.positive)
                .background(Circle().fill(Color.ds.hill).padding(-2))
                .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
                .symbolEffect(.bounce, value: done)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var scanNote: some View {
        if nextFreeScan != nil {
            Label("Next free scan at midnight", systemImage: "moon.stars")
                .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.ink)
                .accessibilityIdentifier("nextFreeScan")
        } else if cameraUnavailable {
            Text("Camera unavailable — scan on a real iPhone.")
                .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.ink)
        }
    }

    private func isDone(_ part: RoutineChecklist.Part) -> Bool {
        let routinePart: RoutinePart = part == .morning ? .morning : .evening
        let steps = RoutineToday.steps(for: routinePart)
        let log = RoutineLog(raw: routineLogRaw)
        return !steps.isEmpty && steps.allSatisfy { log.isDone(part: part.rawValue, slot: $0.slot) }
    }

    private var doneCount: Int {
        [isDone(.morning), scannedToday, isDone(.evening)].filter { $0 }.count
    }
}

private extension View {
    /// Reads as "6, Mild · breakout index" and opens the scan.
    func latestScanAccessibility(_ latest: ScanSession) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(latest.breakoutIndex, format: .number) + Text(verbatim: ", ")
                + Text("\(BandCopy.title(latest.band)) · breakout index"))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens your latest scan")
            .accessibilityIdentifier("mirrorIndex")
    }
}

/// Today's check-off for one part of the day, opened from Home.
private struct RoutineTodaySheet: View {
    let part: RoutineChecklist.Part
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RoutineChecklist(initialPart: part).padding(Spacing.md)
            }
            .dsCanvas()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
