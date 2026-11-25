import SwiftUI
import SkinalyzeKit

/// Streaks in one place: Pimpi beside the routine streak, today's quests and the chest, the wardrobe, then the weekly
/// scan streak, freezes, weekend-off and repair. All of it counts showing up, never skin results.
struct StreakSheet: View {
    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = Metrics.number
    /// A streak worth showing off starts at two days.
    private static let minimumSharedDays = 2

    private enum Metrics {
        static let pimpi: CGFloat = 150
        static let number: CGFloat = 96
        static let numberShrink: CGFloat = 0.5
        static let icon: CGFloat = 28
    }

    var body: some View {
        NavigationStack {
            EffortScroll {
                hero
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    QuestCard()
                    WardrobeLink()
                    streakRows
                    BadgeShelf()
                }
            }
            .navigationTitle("Streaks")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if engagement.routine.count >= Self.minimumSharedDays {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareCardButton { .streak(days: engagement.routine.count) }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .sensoryFeedback(Haptic.success, trigger: engagement.milestone)
        .onDisappear {
            if let milestone = engagement.milestone { engagement.markCelebrated(milestone) }
        }
    }

    // MARK: Pimpi and the number

    private var hero: some View {
        VStack(spacing: Spacing.md) {
            if let milestone = engagement.milestone {
                Text(milestoneTitle(milestone))
                    .font(.ds.display)
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .popIn()
            }
            PimpiRow {
                // Wears its outfit (from the app's environment) and hops when a quest is done or a new outfit goes on.
                PokablePimpi(mood: engagement.milestone != nil || allQuestsDone ? .excited : engagement.mood,
                             size: Metrics.pimpi, cheer: cheer)
                    .dsAnimation(.bouncy, value: quests?.ledger.worn)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(engagement.routine.count, format: .number)
                            .font(.system(size: numberSize, weight: .heavy, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(Metrics.numberShrink)
                            .contentTransition(.numericText(value: Double(engagement.routine.count)))
                            .dsAnimation(.bouncy, value: engagement.routine.count)
                        Image(systemName: "flame.fill").font(.ds.display).foregroundStyle(Color.ds.signal)
                    }
                    .foregroundStyle(Color.ds.ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Routine streak: \(engagement.routine.count) days"))
                    Text(routineLine)
                        .font(.effortRow)
                        .foregroundStyle(Color.ds.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if engagement.canRepair {
                Button { withDSAnimation(.bouncy, reduceMotion: reduceMotion) { engagement.repair() } } label: {
                    Label("Repair yesterday's miss", systemImage: "bandage.fill")
                }
                // The chest, when one is waiting, is the screen's one filled button.
                .buttonStyle(ChunkyButtonStyle(chestWaiting ? .plain : .filled))
            }
        }
    }

    private var chestWaiting: Bool { (quests?.ledger.chestsWaiting ?? 0) > 0 }

    private var allQuestsDone: Bool {
        guard let quests else { return false }
        return !quests.todaysQuests.isEmpty && quests.todaysQuests.allSatisfy(quests.completedToday.contains)
    }

    /// Changes whenever something worth a hop happens here: a quest done, points earned, a new outfit worn.
    private var cheer: Int {
        var hasher = Hasher()
        hasher.combine(quests?.completedToday.count)
        hasher.combine(quests?.ledger.points)
        hasher.combine(quests?.ledger.worn)
        return hasher.finalize()
    }

    // MARK: Streak rows

    private var streakRows: some View {
        @Bindable var engagement = engagement
        return VStack(spacing: Spacing.sm) {
            row(icon: "faceid", title: "Scan streak", value: scanValue, detail: scanLine)
            row(icon: "snowflake", title: "Streak freezes",
                value: Text("\(engagement.ledger.available) of \(FreezeLedger.cap)"),
                detail: Text("A freeze covers one missed day automatically. Earn one every \(StreakEngine.daysPerFreeze) days."))
            Toggle(isOn: $engagement.weekendOff) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Weekends off").font(.effortRow).foregroundStyle(Color.ds.ink)
                    Text("Saturday and Sunday don't count and can't break your streak.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
            }
            .tint(Color.ds.positive)
            .sensoryFeedback(Haptic.toggle, trigger: engagement.weekendOff)
            .dsCard()
        }
    }

    private func row(icon: String, title: LocalizedStringKey, value: Text, detail: Text) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.title3.weight(.bold)).foregroundStyle(Color.ds.signal)
                .frame(minWidth: Metrics.icon)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                    Spacer(minLength: Spacing.xs)
                    value.monospacedDigit()
                }
                .font(.effortRow)
                .foregroundStyle(Color.ds.ink)
                detail.font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Words

    private func milestoneTitle(_ milestone: EngagementModel.Milestone) -> String {
        switch milestone.kind {
        case .routine: String(localized: "\(milestone.value) days in a row!")
        case .scan: String(localized: "\(milestone.value) weeks of scans in a row!")
        }
    }

    private var routineLine: String { StreakCopy.routineLine(engagement.routine.status) }

    private var scanValue: Text {
        engagement.scan.weeks == 1 ? Text("1 week") : Text("\(engagement.scan.weeks) weeks")
    }

    private var scanLine: Text {
        switch engagement.scan.status {
        case .none: Text("Scan once a week to build this.")
        case .doneThisWeek: Text("Scanned this week.")
        case let .due(daysLeft): daysLeft == 1 ? Text("Scan by tomorrow to keep it.") : Text("Scan in the next \(daysLeft) days to keep it.")
        case .atRisk: Text("Last day to scan this week.")
        case .broken: Text("A new streak starts with your next scan.")
        }
    }
}

/// Where the routine streak stands, in one line. Pimpi says it on Home; the streak sheet shows it too.
enum StreakCopy {
    static func routineLine(_ status: RoutineStreak.Status) -> String {
        switch status {
        case .none: String(localized: "Check off a routine step to start your streak.")
        case .doneToday: String(localized: "Done for today. See you tomorrow.")
        case .due: String(localized: "Check off today's routine to keep it going.")
        case .atRisk: String(localized: "Today's almost over — one step keeps your streak.")
        case let .broken(previous): String(localized: "Your \(previous)-day streak ended. Start a new one today.")
        }
    }
}
