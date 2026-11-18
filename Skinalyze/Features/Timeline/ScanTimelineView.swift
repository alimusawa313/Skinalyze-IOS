import Charts
import SwiftData
import SwiftUI
import SkinalyzeKit

/// Every scan, the trend over time, and compare. List-detail on wide layouts (incl. iPhone Duo unfolded).
struct ScanTimelineView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @State private var selection: ScanSession?
    @State private var isComparing = false
    @State private var compareSelection: [ScanSession] = []
    @State private var comparePair: ComparePair?

    struct ComparePair: Identifiable {
        let earlier: ScanSession
        let later: ScanSession
        var id: String { "\(earlier.id)-\(later.id)" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if scans.isEmpty {
                    EmptyStateView(title: String(localized: "Your timeline starts with one scan"),
                                   message: String(localized: "Each scan adds a point here so you can see what's changing.")) {
                        Button("Start a scan") { appModel.startScan() }.buttonStyle(.dsPrimary)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                if scans.count >= 2 {
                    Button(isComparing ? "Cancel" : "Compare") {
                        isComparing.toggle()
                        compareSelection = []
                    }
                }
            }
            .navigationDestination(for: ScanSession.self) { ScanResultView(session: $0) }
        }
        .sheet(item: $comparePair) { pair in
            NavigationStack { CompareView(earlier: pair.earlier, later: pair.later) }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TrendChart(scans: scans)
                    .frame(height: 200)
                    .padding(Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                ForEach(groupedByMonth, id: \.month) { group in
                    Text(group.month.formatted(.dateTime.month(.wide).year()))
                        .font(.ds.titleSmall)
                        .foregroundStyle(Color.ds.ink)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
                        ForEach(group.scans) { scan in
                            card(scan)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(LivingBackground(band: scans.first?.band ?? .calm))
        .safeAreaInset(edge: .bottom) {
            if isComparing {
                Button {
                    let sorted = compareSelection.sorted { $0.createdAt < $1.createdAt }
                    comparePair = ComparePair(earlier: sorted[0], later: sorted[1])
                    isComparing = false
                    compareSelection = []
                } label: {
                    Text(compareSelection.count == 2 ? "Compare these two" : "Pick \(2 - compareSelection.count) more")
                }
                .buttonStyle(.dsPrimary)
                .disabled(compareSelection.count != 2)
                .padding(Spacing.md)
            }
        }
    }

    @ViewBuilder private func card(_ scan: ScanSession) -> some View {
        let isPicked = compareSelection.contains(scan)
        if isComparing {
            Button {
                if isPicked {
                    compareSelection.removeAll { $0 == scan }
                } else {
                    // A third pick replaces the oldest pick (instead of silently ignoring the tap).
                    if compareSelection.count == 2 { compareSelection.removeFirst() }
                    compareSelection.append(scan)
                }
            } label: {
                SkinCard(session: scan, size: .compact)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(.white, isPicked ? Color.ds.positive : Color.black.opacity(0.25))
                            .padding(Spacing.sm)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .scaleEffect(isPicked ? 0.95 : 1)
                    .dsAnimation(.snappy, value: isPicked)
            }
            .buttonStyle(CardPressStyle())
            .sensoryFeedback(Haptic.toggle, trigger: isPicked)
        } else {
            NavigationLink(value: scan) { SkinCard(session: scan, size: .compact) }
                .buttonStyle(CardPressStyle())
                .contextMenu {
                    Button("Delete scan", systemImage: "trash", role: .destructive) {
                        AppPersistence.delete(scan, in: modelContext)
                    }
                }
        }
    }

    private func previous(of scan: ScanSession) -> ScanSession? {
        scans.first { $0.createdAt < scan.createdAt }
    }

    private var groupedByMonth: [(month: Date, scans: [ScanSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: scans) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.createdAt)) ?? $0.createdAt
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }
}

private struct ScanRow: View {
    let scan: ScanSession
    let previous: ScanSession?
    let isPicked: Bool?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let isPicked {
                Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPicked ? Color.ds.signal : Color.ds.inkTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Group {
                if let image = scan.uiImage(at: 0) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.ds.surfaceRaised
                }
            }
            .frame(width: 56, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(scan.createdAt, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.ds.headline)
                BandPill(scan.band)
            }
            Spacer()
            if let previous {
                DeltaBadge(delta: scan.breakoutIndex - previous.breakoutIndex)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// Breakout index over time. Drag to scrub — each scan ticks with a selection haptic.
struct TrendChart: View {
    let scans: [ScanSession]
    @State private var selectedDate: Date?

    private var points: [ScanSession] { scans.sorted { $0.createdAt < $1.createdAt } }

    private var selected: ScanSession? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.createdAt.timeIntervalSince(selectedDate)) < abs($1.createdAt.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Breakout index").font(.ds.headline)
                Spacer()
                if let selected {
                    Text("\(selected.breakoutIndex) · \(selected.createdAt.formatted(.dateTime.day().month()))")
                        .font(.ds.callout.monospacedDigit())
                        .foregroundStyle(Color.ds.inkSecondary)
                }
            }
            Chart(points) { scan in
                LineMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.ds.signal)
                PointMark(x: .value("Date", scan.createdAt), y: .value("Index", scan.breakoutIndex))
                    .foregroundStyle(Color.ds.band(scan.band))
                    .symbolSize(scan == selected ? 140 : 60)
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis { AxisMarks(position: .leading) }
            .accessibilityLabel("Breakout index over time")
            .sensoryFeedback(Haptic.scrub, trigger: selected?.id)
        }
        .padding(.vertical, Spacing.xs)
    }
}
