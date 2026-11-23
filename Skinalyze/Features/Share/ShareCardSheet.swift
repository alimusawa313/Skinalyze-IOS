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
/// the Share button only ever hands over the picture currently shown.
struct ShareCardSheet: View {
    let source: ShareCardSource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @State private var format = ShareCardFormat.story
    @State private var hidesFace = false
    @State private var rendered: Rendered?
    @State private var failed = false

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
            // Landscape (and iPhone Duo closed, landscape): preview beside the controls instead of above them.
            let layout = verticalSizeClass == .compact
                ? AnyLayout(HStackLayout(spacing: Spacing.lg))
                : AnyLayout(VStackLayout(spacing: Spacing.md))
            layout {
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                controls.frame(maxWidth: 520)
            }
            .padding(Spacing.md)
            .dsCanvas()
            .navigationTitle("Share")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .task(id: RenderKey(format: format, hidesFace: hidesFace)) { await render() }
    }

    @ViewBuilder private var preview: some View {
        if let rendered {
            Image(uiImage: rendered.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: Spacing.md, y: Spacing.xs)
                .accessibilityLabel(hidesFace ? Text("Preview of your card with your face hidden") : Text("Preview of your card"))
                .accessibilityIdentifier("shareCardPreview")
        } else if failed {
            ContentUnavailableView("Couldn't make the image", systemImage: "photo.badge.exclamationmark",
                                   description: Text("Close this and try again."))
        } else {
            ProgressView()
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.md) {
            Picker("Shape", selection: $format) {
                ForEach(ShareCardFormat.allCases) { Text(title(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            if source.offersHideFace {
                Toggle(isOn: $hidesFace) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide my face")
                            Text("Shares your sticker's outline and numbers only.")
                                .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        }
                    } icon: {
                        Image(systemName: "eye.slash")
                    }
                }
                .tint(Color.ds.signal)
                .accessibilityIdentifier("shareHideFace")
            }
            shareButton
            Text("Skinalyze uploads nothing. The image goes only where you send it.")
                .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var shareButton: some View {
        let label = Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
        if let rendered {
            ShareLink(item: rendered.url, preview: SharePreview(Text(verbatim: "Skinalyze"), image: Image(uiImage: rendered.image))) { label }
                .simultaneousGesture(TapGesture().onEnded { quests?.did(.share, isPro: access?.policy.hasFullAccess ?? false) })
                .buttonStyle(.dsPrimary)
                .accessibilityIdentifier("shareCardButton")
        } else {
            Button {} label: { label }
                .buttonStyle(.dsPrimary)
                .disabled(true)
        }
    }

    private func title(for format: ShareCardFormat) -> LocalizedStringKey {
        switch format {
        case .story: "Story"
        case .portrait: "Post"
        case .square: "Square"
        }
    }

    private func render() async {
        // Nothing stale may be shared: the old picture goes before the new one is made.
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
