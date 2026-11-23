import SwiftData
import SwiftUI
import SkinalyzeKit

/// One scan, as a card that opens into three swipeable chapters — What changed · What we noticed · What helps.
/// Your 3D scan (or photo) is the hero; saved results are never re-analyzed.
struct ScanResultView: View {
    let session: ScanSession
    var isFreshScan = false

    enum Chapter: Int, CaseIterable, Identifiable {
        case changed, noticed, helps
        var id: Int { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .changed: "What changed"
            case .noticed: "What we noticed"
            case .helps: "What helps"
            }
        }
        /// Short tab label (the full title is the accessibility label).
        var tab: LocalizedStringKey {
            switch self {
            case .changed: "Changed"
            case .noticed: "Noticed"
            case .helps: "Helps"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(EngagementModel.self) private var engagement: EngagementModel?
    @State private var sharedCard: ShareCardSource?
    @State private var sharedVideo: VideoShareSource?
    @State private var paywall: PaywallReason?
    @State private var areaFollow: AreaFollow?
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var allScans: [ScanSession]
    @Environment(ShelfToolsModel.self) private var tools: ShelfToolsModel?
    @State private var lightingTips: [LightingCoach.Tip] = []
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @State private var angle: CaptureAngle = .front
    @State private var visibleTypes = Set(LesionType.allCases)
    @State private var expandedType: LesionType?
    @State private var showsSources = false
    @State private var chapter: Chapter = .changed
    @State private var swipeForward = true
    @State private var shownIndex = 0
    @State private var shows3D: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var indexSize: CGFloat = 88

    init(session: ScanSession, isFreshScan: Bool = false) {
        self.session = session
        self.isFreshScan = isFreshScan
        _shows3D = State(initialValue: session.faceMesh != nil)
    }

    private var previous: ScanSession? {
        allScans.first { $0.createdAt < session.createdAt }
    }

    private var motion: Animation { MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation }

    var body: some View {
        AdaptivePanes {
            heroSection
        } secondary: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if isFreshScan, !lightingTips.isEmpty { LightingTipCard(tips: lightingTips) }
                chapterTabs
                chapterContent
                    .id(chapter)
                    .transition(.asymmetric(
                        insertion: .move(edge: swipeForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: swipeForward ? .leading : .trailing).combined(with: .opacity)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(chapterSwipe)
                disclaimer
            }
            .clipped()
        }
        .background(MoodBackdrop(band: session.band))
        .navigationTitle(Text(session.createdAt, format: .dateTime.day().month().year()))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { shareControl }
            if isFreshScan {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sensoryFeedback(Haptic.scrub, trigger: chapter)
        .task {
            guard isFreshScan, let tools else { return }
            let earlier = allScans.filter { !$0.isDeleted && $0.modelContext != nil && $0.createdAt < session.createdAt }.reversed()
            lightingTips = await tools.lightingTips(for: session, earlier: Array(earlier))
        }
        .onAppear {
            // Opening an earlier scan (not the one just taken) is looking back.
            if !isFreshScan { quests?.did(.lookBack, isPro: policy.hasFullAccess) }
        }
        .sheet(item: $sharedVideo) { VideoShareSheet(source: $0) }
        .paywallSheet($paywall)
        .sheet(item: $areaFollow) { AreaTimelineView(follow: $0) }
        .sheet(item: $sharedCard) { ShareCardSheet(source: $0) }
        .sheet(isPresented: $showsSources) {
            SourcesView(skinType: SkinType(stored: skinTypeRaw))
        }
    }

    // MARK: Sharing

    private var policy: AccessPolicy { access?.policy ?? AccessPolicy(hasFullAccess: true) }

    /// Scans with a 3D head offer the turntable video as well as the card; others share the card directly.
    /// The skin card as a picture or a shimmering video, and the 3D turntable when there is a 3D head.
    private var shareControl: some View {
        Menu {
            Button("Skin card", systemImage: "rectangle.portrait") { shareCard() }
            Button("Shimmer video", systemImage: "sparkles.rectangle.stack") {
                sharedVideo = .shimmer(session, streakDays: engagement?.routine.count ?? 0)
            }
            if session.faceMesh != nil {
                Button("3D turntable", systemImage: "rotate.3d") {
                    if policy.allows(.turntableExport) {
                        sharedVideo = TurntableInput(session: session).map(VideoShareSource.turntable)
                    } else {
                        paywall = .turntable
                    }
                }
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("shareCard")
    }

    private func shareCard() {
        sharedCard = .skin(session, streakDays: engagement?.routine.count ?? 0)
    }

    // MARK: Chapters

    private var chapterTabs: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(Chapter.allCases) { item in
                Button { go(to: item) } label: {
                    Text(item.tab)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.sm)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(chapter == item ? Color.ds.canvas : Color.ds.ink)
                        .background { if chapter == item { Capsule().fill(Color.ds.ink) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.bouncy(0.94))
                .accessibilityLabel(Text(item.title))
                .accessibilityAddTraits(chapter == item ? .isSelected : [])
            }
        }
        .padding(Spacing.xxs)
        .glassEffect(.regular, in: Capsule())
        .animation(motion, value: chapter)
    }

    @ViewBuilder private var chapterContent: some View {
        switch chapter {
        case .changed: changedChapter
        case .noticed: noticedChapter
        case .helps: helpsChapter
        }
    }

    private var chapterSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let step = value.translation.width < 0 ? 1 : -1
                if let next = Chapter(rawValue: chapter.rawValue + step) { go(to: next) }
            }
    }

    private func go(to next: Chapter) {
        guard next != chapter else { return }
        swipeForward = next.rawValue > chapter.rawValue
        withAnimation(motion) { chapter = next }
    }

    // MARK: Hero (3D scan or photo)

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            if session.faceMesh != nil {
                Toggle(isOn: $shows3D.animation(motion)) { Label("3D view", systemImage: "cube.transparent") }
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
            }
            if shows3D, let mesh = session.faceMesh {
                Face3DView(mesh: mesh, canTurn: policy.allows(.turn3D), onLockedTurn: { paywall = .turn3D })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                Text("Drag to turn · pinch to zoom · double-tap to reset")
                    .font(.ds.caption).foregroundStyle(.secondary)
            } else {
                Picker("Angle", selection: $angle.animation(motion)) {
                    ForEach(availableAngles, id: \.self) { Text(GuidanceCopy.title(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                if let image = session.uiImage(at: availableAngles.firstIndex(of: angle) ?? 0) {
                    ScanPhotoView(image: image, detections: session.detections(for: angle, types: visibleTypes),
                                  onFollow: { detection in
                                      if policy.allows(.areaHistory) {
                                          areaFollow = AreaFollow(sessionID: session.id, angle: angle,
                                                                  centre: CGPoint(x: detection.box.center.x, y: detection.box.center.y))
                                      } else {
                                          paywall = .areaHistory
                                      }
                                  })
                        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                        .id(angle)
                        .transition(.opacity)
                }
            }
            if session.captureMode == .legacy {
                Label("Saved with an earlier version — counts are shown as recorded.", systemImage: "clock.arrow.circlepath")
                    .font(.ds.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var availableAngles: [CaptureAngle] {
        let angles = session.sortedCaptures.map(\.angle)
        return angles.isEmpty ? [.front] : angles
    }

    // MARK: What changed

    private var changedChapter: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                Text(shownIndex, format: .number)
                    .font(.system(size: indexSize, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(shownIndex)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .onAppear { withAnimation(motion.delay(0.2)) { shownIndex = session.breakoutIndex } }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    BandPill(session.band)
                    Text("Breakout index").font(.ds.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let previous {
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        DeltaBadge(delta: session.breakoutIndex - previous.breakoutIndex)
                        Text("vs. last scan").font(.ds.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            Text(BandCopy.summary(session.band)).font(.ds.title)
            if session.hasZoneData { zoneBars }
        }
    }

    private var zoneBars: some View {
        let maxIndex = max(FaceZone.allCases.map(session.zoneIndex).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(FaceZone.allCases.enumerated()), id: \.element) { offset, zone in
                let value = session.zoneIndex(zone)
                HStack(spacing: Spacing.sm) {
                    Text(GuidanceCopy.zoneName(zone)).font(.ds.callout.weight(.semibold)).frame(minWidth: 96, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(Color.ds.ink.opacity(0.1))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.ds.band(BreakoutBand.classify(index: value)))
                                    .frame(width: proxy.size.width * CGFloat(value) / CGFloat(maxIndex))
                            }
                    }
                    .frame(height: 12)
                    Text(value, format: .number).font(.ds.callout.monospacedDigit()).frame(minWidth: 28, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .popIn(delay: MotionToken.stagger(offset) * 2)
            }
        }
    }

    // MARK: What we noticed

    private var noticedChapter: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(LesionType.allCases, id: \.self) { type in
                        Chip(LesionGlyph.displayName(for: type), systemImage: LesionGlyph.symbolName(for: type),
                             isSelected: visibleTypes.contains(type)) {
                            withAnimation(motion) { visibleTypes.formSymmetricDifference([type]) }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            ForEach(Array(LesionType.allCases.filter { session.counts[$0] > 0 }.enumerated()), id: \.element) { offset, type in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedType == type },
                    set: { open in withAnimation(motion) { expandedType = open ? type : nil } }
                )) {
                    Text(LesionGlyph.explanation(for: type))
                        .font(.ds.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Image(systemName: LesionGlyph.symbolName(for: type)).foregroundStyle(Color.ds.signal)
                        Text(LesionGlyph.displayName(for: type)).font(.ds.headline)
                        Spacer()
                        Text(session.counts[type], format: .number)
                            .font(.system(.title, design: .rounded).weight(.heavy).monospacedDigit())
                    }
                }
                .tint(.secondary)
                .popIn(delay: MotionToken.stagger(offset) * 2)
            }
            if session.counts.total == 0 {
                Text("Nothing stood out in this scan.").font(.ds.title)
            }
        }
    }

    // MARK: What helps

    private var helpsChapter: some View {
        let skinType = SkinType(stored: skinTypeRaw)
        let guidance = SkinTypeGuidance.for(skinType)
        let products = session.productIDs.compactMap(ProductCatalog.shared.product(id:))
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("For \(skinType.title.lowercased()) skin").font(.ds.title).accessibilityAddTraits(.isHeader)
            Text("Look for").font(.ds.label).foregroundStyle(Color.ds.positive)
            ForEach(guidance.lookFor) { IngredientRow(note: $0) }
            Text("Go easy on").font(.ds.label).foregroundStyle(Color.ds.caution)
            ForEach(guidance.avoid) { IngredientRow(note: $0) }
            if !products.isEmpty {
                Text("Using at the time").font(.ds.label).foregroundStyle(.secondary)
                ForEach(products) { product in
                    Label {
                        VStack(alignment: .leading) {
                            Text(product.name).font(.ds.callout)
                            Text(product.brand).font(.ds.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: product.slot?.systemImage ?? "drop")
                    }
                }
            }
            Button("Where this comes from") { showsSources = true }
                .font(.subheadline.weight(.semibold))
        }
    }

    private var disclaimer: some View {
        Text("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose. If something is painful or persistent, see a dermatologist.")
            .font(.ds.footnote)
            .foregroundStyle(.tertiary)
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title).font(.ds.titleSmall).foregroundStyle(Color.ds.ink).accessibilityAddTraits(.isHeader)
    }
}

private struct IngredientRow: View {
    let note: IngredientNote

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.name).font(.ds.callout.weight(.semibold))
            Text(note.note).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SourcesView: View {
    let skinType: SkinType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ingredient suggestions are general information from these sources, not medical advice.")
                        .font(.ds.footnote)
                }
                Section("Sources") {
                    ForEach(SkinTypeGuidance.for(skinType).sources) { source in
                        if let url = URL(string: source.url) {
                            Link(source.title, destination: url)
                        }
                    }
                }
            }
            .navigationTitle("Sources")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

/// Scan-quality coach (P12): light that differs from usual makes scans harder to compare.
struct LightingTipCard: View {
    let tips: [LightingCoach.Tip]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label("Tip for next time", systemImage: "lightbulb.fill").font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.caution)
            ForEach(tips, id: \.self) { tip in
                Text(Self.text(tip)).font(.ds.footnote).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lightingTip")
    }

    static func text(_ tip: LightingCoach.Tip) -> String {
        switch tip {
        case .tooDark: String(localized: "This scan was darker than usual. Face a window or a bright lamp, like last time.")
        case .tooBright: String(localized: "This scan was brighter than usual. Step out of direct sun so the light is even.")
        case .warmerThanUsual: String(localized: "The light was warmer (more yellow) than usual. Scanning in the same spot keeps scans comparable.")
        case .coolerThanUsual: String(localized: "The light was cooler (more blue) than usual. Scanning in the same spot keeps scans comparable.")
        }
    }
}
