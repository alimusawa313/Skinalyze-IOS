import SwiftData
import SwiftUI
import SkinalyzeKit

/// One scan: the breakout index and your 3D scan (or photo) on the sky, and on the hill Pimpi with three swipeable
/// chapters — What changed · What we noticed · What helps. Saved results are never re-analyzed.
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
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse) private var allScans: [ScanSession]
    @Environment(ShelfToolsModel.self) private var tools: ShelfToolsModel?
    @Environment(RoutineModel.self) private var routine: RoutineModel?
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?
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
    @State private var facing = Face3DView.Facing.front
    @State private var stickerArt: StickerArt?
    @State private var stickerSlapped = false
    /// Times Pimpi was poked (a new line each time).
    @State private var pokes = 0
    /// Pimpi hops whenever you poke it or do something on the screen (switch chapter, flip the 3D view).
    @State private var hops = 0
    @Namespace private var chapterPill
    @ScaledMetric(relativeTo: .largeTitle) private var indexSize: CGFloat = 104

    private enum Metrics {
        static let pimpi: CGFloat = 96
        static let pimpiSmall: CGFloat = 76
        /// Room for Pimpi's handwritten line beside the index.
        static let cheerWidth: CGFloat = 110
        static let handwritingTilt: Double = -6
        /// How far the hill rises behind the last thing on the sky.
        static let hillOverlap: CGFloat = 50
        /// The white sticker edge around the photo.
        static let photoBorder: CGFloat = 6
        static let sticker: CGFloat = 132
        static let stickerBorder: CGFloat = 7
        static let stickerTilt: Double = -5
        /// Where the sticker starts before it slaps on.
        static let slapScale: CGFloat = 1.9
        static let slapTilt: Double = -22
        static let pillHeight: CGFloat = 34
        static let pillTint: Double = 0.18
        static let zoneDot: CGFloat = 10
        static let glyphBadge: CGFloat = 40
        static let tabSpacing: CGFloat = 2
        static let tabPressedScale: CGFloat = 0.94
        static let swipeDistance: CGFloat = 30
        static let indexDelay = 0.2
        static let indexMinimumScale: CGFloat = 0.5
        static let heroEntryScale: CGFloat = 0.85
        static let minimumStreak = 2
        static let pimpiPressedScale: CGFloat = 0.9
        /// Pimpi's hop: squashed, stretched, settled.
        static let hopSquash: CGFloat = 0.86
        static let hopStretch: CGFloat = 1.08
        static let hopSquashSeconds = 0.08
        static let hopStretchSeconds = 0.18
        static let hopSettleSeconds = 0.32
        /// The tour waits for the sticker to slap on.
        static let tourDelay = 2.2
    }

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
                    .coachTarget(.resultChapters)
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
            .scrollingHill(overlap: Metrics.hillOverlap)
        }
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle(Text(session.createdAt, format: .dateTime.day().month().year()))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { shareControl }
            if !isFreshScan {
                ToolbarItem(placement: .topBarTrailing) { HideScanButton(session: session) }
            }
            if isFreshScan {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sensoryFeedback(Haptic.scrub, trigger: chapter)
        .onChange(of: shows3D) { _, _ in hops += 1 }
        .task {
            guard isFreshScan, let tools else { return }
            let earlier = allScans.filter { !$0.isDeleted && $0.modelContext != nil && $0.createdAt < session.createdAt }.reversed()
            lightingTips = await tools.lightingTips(for: session, earlier: Array(earlier))
        }
        .onAppear {
            // Opening an earlier scan (not the one just taken) is looking back.
            if !isFreshScan { quests?.did(.lookBack, isPro: policy.hasFullAccess) }
        }
        .task {
            // The first scan's result gets a four-step tour, after the sticker has slapped on.
            guard isFreshScan, FirstScanCoaching.resultTourPending else { return }
            FirstScanCoaching.resultTourPending = false
            try? await Task.sleep(for: .seconds(Metrics.tourDelay))
            tutorial?.startResultTour()
        }
        .onDisappear { if tutorial?.current?.isResultTour == true { tutorial?.skipResultTour() } }
        .coachHost(showsFreeStanding: true)
        .sheet(item: $sharedVideo) { VideoShareSheet(source: $0) }
        .paywallSheet($paywall)
        .sheet(item: $areaFollow) { AreaTimelineView(follow: $0) }
        .sheet(item: $sharedCard) { ShareCardSheet(source: $0) }
        .sheet(isPresented: $showsSources) {
            SourcesView(skinType: SkinType(stored: skinTypeRaw), patterns: SpotGuidance.patterns(for: session.counts))
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

    // MARK: Pimpi

    /// Beside the index: Pimpi celebrating that you showed up, the line in its handwriting underneath.
    private var cheeringPimpi: some View {
        VStack(spacing: Spacing.xxs) {
            pokablePimpi(size: Metrics.pimpiSmall, mood: pokeMood ?? .excited)
            effortLine
                .font(.ds.pimpiSmall)
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .rotationEffect(.degrees(Metrics.handwritingTilt))
                .contentTransition(.opacity)
                .animation(motion, value: pokes)
        }
        .frame(maxWidth: Metrics.cheerWidth)
    }

    /// Under the 3D head: Pimpi with a line about where you are looking — or, while turning is locked, about showing up.
    private var coach: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            pokablePimpi(size: Metrics.pimpi, mood: pokeMood ?? (isTurning3D ? .curious : .excited))
            SpeechBubble(isTurning3D && pokes == 0 ? Text(facing.line) : effortLine, tail: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(motion, value: facing)
                .animation(motion, value: pokes)
        }
        .sensoryFeedback(Haptic.scrub, trigger: facing)
        .onChange(of: facing) { _, _ in
            pokes = 0 // turning the head brings Pimpi back to where you are looking
            hops += 1
        }
    }

    /// Pimpi as a button: poke it for another line. It squashes and hops on every poke and whenever you do something
    /// here (Reduce Motion: it stays still and only the line changes).
    private func pokablePimpi(size: CGFloat, mood: MascotMood) -> some View {
        Button {
            pokes += 1
            hops += 1
        } label: {
            Pimpi(mood: mood)
                .frame(width: size, height: size)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: hops) { content, squash in
                    content.scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
                } keyframes: { _ in
                    if reduceMotion {
                        LinearKeyframe(1, duration: 0.01)
                    } else {
                        CubicKeyframe(Metrics.hopSquash, duration: Metrics.hopSquashSeconds)
                        SpringKeyframe(Metrics.hopStretch, duration: Metrics.hopStretchSeconds, spring: .snappy)
                        SpringKeyframe(1, duration: Metrics.hopSettleSeconds, spring: .bouncy)
                    }
                }
        }
        .buttonStyle(.bouncy(Metrics.pimpiPressedScale))
        .sensoryFeedback(Haptic.toggle, trigger: pokes)
        .accessibilityLabel(Text("Pimpi"))
        .accessibilityHint(Text("Says something else"))
    }

    /// Only while the head can actually be turned does Pimpi talk about turning it.
    private var isTurning3D: Bool { session.faceMesh != nil && policy.allows(.turn3D) }

    private var streakDays: Int { engagement?.routine.count ?? 0 }

    /// What Pimpi says when poked (from the shared pool): showing up and small habits, never how the skin looks.
    private var pokedLine: PimpiLine? {
        guard pokes > 0 else { return nil }
        return PimpiLines.shared.line(poke: pokes, place: .result, hasStreak: streakDays >= PimpiLines.minimumStreakDays)
    }

    private var pokeMood: MascotMood? { pokedLine?.mood }

    /// Effort only: never the band, the index or how the skin looks.
    private var effortLine: Text {
        if let pokedLine { return Text(verbatim: pokedLine.localized) }
        if streakDays >= Metrics.minimumStreak { return Text("\(streakDays) days in a row!") }
        return Text("You showed up. That already counts.")
    }

    // MARK: Chapters

    /// The three chapters in one white capsule. Full titles where they fit, the short ones where they don't, and a
    /// column at the largest text sizes. The full title is always the accessibility label.
    private var chapterTabs: some View {
        ViewThatFits(in: .horizontal) {
            chapterRow(full: true)
            chapterRow(full: false)
            chapterColumn
        }
        .animation(motion, value: chapter)
    }

    private func chapterRow(full: Bool) -> some View {
        HStack(spacing: Metrics.tabSpacing) {
            ForEach(Chapter.allCases) { chapterButton($0, title: full ? $0.title : $0.tab) }
        }
        .padding(Spacing.xxs)
        .dsSurface(radius: Chunk.controlHeight / 2)
    }

    private var chapterColumn: some View {
        VStack(spacing: Metrics.tabSpacing) {
            ForEach(Chapter.allCases) { chapterButton($0, title: $0.title, wraps: true) }
        }
        .padding(Spacing.xxs)
        .dsSurface(radius: Radius.medium)
    }

    private func chapterButton(_ item: Chapter, title: LocalizedStringKey, wraps: Bool = false) -> some View {
        let selected = chapter == item
        let shape = RoundedRectangle(cornerRadius: wraps ? Radius.medium - Spacing.xxs : Chunk.iconButton / 2, style: .continuous)
        return Button { go(to: item) } label: {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .lineLimit(wraps ? nil : 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: !wraps, vertical: true)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, wraps ? Spacing.xs : 0)
                .frame(maxWidth: .infinity, minHeight: Chunk.iconButton)
                .foregroundStyle(selected ? Color.ds.canvas : Color.ds.ink)
                .background {
                    if selected { shape.fill(Color.ds.ink).matchedGeometryEffect(id: "chapter", in: chapterPill) }
                }
                .contentShape(shape)
        }
        .buttonStyle(.bouncy(Metrics.tabPressedScale))
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var chapterContent: some View {
        switch chapter {
        case .changed: changedChapter
        case .noticed: noticedChapter
        case .helps: helpsChapter
        }
    }

    private var chapterSwipe: some Gesture {
        DragGesture(minimumDistance: Metrics.swipeDistance)
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
        hops += 1
    }

    // MARK: Hero (sticker and index, then the 3D scan or photo)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    deltaPill
                    Spacer(minLength: 0)
                    toggle3D
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    deltaPill
                    toggle3D
                }
            }
            if shows3D, let mesh = session.faceMesh {
                VStack(spacing: Spacing.sm) {
                    Face3DView(mesh: mesh, canTurn: policy.allows(.turn3D), onLockedTurn: { paywall = .turn3D },
                               onFacing: { facing = $0 })
                        .face3DStage()
                        .coachTarget(.resultHead)
                    Text("Drag to turn · pinch to zoom · double-tap to reset")
                        .font(.ds.footnote.weight(.semibold))
                        .foregroundStyle(Color.ds.inkSecondary)
                        .multilineTextAlignment(.center)
                    coach.padding(.top, Spacing.xs)
                    zoneChips
                }
                .transition(.scale(scale: Metrics.heroEntryScale).combined(with: .opacity))
            } else {
                if availableAngles.count > 1 {
                    PillPicker(availableAngles.map { (value: $0, title: GuidanceCopy.title(for: $0)) }, selection: $angle)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Angle")
                }
                photo
                    .coachTarget(.resultHead)
            }
            if session.captureMode == .legacy {
                Label("Saved with an earlier version — counts are shown as recorded.", systemImage: "clock.arrow.circlepath")
                    .font(.ds.footnote)
                    .foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .zIndex(1) // Pimpi and the photo stand in front of the hill that rises behind them
    }

    /// Your sticker slapped on beside the big index; Pimpi cheering at the side. Stacks when the text is too big.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.md) {
                sticker
                indexBlock
                Spacer(minLength: 0)
                if !shows3D { cheeringPimpi }
            }
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    sticker
                    Spacer(minLength: 0)
                    if !shows3D { cheeringPimpi }
                }
                indexBlock
            }
        }
    }

    /// The die-cut sticker made from this scan (the photo in a white ring until it is ready), slapped on at a tilt.
    private var sticker: some View {
        Group {
            if let stickerArt {
                StickerLayers(art: stickerArt, tilts: false)
            } else if let image = session.uiImage(at: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Metrics.sticker - Metrics.stickerBorder * 2, height: Metrics.sticker - Metrics.stickerBorder * 2)
                    .clipShape(Circle())
                    .padding(Metrics.stickerBorder)
                    .background(Circle().fill(Color.ds.surface))
            } else {
                Circle().fill(Color.ds.band(session.band))
                    .padding(Metrics.stickerBorder)
                    .background(Circle().fill(Color.ds.surface))
            }
        }
        .frame(width: Metrics.sticker, height: Metrics.sticker)
        .scaleEffect(stickerSlapped || reduceMotion ? 1 : Metrics.slapScale)
        .rotationEffect(.degrees(stickerSlapped || reduceMotion ? Metrics.stickerTilt : Metrics.slapTilt))
        .opacity(stickerSlapped ? 1 : 0)
        .task(id: session.id) {
            let art = await PortraitCutout.shared.art(for: session.id, photo: session.sortedCaptures.first?.imageData)
            withAnimation(motion) { stickerArt = art }
        }
        .onAppear {
            withAnimation(MotionToken.expressive.resolved(reduceMotion: reduceMotion).animation) { stickerSlapped = true }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: stickerSlapped) { _, slapped in slapped }
        .accessibilityHidden(true)
    }

    /// The breakout index, huge, with its band and its name.
    private var indexBlock: some View {
        indexContent.coachTarget(.resultIndex)
    }

    private var indexContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(shownIndex, format: .number)
                .font(.system(size: indexSize, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.ds.ink)
                .contentTransition(.numericText(value: Double(shownIndex)))
                .lineLimit(1)
                .minimumScaleFactor(Metrics.indexMinimumScale)
                .onAppear { withAnimation(motion.delay(Metrics.indexDelay)) { shownIndex = session.breakoutIndex } }
                .sensoryFeedback(Haptic.capture, trigger: shownIndex)
            BandPill(session.band)
            Text("Breakout index").font(.ds.footnote.weight(.heavy)).foregroundStyle(Color.ds.inkSecondary)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }

    /// How the index moved since the scan before: glyph, number and words, never colour alone.
    @ViewBuilder private var deltaPill: some View {
        if let previous {
            let delta = session.breakoutIndex - previous.breakoutIndex
            let tint = delta == 0 ? Color.ds.inkSecondary : (delta < 0 ? Color.ds.positive : Color.ds.caution)
            HStack(spacing: Spacing.xxs) {
                Image(systemName: delta == 0 ? "equal" : (delta < 0 ? "arrow.down" : "arrow.up"))
                    .foregroundStyle(tint)
                if delta != 0 { Text(abs(delta), format: .number).monospacedDigit() }
                Text("vs. last scan")
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: Metrics.pillHeight)
            .background(Capsule().fill(tint.opacity(Metrics.pillTint)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(delta == 0
                ? Text("No change") + Text(verbatim: ", ") + Text("vs. last scan")
                : Text("\(abs(delta)) \(delta < 0 ? "fewer" : "more")") + Text(verbatim: " ") + Text("vs. last scan"))
        }
    }

    /// Scans with a 3D head switch between it and the photos: ink-filled while the head is showing.
    @ViewBuilder private var toggle3D: some View {
        if session.faceMesh != nil {
            Toggle(isOn: $shows3D.animation(motion)) { Label("3D view", systemImage: "cube.transparent") }
                .toggleStyle(.button)
                .buttonStyle(.chunky(shows3D ? .filled : .plain, fullWidth: false))
                .accessibilityIdentifier("toggle3D")
        }
    }

    /// The zones where something was marked, as resting pills under the head.
    @ViewBuilder private var zoneChips: some View {
        let zones = FaceZone.allCases.filter { session.zoneIndex($0) > 0 }
        if session.hasZoneData, !zones.isEmpty {
            WrapLayout(spacing: Spacing.xs) {
                ForEach(zones, id: \.self) { zone in
                    HStack(spacing: Spacing.xs) {
                        Circle().fill(Color.ds.signal).frame(width: Metrics.zoneDot, height: Metrics.zoneDot)
                        Text(GuidanceCopy.zoneName(zone)) + Text(verbatim: " ") + Text(session.zoneIndex(zone), format: .number)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: Metrics.pillHeight)
                    .background(Capsule().fill(Color.ds.surface))
                    .background(Capsule().fill(Color.ds.edge).offset(y: Chunk.depthSmall))
                    .padding(.bottom, Chunk.depthSmall)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The photo as a sticker: a white edge all round, pins on top.
    @ViewBuilder private var photo: some View {
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
                .padding(Metrics.photoBorder)
                .dsSurface(radius: Radius.large)
                .id(angle)
                .transition(.opacity)
        }
    }

    private var availableAngles: [CaptureAngle] {
        let angles = session.sortedCaptures.map(\.angle)
        return angles.isEmpty ? [.front] : angles
    }

    // MARK: What changed

    private var changedChapter: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(BandCopy.summary(session.band))
                .font(.ds.titleSmall)
                .foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
            if session.hasZoneData { zoneBars }
        }
    }

    private var zoneBars: some View {
        let maxIndex = max(FaceZone.allCases.map(session.zoneIndex).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(FaceZone.allCases.enumerated()), id: \.element) { offset, zone in
                let value = session.zoneIndex(zone)
                ZoneBar(zone: zone, count: value, fraction: Double(value) / Double(maxIndex),
                        delay: MotionToken.stagger(offset) * 2)
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
                noticedRow(type)
                    .popIn(delay: MotionToken.stagger(offset) * 2)
            }
            if session.counts.total == 0 {
                Text("Nothing stood out in this scan.").font(.ds.titleSmall).foregroundStyle(Color.ds.ink)
            }
        }
    }

    /// One kind of spot and how many: press it for what it is.
    private func noticedRow(_ type: LesionType) -> some View {
        let expanded = expandedType == type
        return Button {
            withAnimation(motion) { expandedType = expanded ? nil : type }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: LesionGlyph.symbolName(for: type))
                        .foregroundStyle(Color.ds.signal)
                        .frame(width: Metrics.glyphBadge, height: Metrics.glyphBadge)
                        .background(Circle().fill(Color.ds.surfaceRaised))
                    Text(LesionGlyph.displayName(for: type))
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.xs)
                    Text(session.counts[type], format: .number)
                        .font(.system(.title, design: .rounded).weight(.heavy).monospacedDigit())
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.heavy))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                if expanded {
                    Text(LesionGlyph.explanation(for: type))
                        .font(.ds.footnote)
                        .foregroundStyle(Color.ds.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(PressableRowStyle())
    }

    // MARK: What helps

    private var helpsChapter: some View {
        let skinType = SkinType(stored: skinTypeRaw)
        let guidance = SkinTypeGuidance.for(skinType)
        let products = session.productIDs.compactMap(ProductCatalog.shared.product(id:))
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("For \(skinType.title.lowercased()) skin")
                .font(.ds.titleSmall).foregroundStyle(Color.ds.ink).accessibilityAddTraits(.isHeader)
            HelpsTag(title: "Look for", systemImage: "checkmark.circle.fill", tint: Color.ds.positive)
            ForEach(guidance.lookFor) { IngredientRow(note: $0) }
            HelpsTag(title: "Go easy on", systemImage: "minus.circle.fill", tint: Color.ds.caution)
                .padding(.top, Spacing.xs)
            ForEach(guidance.avoid) { IngredientRow(note: $0) }
            ForEach(SpotGuidance.patterns(for: session.counts), id: \.self) { pattern in
                spotGuidance(SpotGuidance.for(pattern))
            }
            if !products.isEmpty {
                HelpsTag(title: "Using at the time", systemImage: "clock.fill", tint: Color.ds.inkSecondary)
                    .padding(.top, Spacing.xs)
                ForEach(products) { product in
                    Label {
                        VStack(alignment: .leading) {
                            Text(product.name).font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
                            Text(product.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                        }
                    } icon: {
                        Image(systemName: product.kind?.systemImage ?? "drop").foregroundStyle(Color.ds.ink)
                    }
                    .helpsRow()
                }
            }
            Button { showsSources = true } label: {
                Text("Where this comes from")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .underline()
                    .foregroundStyle(Color.ds.ink)
                    .frame(minHeight: Chunk.iconButton)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// What helps for one kind of spot this scan noticed: suggested ingredients (and which of your products have one),
    /// then everyday habits.
    @ViewBuilder private func spotGuidance(_ guidance: SpotGuidance) -> some View {
        let shelf = ProductCatalog.shared.shelf(plan: routine?.plan)
            .map { (name: $0.name, ingredients: $0.ingredientList) }
        let matches = SpotGuidance.shelfMatches(for: guidance.pattern, shelf: shelf)
        Text(guidance.title)
            .font(.ds.titleSmall).foregroundStyle(Color.ds.ink).accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.md)
        HelpsTag(title: "Look for", systemImage: "checkmark.circle.fill", tint: Color.ds.positive)
        ForEach(guidance.lookFor) { IngredientRow(note: $0) }
        if !matches.isEmpty {
            HelpsTag(title: "Already on your shelf", systemImage: "drop.fill", tint: Color.ds.signal)
                .padding(.top, Spacing.xs)
            ForEach(matches, id: \.self) { match in
                IngredientRow(note: IngredientNote(name: match.product, note: String(localized: "Has \(match.ingredient)")))
            }
        }
        HelpsTag(title: "Everyday habits", systemImage: "sparkles", tint: Color.ds.signal)
            .padding(.top, Spacing.xs)
        ForEach(guidance.habits, id: \.self) { habit in
            Text(habit)
                .font(.ds.callout).foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
                .helpsRow()
        }
    }

    private var disclaimer: some View {
        Text("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose. If something is painful or persistent, see a dermatologist.")
            .font(.ds.footnote.weight(.semibold))
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - The hill under a scrolling screen

/// Puts scrolling content on the hill: the crest sits just above the content and the ground runs past the screen's
/// sides and bottom, so pulling the page never shows sky underneath. `overlap` lifts the crest (behind Pimpi's feet).
private struct ScrollingHill: ViewModifier {
    let overlap: CGFloat

    private enum Metrics {
        static let rise: CGFloat = 56
        /// Room for the crest's curve before the first line of content.
        static let crestRoom = Spacing.lg
        /// Past the content's own padding and the safe area, to the screen's edges.
        static let sideBleed: CGFloat = 120
        /// Below the last line, further than a page can be pulled.
        static let depth: CGFloat = 1200
    }

    func body(content: Content) -> some View {
        content
            .padding(.top, Metrics.crestRoom)
            .onHill()
            .background(alignment: .top) {
                HillShape(crest: 0, rise: Metrics.rise)
                    .fill(Color.ds.hill)
                    .padding(.horizontal, -Metrics.sideBleed)
                    .padding(.top, -overlap)
                    .padding(.bottom, -Metrics.depth)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    /// Sits this content on the hill inside a scroll view (see `ScrollingHill`).
    func scrollingHill(overlap: CGFloat = 0) -> some View {
        modifier(ScrollingHill(overlap: overlap))
    }
}

// MARK: - Pieces

/// A row you press: the white panel sinks onto its hard edge. (The design system has this for capsules only.)
private struct PressableRowStyle: ButtonStyle {
    @Environment(\.dsGround) private var ground
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        configuration.label
            .background(shape.fill(Color.ds.surface))
            .offset(y: pressed ? Chunk.depth : 0)
            .background(shape.fill(ground == .hill ? Color.ds.edgeOnHill : Color.ds.edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(shape)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

/// "Look for" / "Go easy on": a glyph and a word, never colour alone.
private struct HelpsTag: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title).foregroundStyle(Color.ds.ink)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
        .font(.system(.footnote, design: .rounded).weight(.heavy))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(Capsule().fill(Color.ds.surface))
        .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    /// A resting white row on the hill.
    func helpsRow() -> some View {
        padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface(radius: Radius.medium)
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

    private enum Metrics {
        static let lineGap: CGFloat = 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.lineGap) {
            Text(note.name).font(.system(.callout, design: .rounded).weight(.heavy)).foregroundStyle(Color.ds.ink)
            Text(note.note).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        }
        .helpsRow()
        .accessibilityElement(children: .combine)
    }
}

struct SourcesView: View {
    let skinType: SkinType
    /// What the scan noticed: their sources are listed too.
    var patterns: [SpotGuidance.Pattern] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ingredient suggestions are general information from these sources, not medical advice.")
                        .font(.ds.footnote)
                        .foregroundStyle(Color.ds.ink)
                }
                .listRowBackground(Color.ds.surface)
                Section("Sources") {
                    ForEach(sources) { source in
                        if let url = URL(string: source.url) {
                            Link(source.title, destination: url)
                        }
                    }
                }
                .listRowBackground(Color.ds.surface)
            }
            .scrollContentBackground(.hidden)
            .tint(Color.ds.signal)
            .dsCanvas()
            .navigationTitle("Sources")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    /// Skin-type sources, then the spot sources, each listed once.
    private var sources: [Citation] {
        var seen = Set<String>()
        return (SkinTypeGuidance.for(skinType).sources + patterns.flatMap { SpotGuidance.for($0).sources })
            .filter { seen.insert($0.url).inserted }
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
                Text(Self.text(tip)).font(.ds.footnote).foregroundStyle(Color.ds.ink).fixedSize(horizontal: false, vertical: true)
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
