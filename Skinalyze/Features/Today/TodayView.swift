import SwiftData
import SwiftUI
import SkinalyzeKit

/// Today: latest state at a glance — last scan, change vs. the one before, routine, and the scan action.
struct TodayView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @AppStorage(UserProfile.Key.name) private var name = ""

    var body: some View {
        NavigationStack {
            Group {
                if let latest = scans.first {
                    AdaptivePanes(maxWidth: 900) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            greeting
                            LatestScanCard(scan: latest, previous: scans.dropFirst().first)
                        }
                    } secondary: {
                        VStack(spacing: Spacing.lg) {
                            InsightCard(scans: scans)
                            RoutineSummaryCard()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            greeting
                            EmptyStateView(
                                title: String(localized: "Your first scan takes about a minute"),
                                message: String(localized: "Three quick photos — front, right, left. Everything stays on your phone.")
                            ) {
                                Button("Start a scan") { appModel.startScan() }
                                    .buttonStyle(.dsPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            RoutineSummaryCard()
                        }
                        .padding(Spacing.md)
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .dsCanvas()
            .navigationTitle("Today")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appModel.isShowingProfile = true
                    } label: {
                        Avatar(name: name)
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
            .navigationDestination(for: ScanSession.self) { ScanResultView(session: $0) }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.ds.label)
                .textCase(.uppercase)
                .foregroundStyle(Color.ds.inkSecondary)
            Text(name.isEmpty ? String(localized: "Hello") : String(localized: "Hello, \(name)"))
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct LatestScanCard: View {
    let scan: ScanSession
    let previous: ScanSession?

    var body: some View {
        NavigationLink(value: scan) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Latest scan").font(.ds.headline).foregroundStyle(Color.ds.ink)
                    Spacer()
                    Text(scan.createdAt, format: .relative(presentation: .named))
                        .font(.ds.footnote)
                        .foregroundStyle(Color.ds.inkSecondary)
                }
                if let image = scan.uiImage(at: 0) {
                    ScanPhotoView(image: image, detections: scan.detections(for: .front, types: Set(LesionType.allCases)))
                        .frame(maxHeight: 280)
                        .frame(maxWidth: .infinity)
                }
                HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                    Text(scan.breakoutIndex, format: .number)
                        .font(.ds.numeral)
                        .foregroundStyle(Color.ds.ink)
                        .contentTransition(.numericText(value: Double(scan.breakoutIndex)))
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        BandPill(scan.band)
                        Text("Breakout index").font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                    }
                    Spacer()
                    if let previous {
                        DeltaBadge(delta: scan.breakoutIndex - previous.breakoutIndex)
                    }
                }
                Text(headline).font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
            }
            .dsCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this scan's details")
    }

    private var headline: String {
        guard let previous else { return BandCopy.summary(scan.band) }
        let delta = scan.breakoutIndex - previous.breakoutIndex
        if delta < 0 { return String(localized: "Calmer than your last scan. Keep going.") }
        if delta > 0 { return String(localized: "A bit more active than last time — worth watching.") }
        return String(localized: "About the same as your last scan.")
    }
}

private struct InsightCard: View {
    let scans: [ScanSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Insight", systemImage: "lightbulb").font(.ds.label).foregroundStyle(Color.ds.signal)
            Text(InsightEngine.headline(for: scans.map(InsightEngine.Point.init)))
                .font(.ds.titleSmall)
                .foregroundStyle(Color.ds.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}

private struct RoutineSummaryCard: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0

    var body: some View {
        let count = [cleanser, toner, moisturizer, sunscreen].filter { $0 > 0 }.count
        Button {
            appModel.selectedTab = .products
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "drop").font(.title2).foregroundStyle(Color.ds.signal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your routine").font(.ds.headline).foregroundStyle(Color.ds.ink)
                    Text(count == 0
                         ? String(localized: "Add the products you use to see what's helping.")
                         : String(localized: "\(count) products in your routine"))
                        .font(.ds.footnote)
                        .foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
            }
            .dsCard()
        }
        .buttonStyle(.plain)
    }
}

struct Avatar: View {
    let name: String

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "·")
            .font(.headline)
            .foregroundStyle(Color.ds.ink)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.ds.surfaceRaised))
            .overlay(Circle().strokeBorder(Color.ds.hairline))
    }
}
