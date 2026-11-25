import SwiftData
import SwiftUI
import SkinalyzeKit

// Today's quests, glow points, the chest moment, Pimpi's wardrobe and the badge shelf. All of it rewards effort.

extension QuestKind {
    var title: LocalizedStringKey {
        switch self {
        case .routine: "Check off a routine step"
        case .scan: "Take today's scan"
        case .productCheck: "Check a product"
        case .share: "Share a card"
        case .lookBack: "Look back at an earlier scan"
        case .lesson: "Finish a Skin School lesson"
        }
    }

    var symbol: String {
        switch self {
        case .routine: "checklist"
        case .scan: "faceid"
        case .productCheck: "checkmark.seal"
        case .share: "square.and.arrow.up"
        case .lookBack: "clock.arrow.circlepath"
        case .lesson: "graduationcap"
        }
    }
}

extension PimpiOutfit {
    var title: LocalizedStringKey {
        switch self {
        case .partyHat: "Party hat"
        case .beanie: "Beanie"
        case .flower: "Flower"
        case .bow: "Bow"
        case .crown: "Crown"
        case .sunglasses: "Sunglasses"
        case .scarf: "Scarf"
        }
    }
}

extension Badge {
    var title: LocalizedStringKey {
        switch self {
        case .firstScan: "First scan"
        case .first3D: "First 3D scan"
        case .routineWeek: "A week of routine"
        case .tenChecks: "10 product checks"
        case .firstShare: "First share"
        case .questWeek: "A week of quests"
        }
    }

    var symbol: String {
        switch self {
        case .firstScan: "faceid"
        case .first3D: "cube"
        case .routineWeek: "flame.fill"
        case .tenChecks: "checkmark.seal.fill"
        case .firstShare: "paperplane.fill"
        case .questWeek: "star.fill"
        }
    }
}

/// Today's three quests, the glow points total, and the chest when it is earned.
struct QuestCard: View {
    @Environment(QuestModel.self) private var quests
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsChest = false

    private enum Metrics {
        /// The chest button rocks side to side while a chest is waiting.
        static let wiggle: Double = 3
        static let wiggleStep: Double = 0.09
        static let wiggleRest: Double = 1.4
    }

    var body: some View {
        let done = quests.completedToday
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center) {
                SectionTitle("Today's quests")
                Spacer(minLength: Spacing.sm)
                points
            }
            ForEach(quests.todaysQuests, id: \.self) { kind in
                questRow(kind, isDone: done.contains(kind))
            }
            monthly
            if quests.ledger.chestsWaiting > 0 {
                Button { showsChest = true } label: {
                    Label("Open your chest", systemImage: "gift.fill")
                }
                .buttonStyle(.chunky)
                .keyframeAnimator(initialValue: 0.0, repeating: !reduceMotion) { content, angle in
                    content.rotationEffect(.degrees(reduceMotion ? 0 : angle))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(Metrics.wiggle, duration: Metrics.wiggleStep)
                        CubicKeyframe(-Metrics.wiggle, duration: Metrics.wiggleStep * 2)
                        CubicKeyframe(Metrics.wiggle, duration: Metrics.wiggleStep * 2)
                        CubicKeyframe(0, duration: Metrics.wiggleStep)
                        LinearKeyframe(0, duration: Metrics.wiggleRest)
                    }
                }
                .padding(.top, Spacing.xxs)
                .transition(.scale.combined(with: .opacity))
                .accessibilityIdentifier("openChest")
            } else {
                Text("Finish all three for a chest.")
                    .font(.effortNote)
                    .foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .dsAnimation(.bouncy, value: quests.ledger.chestsWaiting)
        .sensoryFeedback(Haptic.success, trigger: done.count)
        .sheet(isPresented: $showsChest) { ChestSheet() }
    }

    private var points: some View {
        Label {
            Text(quests.ledger.points, format: .number)
                .contentTransition(.numericText(value: Double(quests.ledger.points)))
                .dsAnimation(.bouncy, value: quests.ledger.points) // the points roll
        } icon: {
            Image(systemName: "sparkles").foregroundStyle(Color.ds.signal)
        }
        .font(.effortRow.monospacedDigit())
        .foregroundStyle(Color.ds.ink)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: Chunk.iconButton)
        .dsSurface(radius: Chunk.iconButton / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(quests.ledger.points) glow points"))
    }

    private func questRow(_ kind: QuestKind, isDone: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            EffortMark(done: isDone) { Image(systemName: kind.symbol) }
            Text(kind.title)
                .font(.effortRow)
                .foregroundStyle(Color.ds.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            EffortTag(text: Text("+\(QuestEngine.points(for: kind))"), quiet: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Chunk.controlHeight)
        .dsSurface()
        .dsAnimation(.bouncy, value: isDone)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? Text("Done") : Text("Not done"))
    }

    /// The monthly quest: every daily quest done on 20 days this month earns the month's badge.
    private var monthly: some View {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        let progress = RewardEngine.monthlyProgress(quests.ledger, year: parts.year ?? 0, month: parts.month ?? 1)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Monthly quest").font(.effortRow).foregroundStyle(Color.ds.ink)
                Spacer(minLength: Spacing.xs)
                Text("\(progress.days) of \(progress.goal) days").font(.effortNote.monospacedDigit())
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            EffortBar(value: Double(min(progress.days, progress.goal)) / Double(max(progress.goal, 1)))
        }
        .dsCard()
        .accessibilityElement(children: .combine)
    }
}

/// The chest moment: it wiggles on the hill; "Open" makes it shake, swell and burst, then Pimpi pops out wearing what
/// was inside. "Wear it" keeps it on (the streak sheet's Pimpi hops into it).
struct ChestSheet: View {
    @Environment(QuestModel.self) private var quests
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reward: RewardEngine.ChestReward?
    @State private var opening = false
    @State private var wiggle = false

    private enum Metrics {
        static let pimpi: CGFloat = 180
        static let chest: CGFloat = 120
        static let wiggleDegrees: Double = 6
        static let wiggleSeconds: Double = 0.18
        static let closedScale: CGFloat = 1.2
        static let revealedScale: CGFloat = 0.6
        /// The burst: a quick shake, a swell, then the lid flies.
        static let shake: Double = 14
        static let shakeStep: Double = 0.07
        static let swell: CGFloat = 1.25
        static let swellTime: Double = 0.18
        static let burst: Duration = .milliseconds(560)
        static let titleDelay: Double = 0.15
    }

    /// One frame of the chest bursting open.
    private struct Burst {
        var angle: Double = 0
        var scale: CGFloat = 1
    }

    var body: some View {
        NavigationStack {
            EffortStage {
                if let reward {
                    revealed(reward).transition(.scale(scale: Metrics.revealedScale).combined(with: .opacity))
                } else {
                    closed.transition(.scale(scale: Metrics.closedScale).combined(with: .opacity))
                }
            } ground: {
                actions
            }
            .toolbar { Button("Done") { dismiss() } }
        }
        .sensoryFeedback(Haptic.success, trigger: reward)
        .sensoryFeedback(Haptic.capture, trigger: opening) { _, isOpening in isOpening }
        .onAppear { wiggle = true }
    }

    private var closed: some View {
        VStack(spacing: Spacing.lg) {
            title(Text("A chest for finishing today's quests"))
            Image(systemName: "gift.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.ds.signal)
                .frame(width: Metrics.chest, height: Metrics.chest)
                .rotationEffect(.degrees(wiggle && !reduceMotion && !opening ? Metrics.wiggleDegrees : -Metrics.wiggleDegrees),
                                anchor: .bottom)
                .animation(reduceMotion || opening ? nil : .easeInOut(duration: Metrics.wiggleSeconds).repeatForever(autoreverses: true),
                           value: wiggle)
                .keyframeAnimator(initialValue: Burst(), trigger: opening) { content, frame in
                    content
                        .rotationEffect(.degrees(reduceMotion ? 0 : frame.angle), anchor: .bottom)
                        .scaleEffect(reduceMotion ? 1 : frame.scale, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(Metrics.shake, duration: Metrics.shakeStep)
                        CubicKeyframe(-Metrics.shake, duration: Metrics.shakeStep)
                        CubicKeyframe(Metrics.shake, duration: Metrics.shakeStep)
                        CubicKeyframe(-Metrics.shake, duration: Metrics.shakeStep)
                        CubicKeyframe(0, duration: Metrics.shakeStep)
                    }
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: Metrics.shakeStep * 4)
                        SpringKeyframe(Metrics.swell, duration: Metrics.swellTime, spring: .bouncy)
                    }
                }
                .accessibilityHidden(true)
        }
    }

    private func revealed(_ reward: RewardEngine.ChestReward) -> some View {
        VStack(spacing: Spacing.lg) {
            Group {
                if let outfit = reward.outfit {
                    title(Text("New for Pimpi: \(Text(outfit.title))"))
                } else {
                    title(Text("Pimpi has every outfit. +\(reward.bonusPoints) glow points instead!"))
                }
            }
            .popIn(delay: Metrics.titleDelay)
            PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: 1)
                .environment(\.pimpiOutfit, reward.outfit)
                .popIn()
        }
    }

    private func title(_ text: Text) -> some View {
        text.font(.ds.display).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The one button of the moment: open it, then wear what was inside.
    @ViewBuilder private var actions: some View {
        if let outfit = reward?.outfit {
            Button("Wear it") {
                quests.wear(outfit)
                dismiss()
            }
            .buttonStyle(.chunky)
            .popIn(delay: Metrics.titleDelay)
            .accessibilityIdentifier("chestWear")
        } else if reward == nil {
            Button("Open") { open() }
                .buttonStyle(.chunky)
                .disabled(opening)
                .accessibilityIdentifier("chestOpen")
        }
    }

    /// Shake and swell first, then show what was inside.
    private func open() {
        opening = true
        let opened = quests.openChest(isPro: access?.policy.hasFullAccess ?? false)
        Task {
            if !reduceMotion { try? await Task.sleep(for: Metrics.burst) }
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { reward = opened }
        }
    }
}

/// Pimpi's outfits as pills: owned ones can be worn; the rest show a lock, and the Pro ones say so.
struct WardrobeView: View {
    @Environment(QuestModel.self) private var quests
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let pimpi: CGFloat = 200
    }

    var body: some View {
        EffortScroll {
            // Dresses the moment a pill is tapped, and hops into it.
            PokablePimpi(mood: .happy, size: Metrics.pimpi, cheer: quests.ledger.worn.hashValue)
                .environment(\.pimpiOutfit, quests.ledger.worn)
                .frame(maxWidth: .infinity)
                .dsAnimation(.bouncy, value: quests.ledger.worn)
        } ground: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("\(quests.ledger.unlocked.count) of \(PimpiOutfit.allCases.count) outfits")
                    .font(.effortRow)
                    .foregroundStyle(Color.ds.ink)
                WrapLayout(spacing: Spacing.xs) {
                    outfitButton(nil)
                    ForEach(PimpiOutfit.allCases, id: \.self) { outfitButton($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sensoryFeedback(Haptic.toggle, trigger: quests.ledger.worn)
        .navigationTitle("Wardrobe")
        .toolbarTitleDisplayMode(.inline)
    }

    private func outfitButton(_ outfit: PimpiOutfit?) -> some View {
        let owned = outfit.map { quests.ledger.unlocked.contains($0) } ?? true
        let worn = quests.ledger.worn == outfit
        return Button { withDSAnimation(.bouncy, reduceMotion: reduceMotion) { quests.wear(outfit) } } label: {
            HStack(spacing: Spacing.xs) {
                if !owned { Image(systemName: "lock.fill").imageScale(.small).accessibilityHidden(true) }
                if let outfit { Text(outfit.title) } else { Text("Nothing") }
                if let outfit, outfit.isPro {
                    EffortTag(text: Text(verbatim: "Pro"), onInk: worn)
                }
            }
        }
        .buttonStyle(.chunky(worn ? .filled : .plain, fullWidth: false))
        .disabled(!owned)
        .accessibilityAddTraits(worn ? .isSelected : [])
        .accessibilityValue(worn ? Text("Wearing") : (owned ? Text(verbatim: "") : Text("Not won yet")))
    }
}

/// Badges for things the user did.
struct BadgeShelf: View {
    @Environment(QuestModel.self) private var quests
    @Query private var scans: [ScanSession]

    private enum Metrics {
        static let column: CGFloat = 92
        static let token: CGFloat = 52
    }

    private let columns = [GridItem(.adaptive(minimum: Metrics.column), spacing: Spacing.sm, alignment: .top)]

    var body: some View {
        let earned = BadgeEngine.earned(BadgeFacts(
            scans: scans.count, has3DScan: scans.contains { $0.faceMesh != nil },
            bestRoutineStreak: quests.bestRoutineStreak, productChecks: quests.ledger.productChecks,
            shares: quests.ledger.shares, questDays: quests.ledger.fullQuestDays))
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("Badges")
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(quests.ledger.monthlyBadges.sorted(), id: \.self) { month in
                    VStack(spacing: Spacing.xxs) {
                        token("calendar.badge.checkmark", earned: true)
                        if let date = DayStamp(string: month + "-01")?.date(in: .current) {
                            caption(Text(date, format: .dateTime.month(.wide).year()), earned: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                ForEach(Badge.allCases, id: \.self) { badge in
                    let has = earned.contains(badge)
                    VStack(spacing: Spacing.xxs) {
                        token(badge.symbol, earned: has)
                        caption(Text(badge.title), earned: has)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(has ? Text("Earned") : Text("Not earned yet"))
                }
            }
            .frame(maxWidth: .infinity)
            .dsCard()
        }
    }

    private func token(_ symbol: String, earned: Bool) -> some View {
        Image(systemName: symbol)
            .font(.title2.weight(.bold))
            .foregroundStyle(earned ? Color.ds.canvas : Color.ds.inkTertiary)
            .frame(width: Metrics.token, height: Metrics.token)
            .background(earned ? Color.ds.signal : Color.ds.surfaceRaised, in: Circle())
    }

    private func caption(_ text: Text, earned: Bool) -> some View {
        text.font(.ds.caption.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(earned ? Color.ds.ink : Color.ds.inkSecondary)
    }
}

/// Row into Pimpi's wardrobe.
struct WardrobeLink: View {
    @Environment(QuestModel.self) private var quests

    private enum Metrics {
        static let pimpi: CGFloat = 48
    }

    var body: some View {
        NavigationLink { WardrobeView() } label: {
            HStack(spacing: Spacing.sm) {
                Pimpi(mood: .happy).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Pimpi's wardrobe").font(.effortRow).foregroundStyle(Color.ds.ink)
                    Text("\(quests.ledger.unlocked.count) of \(PimpiOutfit.allCases.count) outfits")
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.ink)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.effortRow)
        .accessibilityIdentifier("wardrobeLink")
    }
}
