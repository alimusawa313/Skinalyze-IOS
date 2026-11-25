import SwiftData
import SwiftUI
import SkinalyzeKit

// P3 trigger journal and P4 Apple Health patterns. Wording is always "coincided", never "caused".

enum JournalCopy {
    static func title(_ tag: JournalTag) -> String {
        switch tag {
        case .sleptBadly: String(localized: "Slept badly")
        case .stressed: String(localized: "Stressed")
        case .sweets: String(localized: "Sweets")
        case .dairy: String(localized: "Dairy")
        case .friedFood: String(localized: "Fried food")
        case .alcohol: String(localized: "Alcohol")
        case .workout: String(localized: "Workout")
        case .period: String(localized: "Period")
        case .travel: String(localized: "Travel")
        case .newProduct: String(localized: "New product")
        case .touchedFace: String(localized: "Touched my face")
        }
    }

    static func symbol(_ tag: JournalTag) -> String {
        switch tag {
        case .sleptBadly: "moon.zzz"
        case .stressed: "bolt.heart"
        case .sweets: "birthday.cake"
        case .dairy: "cup.and.saucer"
        case .friedFood: "frying.pan"
        case .alcohol: "wineglass"
        case .workout: "figure.run"
        case .period: "drop"
        case .travel: "airplane"
        case .newProduct: "shippingbox"
        case .touchedFace: "hand.point.up.left"
        }
    }

    static func pattern(_ pattern: TriggerPattern) -> String {
        let name = title(pattern.tag).lowercased()
        let with = Int(pattern.withTag.rounded()), without = Int(pattern.withoutTag.rounded())
        return pattern.direction == .more
            ? String(localized: "Scans after \"\(name)\" days had more marked (typically \(with) vs \(without)).")
            : String(localized: "Scans after \"\(name)\" days had fewer marked (typically \(with) vs \(without)).")
    }
}

/// On the Shelf: today's quick check-in. Chips sit straight on the ground; Pimpi thanks you for noting things.
struct JournalCard: View {
    @Environment(JournalModel.self) private var journal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPatterns = false

    private enum Metrics {
        static let pimpi: CGFloat = 64
    }

    var body: some View {
        let today = journal.tags(on: journal.today)
        VStack(alignment: .leading, spacing: Spacing.md) {
            PimpiRow(spacing: Spacing.sm) {
                // Hops each time a tag is noted or cleared; its line counts them.
                PokablePimpi(mood: today.isEmpty ? .happy : .excited, size: Metrics.pimpi, cheer: today.count)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    SectionTitle("How was today?")
                    line(today.count)
                        .font(.ds.pimpiSmall)
                        .foregroundStyle(Color.ds.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText(value: Double(today.count)))
                }
            }
            FlowChips(selected: today) { tag in
                withDSAnimation(.bouncy, reduceMotion: reduceMotion) { journal.toggle(tag) }
            }
            PimpiRow(spacing: Spacing.sm) {
                Text("Only you see this. It stays on this iPhone.")
                    .font(.effortNote)
                    .foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Patterns") { showsPatterns = true }
                    .buttonStyle(.chunky(.plain, fullWidth: false))
                    .accessibilityIdentifier("journalPatterns")
            }
        }
        .dsAnimation(.bouncy, value: today.count)
        .sheet(isPresented: $showsPatterns) { PatternsView() }
    }

    /// Pimpi thanks you for checking in, whatever the day held.
    private func line(_ count: Int) -> Text {
        switch count {
        case 0: Text("Quiet day? Also fine.")
        case 1: Text("1 thing noted. Thanks.")
        default: Text("\(count) things noted. Thanks.")
        }
    }
}

/// Tag chips that wrap to as many rows as the width needs.
struct FlowChips: View {
    let selected: Set<JournalTag>
    let toggle: (JournalTag) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum FlowChipMetrics {
        /// A tag bounces when it's picked or cleared.
        static let pop: CGFloat = 1.12
        static let popTime: Double = 0.1
        static let settle: Double = 0.35
    }

    var body: some View {
        WrapLayout(spacing: Spacing.xs) {
            ForEach(JournalTag.allCases, id: \.self) { tag in
                Chip(JournalCopy.title(tag), isSelected: selected.contains(tag)) { toggle(tag) }
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: selected.contains(tag)) { chip, scale in
                        chip.scaleEffect(reduceMotion ? 1 : scale)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(FlowChipMetrics.pop, duration: FlowChipMetrics.popTime)
                            SpringKeyframe(1, duration: FlowChipMetrics.settle, spring: .bouncy)
                        }
                    }
                    .accessibilityIdentifier("journal.\(tag.rawValue)")
            }
        }
    }
}

/// Left-to-right rows that wrap, like words in a sentence. Nothing is ever wider than the row.
struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = fitted(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// A subview's own size, wrapped onto more lines when it would be wider than the row.
    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > width else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows.removeLast()
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows.append(row)
        }
        return rows
    }
}

/// What coincided with busier or calmer scans, from the journal (and Apple Health with Pro).
struct PatternsView: View {
    @Environment(JournalModel.self) private var journal
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @State private var paywall: PaywallReason?

    private enum Metrics {
        static let pimpi: CGFloat = 120
    }

    private var hasFullAccess: Bool { access?.policy.hasFullAccess ?? true }

    var body: some View {
        let includeHealth = journal.usesHealth && hasFullAccess
        let entries = journal.allEntries(includeHealth: includeHealth)
        let points = allScans.filter { !$0.isDeleted && $0.modelContext != nil }.map(InsightEngine.Point.init)
        let patterns = TriggerEngine.patterns(entries: entries, scans: points, calendar: journal.calendar)
        let waitDays = TriggerEngine.daysUntilReady(entries, today: journal.today, calendar: journal.calendar)
        NavigationStack {
            EffortScroll {
                PimpiRow(spacing: Spacing.xs) {
                    PokablePimpi(mood: .curious, size: Metrics.pimpi, cheer: journal.usesHealth ? 1 : 0)
                    SpeechBubble(Text("Clues, not culprits."), tail: typeSize.isAccessibilitySize ? .up : .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionTitle("What coincided")
                    if waitDays > 0 {
                        row(symbol: "hourglass", Text("Keep checking in. Patterns can show after \(waitDays) more days."))
                    } else if patterns.isEmpty {
                        row(symbol: "checkmark.circle", Text("Nothing stands out yet. That's good to know too."))
                    }
                    ForEach(patterns, id: \.tag) { pattern in
                        row(symbol: JournalCopy.symbol(pattern.tag), Text(JournalCopy.pattern(pattern)))
                    }
                    note(Text("Patterns in your own scans, counting the three days before each one. They show what happened together, not what caused it. Many things affect skin."))
                    SectionTitle("Apple Health").padding(.top, Spacing.sm)
                    if hasFullAccess {
                        Toggle("Include sleep and period from Apple Health", isOn: Binding(
                            get: { journal.usesHealth },
                            set: { on in Task { await journal.setUsesHealth(on) } }))
                            .font(.effortRow)
                            .foregroundStyle(Color.ds.ink)
                            .tint(Color.ds.positive)
                            .sensoryFeedback(Haptic.toggle, trigger: journal.usesHealth)
                            .dsCard()
                            .accessibilityIdentifier("healthToggle")
                    } else {
                        Button("Include Apple Health with Pro") { paywall = .healthPatterns }
                            .buttonStyle(.chunkyPlain)
                    }
                    note(Text("Read on this iPhone when you open this screen. Skinalyze never stores Health data or sends it to iCloud."))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Patterns")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task { await journal.loadHealth() }
        .paywallSheet($paywall)
    }

    /// One finding, in the cautious wording, as a plain white row.
    private func row(symbol: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(Color.ds.signal).accessibilityHidden(true)
            text.foregroundStyle(Color.ds.ink).fixedSize(horizontal: false, vertical: true)
        }
        .font(.ds.callout.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func note(_ text: Text) -> some View {
        text.font(.ds.footnote.weight(.semibold))
            .foregroundStyle(Color.ds.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.xxs)
    }
}
