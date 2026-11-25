import Charts
import SwiftData
import SwiftUI
import SkinalyzeKit

/// History as a deck of skin cards you flick through, in Pimpi's place: a big title and the scan count on the sky, a
/// thin trend line with the card in focus riding on it as a dot, Pimpi watching from the side, and the cards tilting
/// away in 3D as they scroll down onto the hill. "Compare" turns the deck into pick-two.
struct DeckView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @AppStorage(Vault.secretKey) private var vaultSecret = false
    @State private var showsVault = false
    @State private var focusedID: PersistentIdentifier?
    @State private var isPicking = false
    @State private var picked: [ScanSession] = []
    @State private var comparePair: ComparePair?
    @State private var showsReel = false
    @State private var showsZoneMap = false
    @State private var paywall: PaywallReason?
    @Environment(ProAccess.self) private var access: ProAccess?

    struct ComparePair: Identifiable {
        let earlier: ScanSession
        let later: ScanSession
        var id: String { "\(earlier.id)-\(later.id)" }
    }

    private enum Metrics {
        static let title: CGFloat = 46
        static let trendHeight: CGFloat = 56
        static let pimpi: CGFloat = 92
        static let pimpiCompact: CGFloat = 64
        static let emptyPimpi: CGFloat = 170
        /// Where the hill starts, as a fraction of the screen height.
        static let hillCrest: CGFloat = 0.72
        static let hillRise: CGFloat = 40
        /// Room for the floating dock under the compare buttons (portrait; in landscape the dock stands at the side).
        static let dockClearance: CGFloat = 76
        /// Room under the last card so it can scroll clear of the compare buttons.
        static let stackBottomMargin: CGFloat = 24
        /// A card fills this much of the deck's height.
        static let cardHeight: CGFloat = 0.8
        static let cardMaxWidth: CGFloat = 460
        static let sideColumnWidth: CGFloat = 300
        static let titleHoldSeconds: Double = 1.5
        // 3D tilt as cards scroll away.
        static let tiltDegrees: Double = -24
        static let tiltPerspective: CGFloat = 0.6
        static let tiltShrink: CGFloat = 0.12
        static let tiltFade: Double = 0.45
        static let tiltBlur: CGFloat = 2
        static let pressScale: CGFloat = 0.95
        static let pickedScale: CGFloat = 0.94
        static let settleScale: CGFloat = 1.03
    }

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = Metrics.title

    private var focused: ScanSession? { scans.first { $0.persistentModelID == focusedID } ?? scans.first }
    private var isWide: Bool { verticalSizeClass == .compact }

    var body: some View {
        deckBody.offersCoach([.deckCompare])
    }

    @ViewBuilder private var deckBody: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    empty
                } else if isWide {
                    wide
                } else {
                    tall
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dsHill(crest: Metrics.hillCrest, rise: Metrics.hillRise)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanSession.self) { ScanResultView(session: $0) }
        }
        .sheet(item: $comparePair) { pair in
            NavigationStack { CompareView(earlier: pair.earlier, later: pair.later) }
        }
        .sheet(isPresented: $showsReel) { VideoShareSheet(source: .reel(scans: scans)) }
        .sheet(isPresented: $showsZoneMap) { ZoneMapView() }
        .sheet(isPresented: $showsVault) { NavigationStack { HiddenScansView() } }
        .paywallSheet($paywall)
    }

    // MARK: Layouts

    /// Portrait and other tall shapes: title and trend on the sky, the deck below, compare on the hill.
    private var tall: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            trendRow(pimpiSize: Metrics.pimpi)
                .padding(.horizontal, Spacing.lg)
            stack
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    compareBar
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Metrics.dockClearance)
                }
        }
    }

    /// Landscape: title, trend and compare in a side column; the deck keeps the full height.
    private var wide: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                trendRow(pimpiSize: Metrics.pimpiCompact)
                    .padding(.horizontal, Spacing.lg)
                Spacer(minLength: 0)
                compareBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                    .onHill()
            }
            .frame(maxWidth: Metrics.sideColumnWidth)
            stack
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Deck").font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.ds.ink)
                    .lineLimit(1).fixedSize()
                    .accessibilityAddTraits(.isHeader)
                    // The private vault's secret way in (P13): press and hold the title.
                    .contentShape(Rectangle())
                    .simultaneousGesture(LongPressGesture(minimumDuration: Metrics.titleHoldSeconds).onEnded { _ in
                        if vaultSecret { showsVault = true }
                    })
                    .accessibilityActions {
                        if vaultSecret { Button("Open hidden scans") { showsVault = true } }
                    }
                    .accessibilityIdentifier("deckTitle")
                HStack(spacing: Spacing.xxs) {
                    Text("\(scans.count)")
                        .contentTransition(.numericText(value: Double(scans.count)))
                        .accessibilityIdentifier("deckCount")
                    Text("Scans").textCase(.lowercase)
                }
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.inkSecondary)
            }
            Spacer(minLength: 0)
            if !isPicking {
                HStack(spacing: Spacing.sm) {
                    Button {
                        if (access?.policy ?? AccessPolicy(hasFullAccess: true)).allows(.zoneMap) {
                            showsZoneMap = true
                        } else {
                            paywall = .zoneMap
                        }
                    } label: {
                        Label("Zone map", systemImage: "circle.hexagongrid")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.chunkyIcon)
                    .accessibilityIdentifier("deckZoneMap")
                    if scans.count >= 2 {
                        Button { showsReel = true } label: {
                            Label("Glow-up reel", systemImage: "film")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.chunkyIcon)
                        .accessibilityIdentifier("deckReel")
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    /// The trend line with the focused scan as a dot, and Pimpi watching from the end of it.
    private func trendRow(pimpiSize: CGFloat) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            if scans.count >= 2 {
                DeckTrendLine(scans: scans, focusedID: focused?.persistentModelID)
                    .frame(height: Metrics.trendHeight)
            } else {
                Spacer(minLength: 0)
            }
            // Curious while you pick, cheering at each pick (picking is effort, not a verdict).
            PokablePimpi(mood: picked.count == 2 ? .excited : (isPicking ? .curious : .happy), size: pimpiSize,
                         cheer: picked.count)
        }
    }

    private var stack: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Spacing.lg) {
                ForEach(scans) { scan in
                    card(scan)
                        // A springy settle when a flick lands on this card.
                        .keyframeAnimator(initialValue: CGFloat(1), trigger: focusedID == scan.persistentModelID) { content, scale in
                            content.scaleEffect(reduceMotion ? 1 : scale)
                        } keyframes: { _ in
                            SpringKeyframe(Metrics.settleScale, duration: 0.14, spring: .snappy)
                            SpringKeyframe(1, duration: 0.45, spring: .bouncy(extraBounce: 0.2))
                        }
                        .frame(maxWidth: Metrics.cardMaxWidth)
                        .containerRelativeFrame(.vertical) { height, _ in height * Metrics.cardHeight }
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * Metrics.tiltShrink)
                                .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * Metrics.tiltDegrees),
                                                  axis: (x: 1, y: 0, z: 0), perspective: Metrics.tiltPerspective)
                                .opacity(1 - abs(phase.value) * Metrics.tiltFade)
                                .blur(radius: reduceMotion ? 0 : abs(phase.value) * Metrics.tiltBlur)
                        }
                        .id(scan.persistentModelID)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xs)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID, anchor: .center)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Metrics.stackBottomMargin, for: .scrollContent)
        .sensoryFeedback(Haptic.scrub, trigger: focusedID)
        .onHill()
    }

    @ViewBuilder private func card(_ scan: ScanSession) -> some View {
        let isPicked = picked.contains(scan)
        let policy = access?.policy ?? AccessPolicy(hasFullAccess: true)
        if !policy.canOpenScan(atPosition: scans.firstIndex(of: scan) ?? 0) {
            Button { paywall = .history } label: {
                SkinCard(session: scan, size: .deck)
                    .overlay { LockedCardCover().padding(.bottom, Chunk.depth) }
            }
            .buttonStyle(.bouncy(Metrics.pressScale))
            .accessibilityHint("Opens Skinalyze Pro")
            .accessibilityIdentifier("lockedScan")
        } else if isPicking {
            Button { toggle(scan) } label: {
                SkinCard(session: scan, size: .deck)
                    .overlay(alignment: .topTrailing) { pickMark(isPicked) }
                    .scaleEffect(isPicked ? Metrics.pickedScale : 1)
                    .dsAnimation(.bouncy, value: isPicked)
            }
            .buttonStyle(.bouncy(Metrics.pressScale))
            .sensoryFeedback(Haptic.toggle, trigger: isPicked)
        } else {
            NavigationLink(value: scan) {
                SkinCard(session: scan, size: .deck)
                    .overlay(alignment: .topTrailing) { delta(for: scan) }
            }
            .buttonStyle(.bouncy(Metrics.pressScale))
            .contextMenu {
                Button("Delete scan", systemImage: "trash", role: .destructive) {
                    AppPersistence.delete(scan, in: modelContext)
                }
            }
        }
    }

    private func pickMark(_ isPicked: Bool) -> some View {
        Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
            .font(.largeTitle.weight(.bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(isPicked ? Color.ds.surface : Color.ds.ink, isPicked ? Color.ds.positive : Color.ds.ink)
            .background(Circle().fill(Color.ds.surface).padding(Spacing.xxs / 2))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: isPicked)
            .padding(SkinCard.panelInset + Spacing.sm)
    }

    @ViewBuilder private func delta(for scan: ScanSession) -> some View {
        if let previous = scans.first(where: { $0.createdAt < scan.createdAt }) {
            DeltaBadge(delta: scan.breakoutIndex - previous.breakoutIndex)
                .font(.headline)
                .padding(Spacing.xxs)
                .background(Capsule().fill(Color.ds.surface))
                .padding(SkinCard.panelInset + Spacing.sm)
        }
    }

    /// Compare is the one filled action. While picking: Cancel beside "Compare these two".
    @ViewBuilder private var compareBar: some View {
        if scans.count >= 2 {
            HStack(spacing: Spacing.sm) {
                if isPicking {
                    Button("Cancel", action: togglePicking)
                        .buttonStyle(.chunky(.plain, fullWidth: false, minHeight: Chunk.controlHeight))
                        .transition(.scale.combined(with: .opacity))
                    Button {
                        let sorted = picked.sorted { $0.createdAt < $1.createdAt }
                        comparePair = .init(earlier: sorted[0], later: sorted[1])
                        isPicking = false
                        picked = []
                    } label: {
                        Text(picked.count == 2 ? "Compare these two" : "Pick \(2 - picked.count) more")
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.chunky)
                    .disabled(picked.count != 2)
                } else {
                    Button("Compare", action: togglePicking)
                        .buttonStyle(.chunky)
                        .coachTarget(.deckCompare)
                }
            }
            .frame(maxWidth: Metrics.cardMaxWidth)
            .frame(maxWidth: .infinity)
            .onHill()
        }
    }

    private var empty: some View {
        VStack(spacing: Spacing.lg) {
            Text("Your deck starts with one scan")
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
            Pimpi(mood: .curious)
                .frame(maxWidth: Metrics.emptyPimpi, maxHeight: Metrics.emptyPimpi)
            Button { appModel.startScan() } label: {
                Label("Scan my skin", systemImage: "faceid")
            }
            .buttonStyle(.chunky)
            .frame(maxWidth: Metrics.sideColumnWidth)
            .onHill()
        }
        .padding(Spacing.xl)
        .padding(.bottom, isWide ? 0 : Metrics.dockClearance)
        .popIn()
    }

    private func togglePicking() {
        withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) {
            isPicking.toggle()
            picked = []
        }
    }

    private func toggle(_ scan: ScanSession) {
        withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) {
            if let index = picked.firstIndex(of: scan) {
                picked.remove(at: index)
            } else {
                if picked.count == 2 { picked.removeFirst() } // a third pick replaces the oldest
                picked.append(scan)
            }
        }
    }
}

/// Thin ink breakout-index line; the card in focus is a band-coloured dot riding on it.
private struct DeckTrendLine: View {
    let scans: [ScanSession]
    let focusedID: PersistentIdentifier?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let line: CGFloat = 3
        static let dot: CGFloat = 18
        static let dotRing: CGFloat = 3
    }

    private var points: [ScanSession] { scans.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        Chart {
            ForEach(points) { scan in
                LineMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: Metrics.line, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.ds.ink)
            }
            // One dot that slides along the line to the card in focus.
            if let focus = points.first(where: { $0.persistentModelID == focusedID }) ?? points.last {
                PointMark(x: .value("Date", focus.createdAt), y: .value("Index", focus.breakoutIndex))
                    .symbol {
                        Circle()
                            .fill(Color.ds.band(focus.band))
                            .stroke(Color.ds.ink, lineWidth: Metrics.dotRing)
                            .frame(width: Metrics.dot, height: Metrics.dot)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(Metrics.dot / 2)
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: focusedID)
        .accessibilityLabel("Breakout index over time")
        .accessibilityValue(Text(points.map { "\($0.breakoutIndex)" }.joined(separator: ", ")))
    }
}

