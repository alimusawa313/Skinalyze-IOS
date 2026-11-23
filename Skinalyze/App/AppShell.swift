import SwiftData
import SwiftUI
import SkinalyzeKit

/// V2 shell: no tab bar. Mirror is home; a floating Liquid Glass dock moves between Mirror · Deck · Shelf.
struct AppShell: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var capture = ScanCaptureModel()
    @State private var isKeyboardVisible = false
    @State private var engagement = EngagementModel()
    @State private var quests = QuestModel()
    @State private var school = SchoolModel()
    @State private var challenges = ChallengeModel()
    @State private var social = SocialModel()
    @State private var shelfTools = ShelfToolsModel()
    @State private var routine = RoutineModel()
    @State private var journal = JournalModel()
    @State private var uv = UVModel()
    /// Synced streaks and rewards; changes here come from the user's other devices (or a restore).
    @Query private var engagementRecords: [EngagementRecord]
    @Environment(\.scenePhase) private var scenePhase
    @State private var paywall: PaywallReason?
    @Environment(ProAccess.self) private var access: ProAccess?
    #if DEBUG
    @State private var showsPimpiGallery = UserDefaults.standard.bool(forKey: "pimpiGallery")
    @State private var showsPimpiWidgetGallery = UserDefaults.standard.bool(forKey: "pimpiWidgetGallery")
    @State private var showsPimpiMotionLab = UserDefaults.standard.bool(forKey: "pimpiMotionLab")
    @State private var showsZoneMapDebug = false
    #endif

    var body: some View {
        @Bindable var appModel = appModel
        ZStack(alignment: .bottom) {
            page
                .id(appModel.selectedTab == .search ? AppModel.Tab.products : appModel.selectedTab)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            if !appModel.isScanning, !isKeyboardVisible {
                MirrorDock(selection: $appModel.selectedTab)
                    .padding(.bottom, Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: appModel.selectedTab)
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: appModel.isScanning)
        .onChange(of: appModel.selectedTab) { _, tab in capture.setMirrorVisible(tab == .today) }
        // The dock steps aside while typing so it never covers search results.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: isKeyboardVisible)
        .sheet(item: $appModel.presentedScan, onDismiss: offerProAfterFirstScan) { presented in
            NavigationStack {
                if let session = modelContext.model(for: presented.id) as? ScanSession {
                    ScanResultView(session: session, isFreshScan: true)
                }
            }
        }
        .sheet(isPresented: $appModel.isShowingProfile) { ProfileView() }
        .sheet(item: $challenges.justFinished) { ChallengeFinishedView(challenge: $0) }
        .sheet(item: $appModel.pendingInvite) { InviteView(inviter: $0) }
        .sheet(item: $appModel.sharedShelf) { SharedShelfView(productIDs: $0.productIDs) }
        .paywallSheet($paywall)
        .environment(engagement)
        .environment(quests)
        .environment(school)
        .environment(challenges)
        .environment(social)
        .environment(shelfTools)
        .environment(routine)
        .environment(journal)
        .environment(uv)
        .environment(\.pimpiOutfit, quests.ledger.worn)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                prepareQuests()
                publishSocial()
                Task { await uv.refresh() }
            }
            if phase == .active || phase == .background { syncEngagement() }
        }
        .onChange(of: engagementRecords.map(\.updatedAt)) { syncEngagement() }
        #if DEBUG
        .fullScreenCover(isPresented: $showsPimpiGallery) { PimpiGallery() }
        .fullScreenCover(isPresented: $showsPimpiWidgetGallery) { PimpiWidgetGallery() }
        .fullScreenCover(isPresented: $showsPimpiMotionLab) { PimpiMotionLab() }
        .sheet(isPresented: $showsZoneMapDebug) { ZoneMapView() }
        #endif
        .onOpenURL { appModel.open($0) }
        #if DEBUG
        .onAppear {
            if let tab = UserDefaults.standard.string(forKey: "startTab"), let url = URL(string: "skinalyze://\(tab)") {
                appModel.open(url)
            }
            // `-pimpiGalleryDump <file.png>`: every mood and outfit, light and dark, rendered to an image.
            if let path = UserDefaults.standard.string(forKey: "pimpiGalleryDump") {
                let renderer = ImageRenderer(content: PimpiGallery().frame(width: 402, height: 874))
                renderer.scale = 2
                try? renderer.uiImage?.pngData()?.write(to: URL(fileURLWithPath: path))
            }
            // `-shareCardDump <folder>`: export every share card in every shape for checking.
            if let folder = UserDefaults.standard.string(forKey: "shareCardDump") {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    let descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                    await ShareCardDump.run(into: folder, scans: (try? modelContext.fetch(descriptor)) ?? [])
                }
            }
            // `-reelDump <folder>`: export the glow-up reel (and the face-hidden one) for frame-by-frame checking.
            if let folder = UserDefaults.standard.string(forKey: "reelDump") {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    let limit = UserDefaults.standard.integer(forKey: "reelDumpLimit")
                    var descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                    if limit > 0 { descriptor.fetchLimit = limit }
                    await ReelDump.run(into: folder, scans: (try? modelContext.fetch(descriptor)) ?? [])
                }
            }
            // `-turntableDump <folder>`: export the newest 3D scan's turntable video for frame-by-frame checking.
            if let folder = UserDefaults.standard.string(forKey: "turntableDump") {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    let descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                    let scans = (try? modelContext.fetch(descriptor)) ?? []
                    let target = URL(fileURLWithPath: folder, isDirectory: true)
                    try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                    let started = Date()
                    var note = "no scan with a 3D mesh"
                    if let input = scans.lazy.compactMap(TurntableInput.init(session:)).first {
                        do {
                            let url = try await TurntableExporter.export(input, name: "dump-turntable", progress: { _ in })
                            try? FileManager.default.removeItem(at: target.appendingPathComponent("turntable.mp4"))
                            try FileManager.default.copyItem(at: url, to: target.appendingPathComponent("turntable.mp4"))
                            note = "made in \(String(format: "%.1f", Date().timeIntervalSince(started))) s"
                        } catch {
                            note = "failed: \(error)"
                        }
                    }
                    try? note.write(to: target.appendingPathComponent("turntable.txt"), atomically: true, encoding: .utf8)
                }
            }
            // `-openZoneMap YES`: the zone map over the demo scans (renderer checks in the Simulator).
            if UserDefaults.standard.bool(forKey: "openZoneMap") {
                Task {
                    try? await Task.sleep(for: .seconds(4)) // after demo seeding
                    showsZoneMapDebug = true
                }
            }
            // `-openLatestScan YES`: present the newest scan's result (renderer checks in the Simulator).
            if UserDefaults.standard.bool(forKey: "openLatestScan") {
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    var descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                    descriptor.fetchLimit = 1
                    if let latest = try? modelContext.fetch(descriptor).first {
                        appModel.presentedScan = .init(id: latest.persistentModelID)
                    }
                }
            }
        }
        #endif
    }

    @ViewBuilder private var page: some View {
        switch appModel.selectedTab {
        case .today: MirrorView(model: capture)
        case .timeline: DeckView().accessibilityIdentifier("deckView")
        case .products, .search: ShelfView().accessibilityIdentifier("shelfView")
        }
    }

    /// Streaks and rewards through the user's own iCloud: merge, keep one copy, apply what changed.
    private func syncEngagement() {
        let sync = EngagementSync()
        let local = sync.local(rewards: quests.ledger, bestRoutineStreak: quests.bestRoutineStreak, school: school.progress,
                               challenges: challenges.book, social: social.state)
        guard let merged = sync.sync(local: local, context: modelContext) else { return }
        sync.applyStreaks(merged)
        quests.applySynced(merged)
        school.applySynced(merged.school)
        challenges.applySynced(merged.challenges)
        social.applySynced(merged.social)
        engagement.reloadFromStore()
    }

    /// Friends see today's streak and points: publish when the app comes to the front (only if the user opted in).
    private func publishSocial() {
        guard social.isSharing else { return }
        let scans = (try? modelContext.fetch(FetchDescriptor<ScanSession>())) ?? []
        let effort = SocialEffort.current(engagement: engagement, quests: quests, scans: scans)
        Task { await social.refresh(effort: effort) }
    }

    /// Today's quests come from what can actually be done today.
    private func prepareQuests() {
        let policy = access?.policy ?? AccessPolicy(hasFullAccess: true)
        let descriptor = FetchDescriptor<ScanSession>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let dates = ((try? modelContext.fetch(descriptor)) ?? []).map(\.createdAt)
        let scannedToday = dates.contains { Calendar.current.isDateInToday($0) }
        let canScan = !scannedToday && policy.scanAllowance(savedScanDates: dates, now: .now, calendar: .current) == .allowed
        quests.prepare(context: QuestContext(canScan: canScan, hasRoutine: true,
                                             canCheckProduct: ProductCheckLedger().canCheck("quest-probe", policy: policy),
                                             scanCount: dates.count,
                                             hasLesson: school.hasOpenLesson(hasFullAccess: policy.hasFullAccess)))
    }

    /// Once, when the very first scan result is closed: what Pro adds. Never before a result has been seen.
    private func offerProAfterFirstScan() {
        let shownKey = "welcomePaywallShown"
        guard let access, !access.policy.hasFullAccess, !UserDefaults.standard.bool(forKey: shownKey),
              (try? modelContext.fetchCount(FetchDescriptor<ScanSession>())) == 1 else { return }
        UserDefaults.standard.set(true, forKey: shownKey)
        paywall = .welcome
    }
}

/// Three glyphs in one glass capsule; the selection is a white pill that slides between them.
struct MirrorDock: View {
    @Binding var selection: AppModel.Tab
    @Namespace private var pill

    private struct Item: Identifiable {
        let tab: AppModel.Tab
        let title: LocalizedStringKey
        let symbol: String
        let identifier: String
        var id: String { identifier }
    }

    private let items = [
        Item(tab: .today, title: "Mirror", symbol: "faceid", identifier: "dock.mirror"),
        Item(tab: .timeline, title: "Deck", symbol: "rectangle.stack.fill", identifier: "dock.deck"),
        Item(tab: .products, title: "Shelf", symbol: "drop.fill", identifier: "dock.shelf"),
    ]

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(items) { item in
                button(item)
            }
        }
        .padding(Spacing.xxs + 2)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func isSelected(_ item: Item) -> Bool {
        selection == item.tab || (item.tab == .products && selection == .search)
    }

    private func button(_ item: Item) -> some View {
        let selected = isSelected(item)
        return Button { selection = item.tab } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: item.symbol).font(.body.weight(.semibold))
                    .symbolEffect(.bounce.up, value: selected)
                if selected { Text(item.title).font(.subheadline.weight(.heavy)).fixedSize() }
            }
            .padding(.horizontal, selected ? 18 : 14)
            .frame(minHeight: 48)
            .foregroundStyle(selected ? Color.ds.canvas : Color.ds.ink)
            .background {
                if selected { Capsule().fill(Color.ds.ink).matchedGeometryEffect(id: "pill", in: pill) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier(item.identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
