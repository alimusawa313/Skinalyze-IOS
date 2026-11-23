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

/// On the Shelf: today's quick check-in.
struct JournalCard: View {
    @Environment(JournalModel.self) private var journal
    @State private var showsPatterns = false

    var body: some View {
        let today = journal.tags(on: journal.today)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionTitle("How was today?")
                Spacer()
                Button("Patterns") { showsPatterns = true }
                    .font(.ds.label)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("journalPatterns")
            }
            FlowChips(selected: today) { journal.toggle($0) }
            Text("Only you see this. It stays on this iPhone.").font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
        }
        .dsCard()
        .sheet(isPresented: $showsPatterns) { PatternsView() }
    }
}

/// Tag chips that wrap to as many rows as the width needs.
struct FlowChips: View {
    let selected: Set<JournalTag>
    let toggle: (JournalTag) -> Void

    var body: some View {
        WrapLayout(spacing: Spacing.xs) {
            ForEach(JournalTag.allCases, id: \.self) { tag in
                let on = selected.contains(tag)
                Button { toggle(tag) } label: {
                    Label(JournalCopy.title(tag), systemImage: JournalCopy.symbol(tag))
                        .font(.ds.footnote.weight(.semibold))
                        .padding(.horizontal, Spacing.sm)
                        .frame(minHeight: 36)
                        .background(on ? Color.ds.signal : Color.ds.surfaceRaised, in: Capsule())
                        .foregroundStyle(on ? Color.white : Color.ds.ink)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(Haptic.toggle, trigger: on)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("journal.\(tag.rawValue)")
            }
        }
    }
}

/// Left-to-right rows that wrap, like words in a sentence.
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
                let size = subviews[index].sizeThatFits(.unspecified)
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

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
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
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @State private var paywall: PaywallReason?

    private var hasFullAccess: Bool { access?.policy.hasFullAccess ?? true }

    var body: some View {
        let includeHealth = journal.usesHealth && hasFullAccess
        let entries = journal.allEntries(includeHealth: includeHealth)
        let points = allScans.filter { !$0.isDeleted && $0.modelContext != nil }.map(InsightEngine.Point.init)
        let patterns = TriggerEngine.patterns(entries: entries, scans: points, calendar: journal.calendar)
        let waitDays = TriggerEngine.daysUntilReady(entries, today: journal.today, calendar: journal.calendar)
        NavigationStack {
            List {
                Section {
                    if waitDays > 0 {
                        Label("Keep checking in. Patterns can show after \(waitDays) more days.", systemImage: "hourglass")
                    } else if patterns.isEmpty {
                        Label("Nothing stands out yet. That's good to know too.", systemImage: "checkmark.circle")
                    }
                    ForEach(patterns, id: \.tag) { pattern in
                        Label(JournalCopy.pattern(pattern), systemImage: JournalCopy.symbol(pattern.tag))
                            .font(.ds.callout)
                    }
                } header: {
                    Text("What coincided")
                } footer: {
                    Text("Patterns in your own scans, counting the three days before each one. They show what happened together, not what caused it. Many things affect skin.")
                }
                Section {
                    if hasFullAccess {
                        Toggle("Include sleep and period from Apple Health", isOn: Binding(
                            get: { journal.usesHealth },
                            set: { on in Task { await journal.setUsesHealth(on) } }))
                            .accessibilityIdentifier("healthToggle")
                    } else {
                        Button("Include Apple Health with Pro") { paywall = .healthPatterns }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Read on this iPhone when you open this screen. Skinalyze never stores Health data or sends it to iCloud.")
                }
            }
            .navigationTitle("Patterns")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task { await journal.loadHealth() }
        .paywallSheet($paywall)
    }
}
