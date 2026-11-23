import Charts
import SwiftData
import SwiftUI
import SkinalyzeKit

/// History as a deck of skin cards you flick through. Cards tilt away in 3D as they scroll, the backdrop takes the
/// mood of the card in focus, and a glowing line on top shows the trend. "Compare" turns it into pick-two.
struct DeckView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 54

    private var focused: ScanSession? { scans.first { $0.persistentModelID == focusedID } ?? scans.first }

    var body: some View {
        NavigationStack {
            ZStack {
                MoodBackdrop(band: focused?.band ?? .calm)
                if scans.isEmpty {
                    empty
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        header
                        stack
                    }
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanSession.self) { ScanResultView(session: $0) }
            .safeAreaInset(edge: .bottom) { compareBar }
        }
        .sheet(item: $comparePair) { pair in
            NavigationStack { CompareView(earlier: pair.earlier, later: pair.later) }
        }
        .sheet(isPresented: $showsReel) { VideoShareSheet(source: .reel(scans: scans)) }
        .sheet(isPresented: $showsZoneMap) { ZoneMapView() }
        .sheet(isPresented: $showsVault) { NavigationStack { HiddenScansView() } }
        .paywallSheet($paywall)
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Deck").font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .lineLimit(1).fixedSize()
                    .accessibilityAddTraits(.isHeader)
                    // The private vault's secret way in (P13): press and hold the title.
                    .contentShape(Rectangle())
                    .simultaneousGesture(LongPressGesture(minimumDuration: 1.5).onEnded { _ in
                        if vaultSecret { showsVault = true }
                    })
                    .accessibilityActions {
                        if vaultSecret { Button("Open hidden scans") { showsVault = true } }
                    }
                    .accessibilityIdentifier("deckTitle")
                Text("\(scans.count)").font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(scans.count)))
                    .accessibilityIdentifier("deckCount")
                Spacer()
                if !isPicking {
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
                    .font(.headline)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("deckZoneMap")
                }
                if scans.count >= 2, !isPicking {
                    Button { showsReel = true } label: {
                        Label("Glow-up reel", systemImage: "film")
                    }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("deckReel")
                }
                if scans.count >= 2 {
                    Button(isPicking ? "Cancel" : "Compare") {
                        withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) {
                            isPicking.toggle()
                            picked = []
                        }
                    }
                    .font(.headline)
                    .buttonStyle(.glass)
                }
            }
            if scans.count >= 2 {
                DeckTrendLine(scans: scans, focusedID: focused?.persistentModelID)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private var stack: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Spacing.lg) {
                ForEach(scans) { scan in
                    card(scan)
                        .containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
                        .scrollTransition(.interactive, axis: .vertical) { content, phase in
                            content
                                .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.12)
                                .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * -24),
                                                  axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                                .opacity(1 - abs(phase.value) * 0.45)
                                .blur(radius: reduceMotion ? 0 : abs(phase.value) * 2)
                        }
                        .id(scan.persistentModelID)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.xl)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedID, anchor: .center)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 120, for: .scrollContent)
        .sensoryFeedback(Haptic.scrub, trigger: focusedID)
    }

    @ViewBuilder private func card(_ scan: ScanSession) -> some View {
        let isPicked = picked.contains(scan)
        let policy = access?.policy ?? AccessPolicy(hasFullAccess: true)
        if !policy.canOpenScan(atPosition: scans.firstIndex(of: scan) ?? 0) {
            Button { paywall = .history } label: {
                SkinCard(session: scan, size: .deck)
                    .overlay { LockedCardCover() }
            }
            .buttonStyle(.bouncy(0.95))
            .accessibilityHint("Opens Skinalyze Pro")
            .accessibilityIdentifier("lockedScan")
        } else if isPicking {
            Button { toggle(scan) } label: {
                SkinCard(session: scan, size: .deck)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                            .font(.largeTitle)
                            .foregroundStyle(.white, isPicked ? Color.ds.positive : Color.black.opacity(0.3))
                            .symbolEffect(.bounce, value: isPicked)
                            .padding(Spacing.md)
                    }
                    .scaleEffect(isPicked ? 0.94 : 1)
                    .dsAnimation(.bouncy, value: isPicked)
            }
            .buttonStyle(.bouncy(0.95))
            .sensoryFeedback(Haptic.toggle, trigger: isPicked)
        } else {
            NavigationLink(value: scan) {
                SkinCard(session: scan, size: .deck)
                    .overlay(alignment: .topTrailing) { delta(for: scan) }
            }
            .buttonStyle(.bouncy(0.95))
            .contextMenu {
                Button("Delete scan", systemImage: "trash", role: .destructive) {
                    AppPersistence.delete(scan, in: modelContext)
                }
            }
        }
    }

    @ViewBuilder private func delta(for scan: ScanSession) -> some View {
        if let previous = scans.first(where: { $0.createdAt < scan.createdAt }) {
            DeltaBadge(delta: scan.breakoutIndex - previous.breakoutIndex)
                .font(.headline)
                .padding(Spacing.xxs)
                .background(.black.opacity(0.6), in: Capsule())
                .environment(\.colorScheme, .dark) // bright tints on the dark chip, in both modes
                .padding(Spacing.md)
        }
    }

    @ViewBuilder private var compareBar: some View {
        if isPicking {
            Button {
                let sorted = picked.sorted { $0.createdAt < $1.createdAt }
                comparePair = .init(earlier: sorted[0], later: sorted[1])
                isPicking = false
                picked = []
            } label: {
                Text(picked.count == 2 ? "Compare these two" : "Pick \(2 - picked.count) more")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.dsPrimary)
            .disabled(picked.count != 2)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 76)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var empty: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 88, weight: .light))
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2.5)))
                .accessibilityHidden(true)
            Text("Your deck starts with one scan").font(.system(.title, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
            Button { appModel.startScan() } label: {
                Label("Scan my skin", systemImage: "faceid").frame(maxWidth: 280)
            }
            .buttonStyle(.dsPrimary)
        }
        .padding(Spacing.xl)
        .popIn()
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

/// Thin glowing breakout-index line; the card in focus is a bright dot riding on it.
private struct DeckTrendLine: View {
    let scans: [ScanSession]
    let focusedID: PersistentIdentifier?

    private var points: [ScanSession] { scans.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        Chart(points) { scan in
            LineMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(Color.ds.ink.opacity(0.85))
            if scan.persistentModelID == focusedID {
                PointMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .symbolSize(160)
                    .foregroundStyle(Color.ds.band(scan.band))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .shadow(color: Color.ds.ink.opacity(0.35), radius: 6)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: focusedID)
        .accessibilityLabel("Breakout index over time")
        .accessibilityValue(Text(points.map { "\($0.breakoutIndex)" }.joined(separator: ", ")))
    }
}

/// The canvas with a mood colour glowing through (Deck focus, scan result) — shifts smoothly when the band changes.
struct MoodBackdrop: View {
    let band: BreakoutBand

    var body: some View {
        ZStack {
            Color.ds.canvas
            RadialGradient(colors: [Color.ds.band(band).opacity(0.5), .clear], center: .center, startRadius: 20, endRadius: 520)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: band)
    }
}
