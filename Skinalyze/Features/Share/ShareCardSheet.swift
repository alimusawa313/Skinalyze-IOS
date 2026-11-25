import SwiftData
import SwiftUI
import SkinalyzeKit

/// Something that can be shared as a card: how to build its picture, and whether a face is involved.
struct ShareCardSource: Identifiable {
    let id = UUID()
    let fileName: String
    let offersHideFace: Bool
    let content: @MainActor (_ hidesFace: Bool) async -> ShareCardContent?
}

extension ShareCardSource {
    @MainActor
    static func skin(_ session: ScanSession, streakDays: Int) -> ShareCardSource {
        let id = session.id, photo = session.sortedCaptures.first?.imageData
        let index = session.breakoutIndex, band = session.band, date = session.createdAt
        return ShareCardSource(fileName: "skinalyze-card", offersHideFace: true) { hidesFace in
            let art = await PortraitCutout.shared.art(for: id, photo: photo)
            return .skin(SkinShare(index: index, band: band, date: date,
                                   portrait: SharePortrait.make(from: art, hidesFace: hidesFace), streakDays: streakDays))
        }
    }

    static func verdict(product: CatalogProduct, result: VerdictResult) -> ShareCardSource {
        ShareCardSource(fileName: "skinalyze-product", offersHideFace: false) { _ in
            .verdict(VerdictShare(brand: product.brand, name: product.name, result: result))
        }
    }

    /// The photos are the eye-aligned ones Compare is already showing.
    @MainActor
    static func compare(earlier: ScanSession, later: ScanSession, earlierPhoto: UIImage, laterPhoto: UIImage) -> ShareCardSource {
        let share = CompareShare(earlier: earlierPhoto, later: laterPhoto, earlierDate: earlier.createdAt, laterDate: later.createdAt,
                                 earlierIndex: earlier.breakoutIndex, laterIndex: later.breakoutIndex)
        return ShareCardSource(fileName: "skinalyze-compare", offersHideFace: false) { _ in .compare(share) }
    }

    static func streak(days: Int) -> ShareCardSource {
        ShareCardSource(fileName: "skinalyze-streak", offersHideFace: false) { _ in .streak(days: days) }
    }

    /// Effort numbers only — no photo, no skin result.
    static func recap(period: RecapPeriod, recap: Recap) -> ShareCardSource {
        let cheer = RecapEngine.cheer(for: recap)
        let share = RecapShare(title: RecapCopy.title(period), dates: RecapCopy.dates(period), cheer: RecapCopy.cheer(cheer),
                               mood: RecapCopy.mood(cheer), tiles: RecapTile.tiles(recap))
        return ShareCardSource(fileName: "skinalyze-recap", offersHideFace: false) { _ in .recap(share) }
    }

    static func challenge(_ challenge: Challenge) -> ShareCardSource {
        let share = ChallengeShare(kind: challenge.kind, finished: challenge.finished?.date(in: .current) ?? .now)
        return ShareCardSource(fileName: "skinalyze-challenge", offersHideFace: false) { _ in .challenge(share) }
    }
}

/// Preview, shape, "hide my face", then the system share sheet. The face choice is made fresh on every share and
/// the Share button only ever hands over the picture currently shown. The card sits on the sky with a white edge;
/// the choices and the Share button stand on the hill.
struct ShareCardSheet: View {
    let source: ShareCardSource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @State private var format = ShareCardFormat.story
    @State private var hidesFace = false
    @State private var rendered: Rendered?
    /// The picture shown last, kept (blurred, never shareable) while the next one is made.
    @State private var lastImage: UIImage?
    @State private var failed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Rendered {
        let image: UIImage
        let url: URL
    }

    private struct RenderKey: Hashable {
        let format: ShareCardFormat
        let hidesFace: Bool
    }

    var body: some View {
        NavigationStack {
            Group {
                // Landscape (and iPhone Duo closed, landscape): the card beside the controls instead of above them.
                if verticalSizeClass == .compact {
                    HStack(spacing: Spacing.lg) {
                        preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                        ScrollView { controls.padding(.vertical, Spacing.md) }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(maxWidth: ShareSheetMetrics.controlsWidth)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .dsHill(crest: ShareSheetMetrics.wideCrest, rise: ShareSheetMetrics.hillRise)
                } else {
                    VStack(spacing: 0) {
                        preview
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls.shareSheetHill()
                    }
                    .background(Color.ds.canvas.ignoresSafeArea())
                }
            }
            .navigationTitle("Share")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .task(id: RenderKey(format: format, hidesFace: hidesFace)) { await render() }
        .sensoryFeedback(Haptic.toggle, trigger: hidesFace)
        .sensoryFeedback(Haptic.success, trigger: rendered?.url) { _, url in url != nil }
    }

    /// The card itself, with a white edge and a slight tilt, like a sticker laid down. Changing the shape springs the
    /// card to its new proportions; while the new picture is made the last one stays, blurred, and the new one fades
    /// in over it (so hiding the face melts the sticker into its outline). Only the finished picture can be shared.
    @ViewBuilder private var preview: some View {
        if failed {
            ContentUnavailableView("Couldn't make the image", systemImage: "photo.badge.exclamationmark",
                                   description: Text("Close this and try again."))
        } else {
            let size = format.pointSize
            Color.clear
                .aspectRatio(size.width / size.height, contentMode: .fit)
                .overlay {
                    if let rendered {
                        Image(uiImage: rendered.image)
                            .resizable()
                            .scaledToFill()
                            .accessibilityLabel(hidesFace ? Text("Preview of your card with your face hidden") : Text("Preview of your card"))
                            .accessibilityIdentifier("shareCardPreview")
                            .transition(.opacity)
                    } else {
                        ZStack {
                            Color.ds.surfaceRaised
                            if let lastImage {
                                Image(uiImage: lastImage)
                                    .resizable()
                                    .scaledToFill()
                                    .blur(radius: reduceMotion ? 0 : ShareSheetMetrics.pendingBlur)
                                    .opacity(ShareSheetMetrics.pendingOpacity)
                                    .accessibilityHidden(true)
                            }
                            ProgressView().tint(Color.ds.ink)
                        }
                        .transition(.opacity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .padding(ShareSheetMetrics.cardBorder)
                .dsSurface(radius: Radius.medium)
                .rotationEffect(.degrees(ShareSheetMetrics.cardTilt))
                .padding(Spacing.xs)
                .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: format)
                .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: rendered?.url)
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.md) {
            PillPicker(ShareCardFormat.allCases.map { (value: $0, title: title(for: $0)) }, selection: $format)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Shape")
            if source.offersHideFace {
                HideFaceRow(isOn: $hidesFace, identifier: "shareHideFace")
            }
            Text("Skinalyze uploads nothing. The image goes only where you send it.")
                .font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            shareButton
        }
    }

    @ViewBuilder private var shareButton: some View {
        let label = Label("Share", systemImage: "square.and.arrow.up")
        if let rendered {
            ShareLink(item: rendered.url, preview: SharePreview(Text(verbatim: "Skinalyze"), image: Image(uiImage: rendered.image))) { label }
                .simultaneousGesture(TapGesture().onEnded { quests?.did(.share, isPro: access?.policy.hasFullAccess ?? false) })
                .buttonStyle(.chunky)
                .accessibilityIdentifier("shareCardButton")
        } else {
            Button {} label: { label }
                .buttonStyle(.chunky)
                .disabled(true)
        }
    }

    private func title(for format: ShareCardFormat) -> String {
        switch format {
        case .story: String(localized: "Story")
        case .portrait: String(localized: "Post")
        case .square: String(localized: "Square")
        }
    }

    private func render() async {
        // Nothing stale may be shared: the old picture goes before the new one is made (it stays on screen, blurred).
        if let image = rendered?.image { lastImage = image }
        rendered = nil
        failed = false
        let content = await source.content(hidesFace)
        guard !Task.isCancelled else { return }
        let watermark = ShareCardPolicy.showsWatermark(isPro: access?.policy.hasFullAccess ?? false)
        guard let content, let image = ShareCardRenderer.image(of: content, format: format, showsWatermark: watermark),
              let url = ShareCardRenderer.write(image, name: "\(source.fileName)-\(format.rawValue)") else {
            failed = true
            return
        }
        rendered = Rendered(image: image, url: url)
    }
}

// MARK: - Shared pieces of the share sheets

enum ShareSheetMetrics {
    static let controlsWidth: CGFloat = 520
    static let hillRise: CGFloat = 40
    /// Where the hill starts behind a landscape share sheet, as a fraction of its height.
    static let wideCrest: CGFloat = 0.8
    /// The white edge round the card preview.
    static let cardBorder: CGFloat = 8
    static let cardTilt: Double = -3
    static let pendingBlur: CGFloat = 12
    static let pendingOpacity = 0.6
    static let lineGap: CGFloat = 2
}

/// "Hide my face" on a white row with the hard edge; the switch turns green when the face is hidden.
struct HideFaceRow: View {
    @Binding var isOn: Bool
    /// The UI tests find the switch by this.
    let identifier: String

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: ShareSheetMetrics.lineGap) {
                Text("Hide my face")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                Text("Shares your sticker's outline and numbers only.")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color.ds.positive)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .dsSurface(radius: Radius.large)
    }
}

extension View {
    /// Stands a share sheet's controls on the hill (portrait): the crest just above them, the ground to the bottom.
    func shareSheetHill() -> some View {
        padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl + Spacing.xxs)
            .padding(.bottom, Spacing.md)
            .frame(maxWidth: ShareSheetMetrics.controlsWidth)
            .frame(maxWidth: .infinity)
            .onHill()
            .background(alignment: .top) {
                HillShape(crest: 0, rise: ShareSheetMetrics.hillRise)
                    .fill(Color.ds.hill)
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
                    .accessibilityHidden(true)
            }
    }
}

/// The Share button screens put in their toolbar.
struct ShareCardButton: View {
    let source: () -> ShareCardSource?
    @State private var presented: ShareCardSource?

    var body: some View {
        Button { presented = source() } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("shareCard")
        .sheet(item: $presented) { ShareCardSheet(source: $0) }
    }
}

#if DEBUG
/// `-shareCardDump <folder>`: writes every card in every shape from the demo data, so exports can be opened and checked.
@MainActor
enum ShareCardDump {
    static func run(into folder: String, scans: [ScanSession]) async {
        var sources: [(String, ShareCardSource, Bool)] = [("streak", .streak(days: 128), false)]
        // A busy month: the most numbers a recap card has to fit.
        let calendar = Calendar.current
        let month = RecapEngine.previousMonth(now: .now, calendar: calendar)
        let days = month.days(calendar: calendar)
        let busy = ActivityHistory(routineDays: Set(days.dropLast(3)), scanDates: days.prefix(5).map { $0.date(in: calendar) },
                                   quests: Dictionary(uniqueKeysWithValues: days.map { ($0.string, Set<QuestKind>([.routine, .lesson, .share])) }))
        sources.append(("recap", .recap(period: month, recap: RecapEngine.recap(month, history: busy, calendar: calendar)), false))
        let wrapped = RecapEngine.latestWrapped(now: .now, calendar: calendar)
        sources.append(("wrapped", .recap(period: wrapped, recap: RecapEngine.recap(wrapped, history: busy, calendar: calendar)), false))
        sources.append(("shelf", .routine(productIDs: [18, 1, 40, 120]), false))
        sources.append(("challenge", .challenge(Challenge(kind: .morningAndEvening, started: days[0], finished: days[29])), false))
        var videos: [(String, VideoShareSource, Bool)] = []
        if let latest = scans.first {
            sources.append(("skin", .skin(latest, streakDays: 12), false))
            sources.append(("skin-hidden", .skin(latest, streakDays: 12), true))
            // The wordiest verdict in the first few hundred products — the hardest case for the card's text.
            let profile = VerdictProfileBuilder.make(latest: latest)
            let verdicts = ProductCatalog.shared.search("a").prefix(300).map { product in
                (product, ProductVerdictEngine.evaluate(ingredients: product.ingredientList.map { $0.lowercased() }, profile: profile))
            }
            if let (product, result) = verdicts.max(by: { $0.1.reasons.count < $1.1.reasons.count }) {
                sources.append(("verdict", .verdict(product: product, result: result), false))
            }
        }
        if scans.count > 1, let later = scans.first, let laterImage = later.uiImage(at: 0),
           let earlier = scans.last, let earlierImage = earlier.uiImage(at: 0) {
            let first = await FaceAligner.shared.aligned(earlierImage, key: "dump-earlier")?.image ?? earlierImage
            let second = await FaceAligner.shared.aligned(laterImage, key: "dump-later")?.image ?? laterImage
            sources.append(("compare", .compare(earlier: earlier, later: later, earlierPhoto: first, laterPhoto: second), false))
            videos.append(("before-after", .wipe(CompareShare(earlier: first, later: second, earlierDate: earlier.createdAt,
                                                              laterDate: later.createdAt, earlierIndex: earlier.breakoutIndex,
                                                              laterIndex: later.breakoutIndex)), false))
        }
        if let latest = scans.first {
            videos.append(("shimmer", .shimmer(latest, streakDays: 12), false))
            videos.append(("shimmer-hidden", .shimmer(latest, streakDays: 12), true))
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // The dermatologist visit pack, oldest scan first.
        let pack = await DermPackBuilder.content(scans: scans.reversed(), includePhotos: true, journal: JournalModel())
        if let url = DermPackBuilder.render(pack) {
            let target = directory.appendingPathComponent("visit-pack.pdf")
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: url, to: target)
        }
        for (name, source, hidesFace) in videos {
            guard let url = try? await source.make(hidesFace, true, { _ in }) else { continue }
            let target = directory.appendingPathComponent("\(name).mp4")
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: url, to: target)
        }
        for (name, source, hidesFace) in sources {
            guard let content = await source.content(hidesFace) else { continue }
            for format in ShareCardFormat.allCases {
                let image = ShareCardRenderer.image(of: content, format: format)
                try? image?.pngData()?.write(to: directory.appendingPathComponent("\(name)-\(format.rawValue).png"))
            }
        }
    }
}
#endif
