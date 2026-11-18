import SwiftData
import SwiftUI
import SkinalyzeKit

/// Today: one hero. Your latest skin card on your mood colour, one sentence, one big action — history is a deck you flick.
struct TodayView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @AppStorage(UserProfile.Key.name) private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    greeting
                    if let latest = scans.first {
                        NavigationLink(value: latest) {
                            SkinCard(session: latest)
                        }
                        .buttonStyle(CardPressStyle())
                        .accessibilityIdentifier("heroCard")
                        Text(headline(latest))
                            .font(.ds.titleSmall)
                            .foregroundStyle(Color.ds.ink)
                    } else {
                        FirstScanHero()
                    }
                    Button { appModel.startScan() } label: {
                        Label("Scan my skin", systemImage: "faceid").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dsPrimary)
                    .accessibilityIdentifier("todayScanButton")
                    if scans.count > 1 { deck }
                    ChipRow(scans: scans)
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(LivingBackground(band: scans.first?.band ?? .calm))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appModel.isShowingProfile = true } label: { Avatar(name: name) }
                        .accessibilityLabel("Profile and settings")
                }
            }
            .navigationDestination(for: ScanSession.self) { ScanResultView(session: $0) }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
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

    /// Past scans as a physical deck: cards tilt and shrink as they leave the centre.
    private var deck: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Your cards").font(.ds.titleSmall).foregroundStyle(Color.ds.ink)
            ScrollView(.horizontal) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(scans.dropFirst()) { scan in
                        NavigationLink(value: scan) {
                            SkinCard(session: scan, size: .compact).frame(width: 150)
                        }
                        .buttonStyle(CardPressStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.12)
                                .rotation3DEffect(.degrees(phase.value * -18), axis: (x: 0, y: 1, z: 0))
                                .opacity(1 - abs(phase.value) * 0.3)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, Spacing.md)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .sensoryFeedback(Haptic.scrub, trigger: scans.count)
        }
    }

    private func headline(_ scan: ScanSession) -> String {
        guard let previous = scans.dropFirst().first else { return BandCopy.summary(scan.band) }
        let delta = scan.breakoutIndex - previous.breakoutIndex
        if delta < 0 { return String(localized: "Calmer than your last scan. Keep going.") }
        if delta > 0 { return String(localized: "A bit more active than last time — worth watching.") }
        return String(localized: "About the same as your last scan.")
    }
}

/// Cards press in like something physical.
struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: configuration.isPressed)
    }
}

private struct FirstScanHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.ds.surface.opacity(0.6)).frame(width: 200, height: 200)
                FaceRing(frontProgress: 0.35, rightProgress: 0.6, leftProgress: 0.2).frame(width: 220, height: 220)
                Image(systemName: "faceid").font(.system(size: 64, weight: .light)).foregroundStyle(Color.ds.ink)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
            }
            Text("Your first scan takes about a minute").font(.ds.title).multilineTextAlignment(.center)
            Text("Look at the camera, then slowly turn your head — like setting up Face ID. Everything stays on your phone.")
                .font(.ds.body).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}

private struct ChipRow: View {
    let scans: [ScanSession]
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(InsightEngine.headline(for: scans.map(InsightEngine.Point.init)), systemImage: "sparkle")
                .font(.ds.callout.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            Button { appModel.selectedTab = .products } label: {
                Label("Your routine", systemImage: "drop.fill")
                    .font(.ds.callout.weight(.semibold))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct Avatar: View {
    let name: String

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "·")
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .frame(width: 48, height: 48)
            .glassEffect(.regular.interactive(), in: Circle())
    }
}
