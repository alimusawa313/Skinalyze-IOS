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
    @Environment(ProAccess.self) private var access: ProAccess?
    @State private var showsChest = false

    var body: some View {
        let done = quests.completedToday
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Today's quests").font(.ds.headline)
                Spacer()
                Label {
                    Text(quests.ledger.points, format: .number)
                        .contentTransition(.numericText(value: Double(quests.ledger.points)))
                } icon: {
                    Image(systemName: "sparkles")
                }
                .font(.ds.headline.monospacedDigit())
                .foregroundStyle(Color.ds.signal)
                .accessibilityLabel(Text("\(quests.ledger.points) glow points"))
            }
            ForEach(quests.todaysQuests, id: \.self) { kind in
                let isDone = done.contains(kind)
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : kind.symbol)
                        .font(.title3)
                        .foregroundStyle(isDone ? Color.ds.positive : Color.ds.inkSecondary)
                        .frame(width: 28)
                        .contentTransition(.symbolEffect(.replace))
                    Text(kind.title).font(.ds.callout)
                        .strikethrough(isDone, color: Color.ds.inkTertiary)
                        .foregroundStyle(isDone ? Color.ds.inkSecondary : Color.ds.ink)
                    Spacer(minLength: Spacing.xs)
                    Text("+\(QuestEngine.points(for: kind))").font(.ds.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.ds.inkSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? Text("Done") : Text("Not done"))
            }
            monthly
            if quests.ledger.chestsWaiting > 0 {
                Button { showsChest = true } label: {
                    Label("Open your chest", systemImage: "gift.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.dsPrimary)
                .accessibilityIdentifier("openChest")
            } else {
                Text("Finish all three for a chest.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .dsCard()
        .sheet(isPresented: $showsChest) { ChestSheet() }
    }

    /// The monthly quest: every daily quest done on 20 days this month earns the month's badge.
    private var monthly: some View {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        let progress = RewardEngine.monthlyProgress(quests.ledger, year: parts.year ?? 0, month: parts.month ?? 1)
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text("Monthly quest").font(.ds.footnote.weight(.semibold))
                Spacer()
                Text("\(progress.days) of \(progress.goal) days").font(.ds.footnote.monospacedDigit())
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            ProgressView(value: Double(min(progress.days, progress.goal)), total: Double(progress.goal))
                .tint(Color.ds.signal)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The chest moment: it bounces, pops open, and Pimpi tries on what was inside.
struct ChestSheet: View {
    @Environment(QuestModel.self) private var quests
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reward: RewardEngine.ChestReward?
    @State private var wiggle = false

    private static let pimpiSide: CGFloat = 180
    private static let chestSide: CGFloat = 120

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 0)
                if let reward {
                    revealed(reward).transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    closed.transition(.scale(scale: 1.2).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .dsCanvas()
            .toolbar { Button("Done") { dismiss() } }
        }
        .sensoryFeedback(Haptic.success, trigger: reward)
        .onAppear { wiggle = true }
    }

    private var closed: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "gift.fill")
                .font(.system(size: Self.chestSide * 0.7))
                .foregroundStyle(Color.ds.signal)
                .frame(width: Self.chestSide, height: Self.chestSide)
                .rotationEffect(.degrees(wiggle && !reduceMotion ? 6 : -6))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18).repeatForever(autoreverses: true), value: wiggle)
                .accessibilityHidden(true)
            Text("A chest for finishing today's quests").font(.ds.title).multilineTextAlignment(.center)
            Button {
                let opened = quests.openChest(isPro: access?.policy.hasFullAccess ?? false)
                withDSAnimation(.bouncy, reduceMotion: reduceMotion) { reward = opened }
            } label: {
                Text("Open").frame(maxWidth: .infinity)
            }
            .buttonStyle(.dsPrimary)
            .accessibilityIdentifier("chestOpen")
        }
    }

    @ViewBuilder private func revealed(_ reward: RewardEngine.ChestReward) -> some View {
        VStack(spacing: Spacing.md) {
            Pimpi(mood: .excited)
                .environment(\.pimpiOutfit, reward.outfit)
                .frame(width: Self.pimpiSide, height: Self.pimpiSide)
            if let outfit = reward.outfit {
                Text("New for Pimpi: \(Text(outfit.title))").font(.ds.title).multilineTextAlignment(.center)
                Button {
                    quests.wear(outfit)
                    dismiss()
                } label: {
                    Text("Wear it").frame(maxWidth: .infinity)
                }
                .buttonStyle(.dsPrimary)
                .accessibilityIdentifier("chestWear")
            } else {
                Text("Pimpi has every outfit. +\(reward.bonusPoints) glow points instead!")
                    .font(.ds.title).multilineTextAlignment(.center)
            }
        }
    }
}

/// Pimpi's outfits: owned ones can be worn; the rest show where they come from.
struct WardrobeView: View {
    @Environment(QuestModel.self) private var quests

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)]
    private static let pimpiSide: CGFloat = 72

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                outfitButton(nil)
                ForEach(PimpiOutfit.allCases, id: \.self) { outfitButton($0) }
            }
            .padding(Spacing.md)
        }
        .dsCanvas()
        .navigationTitle("Wardrobe")
        .toolbarTitleDisplayMode(.inline)
    }

    private func outfitButton(_ outfit: PimpiOutfit?) -> some View {
        let owned = outfit.map { quests.ledger.unlocked.contains($0) } ?? true
        let worn = quests.ledger.worn == outfit
        return Button { quests.wear(outfit) } label: {
            VStack(spacing: Spacing.xxs) {
                Pimpi(mood: .happy)
                    .environment(\.pimpiOutfit, outfit)
                    .frame(width: Self.pimpiSide, height: Self.pimpiSide)
                    .opacity(owned ? 1 : 0.35)
                    .overlay(alignment: .bottomTrailing) {
                        if !owned { Image(systemName: "lock.fill").foregroundStyle(Color.ds.inkSecondary) }
                    }
                Group {
                    if let outfit { Text(outfit.title) } else { Text("Nothing") }
                }
                .font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.ink)
                if let outfit, outfit.isPro {
                    Text(verbatim: "Pro").font(.ds.label).foregroundStyle(Color.ds.signal)
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(worn ? Color.ds.signal : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!owned)
        .accessibilityValue(worn ? Text("Wearing") : (owned ? Text(verbatim: "") : Text("Not won yet")))
    }
}

/// Badges for things the user did.
struct BadgeShelf: View {
    @Environment(QuestModel.self) private var quests
    @Query private var scans: [ScanSession]

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: Spacing.sm)]

    var body: some View {
        let earned = BadgeEngine.earned(BadgeFacts(
            scans: scans.count, has3DScan: scans.contains { $0.faceMesh != nil },
            bestRoutineStreak: quests.bestRoutineStreak, productChecks: quests.ledger.productChecks,
            shares: quests.ledger.shares, questDays: quests.ledger.fullQuestDays))
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Badges").font(.ds.headline)
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(quests.ledger.monthlyBadges.sorted(), id: \.self) { month in
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(Color.ds.signal)
                            .frame(width: 52, height: 52)
                            .background(Color.ds.signalSoft, in: Circle())
                        if let date = DayStamp(string: month + "-01")?.date(in: .current) {
                            Text(date, format: .dateTime.month(.wide).year()).font(.ds.caption).multilineTextAlignment(.center)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                ForEach(Badge.allCases, id: \.self) { badge in
                    let has = earned.contains(badge)
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: badge.symbol)
                            .font(.title2)
                            .foregroundStyle(has ? Color.ds.signal : Color.ds.inkTertiary)
                            .frame(width: 52, height: 52)
                            .background(has ? Color.ds.signalSoft : Color.ds.surfaceRaised, in: Circle())
                        Text(badge.title).font(.ds.caption).multilineTextAlignment(.center)
                            .foregroundStyle(has ? Color.ds.ink : Color.ds.inkTertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(has ? Text("Earned") : Text("Not earned yet"))
                }
            }
        }
        .dsCard()
    }
}

/// Row into Pimpi's wardrobe.
struct WardrobeLink: View {
    @Environment(QuestModel.self) private var quests

    var body: some View {
        NavigationLink { WardrobeView() } label: {
            HStack(spacing: Spacing.sm) {
                Pimpi(mood: .happy).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pimpi's wardrobe").font(.ds.headline).foregroundStyle(Color.ds.ink)
                    Text("\(quests.ledger.unlocked.count) of \(PimpiOutfit.allCases.count) outfits")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
            }
            .dsCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wardrobeLink")
    }
}
