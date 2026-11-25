import SwiftData
import SwiftUI
import SkinalyzeKit

// Weekly / monthly recaps (E12, E14) and Skin Wrapped (G6). Effort numbers only; Wrapped adds two gentle,
// good-news-only highlights worded as coincidence.

/// One number on a recap.
struct RecapTile: Hashable {
    let value: Int
    let label: String
    let symbol: String

    static func tiles(_ recap: Recap) -> [RecapTile] {
        [RecapTile(value: recap.routineDays, label: String(localized: "routine days of \(recap.dayCount)"),
                   symbol: "checklist"),
         RecapTile(value: recap.longestRun, label: String(localized: "days in a row at best"), symbol: "flame.fill"),
         RecapTile(value: recap.scans, label: String(localized: "scans taken"), symbol: "faceid"),
         RecapTile(value: recap.lessons, label: String(localized: "lessons learned"), symbol: "graduationcap.fill"),
         RecapTile(value: recap.questsDone, label: String(localized: "quests done"), symbol: "star.fill"),
         RecapTile(value: recap.points, label: String(localized: "glow points"), symbol: "sparkles")]
    }
}

/// Pimpi offering the recap that's due, on the Shelf. One at a time; closing it counts as seen.
struct RecapBanner: View {
    @Environment(QuestModel.self) private var quests
    @Query(sort: \ScanSession.createdAt) private var scans: [ScanSession]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened: RecapPeriod?
    /// Bumped when a recap is opened or dismissed, so the banner re-reads what was seen.
    @State private var seenChanges = 0

    private enum Metrics {
        static let pimpi: CGFloat = 56
    }

    private var due: RecapPeriod? {
        _ = seenChanges
        return RecapData.due(history: RecapData.history(scans: scans.filter { !$0.isDeleted }, quests: quests))
    }

    var body: some View {
        Group {
            if let due {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    Button { opened = due } label: {
                        PimpiRow(spacing: Spacing.sm) {
                            Pimpi(mood: .excited).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(RecapCopy.title(due)).font(.effortRow).foregroundStyle(Color.ds.ink)
                                Text("Pimpi made you a recap").font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(EffortRowButtonStyle(filled: false))
                    .accessibilityIdentifier("recapBanner")
                    Button {
                        RecapData.markSeen(due)
                        withDSAnimation(.smooth, reduceMotion: reduceMotion) { seenChanges += 1 }
                    } label: {
                        Image(systemName: "xmark").font(.effortNote)
                    }
                    .buttonStyle(.chunkyIcon)
                    .accessibilityLabel(Text("Not now"))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(item: $opened, onDismiss: { seenChanges += 1 }) { RecapView(period: $0) }
    }
}

/// A recap: Pimpi's line on the sky, the numbers (and, for Wrapped, the highlights) on the hill. Shareable as a card
/// without any photo.
struct RecapView: View {
    let period: RecapPeriod

    @Environment(\.dismiss) private var dismiss
    @Environment(QuestModel.self) private var quests
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    private var scans: [ScanSession] { allScans.filter { !$0.isDeleted && $0.modelContext != nil } }

    private enum Metrics {
        static let pimpi: CGFloat = 104
        static let tile: CGFloat = 150
    }

    private var recap: Recap {
        RecapEngine.recap(period, history: RecapData.history(scans: scans, quests: quests), calendar: .current)
    }

    var body: some View {
        let recap = recap
        let cheer = RecapEngine.cheer(for: recap)
        NavigationStack {
            EffortScroll {
                header(cheer: cheer)
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? EffortMetrics.readable : Metrics.tile),
                                                 spacing: Spacing.sm, alignment: .top)],
                              spacing: Spacing.sm) {
                        ForEach(Array(RecapTile.tiles(recap).enumerated()), id: \.element) { index, item in
                            tile(item).popIn(delay: MotionToken.stagger(index))
                        }
                    }
                    if RecapCopy.isWrapped(period) {
                        WrappedHighlightsView(period: period, scans: scans)
                    }
                }
            }
            .navigationTitle(RecapCopy.title(period))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareCardButton { .recap(period: period, recap: recap) }
                }
            }
        }
        .onAppear { RecapData.markSeen(period) }
    }

    /// Pimpi and its line, with the dates above.
    private func header(cheer: RecapCheer) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(RecapCopy.dates(period))
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color.ds.inkSecondary)
            PimpiRow(spacing: Spacing.xs) {
                PokablePimpi(mood: RecapCopy.mood(cheer), size: Metrics.pimpi)
                SpeechBubble(Text(RecapCopy.cheer(cheer)), tail: typeSize.isAccessibilitySize ? .up : .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func tile(_ tile: RecapTile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: tile.symbol).font(.title3.weight(.bold)).foregroundStyle(Color.ds.signal)
            Text(tile.value, format: .number)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Color.ds.ink)
            Text(tile.label).font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityElement(children: .combine)
    }
}

/// Wrapped only: an area that calmed down and the calmest month, with what was on the shelf then.
private struct WrappedHighlightsView: View {
    let period: RecapPeriod
    let scans: [ScanSession]

    var body: some View {
        let highlights = WrappedEngine.highlights(period, points: scans.map(InsightEngine.Point.init),
                                                  shelf: RecapData.shelf(), calendar: .current)
        if highlights.calmerZone != nil || highlights.calmestMonth != nil {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle("Highlights")
                if let zone = highlights.calmerZone {
                    highlight(symbol: "leaf.fill",
                              Text("Your \(GuidanceCopy.zoneName(zone).lowercased()) had fewer spots marked later on than early in this stretch."))
                }
                if let month = highlights.calmestMonth {
                    let name = month.first.date(in: .current).formatted(.dateTime.month(.wide))
                    highlight(symbol: "moon.stars.fill", Text("Your calmest month was \(name)."))
                    let products = highlights.productsThen.compactMap { ProductCatalog.shared.product(id: $0)?.name }
                    if !products.isEmpty {
                        highlight(symbol: "drop.fill",
                                  Text("On your shelf then: \(products.formatted(.list(type: .and))). They coincided with it, which doesn't mean they caused it."))
                    }
                }
                Text("Many things affect skin. These are patterns in your own scans, not advice.")
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xxs)
            }
            .accessibilityIdentifier("wrappedHighlights")
        }
    }

    private func highlight(symbol: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(Color.ds.positive).accessibilityHidden(true)
            text.font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .dsCard()
    }
}
