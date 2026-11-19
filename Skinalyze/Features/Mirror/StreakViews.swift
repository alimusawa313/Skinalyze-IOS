import SwiftUI
import SkinalyzeKit

/// Pimpi standing next to the shutter with the streak flame — the one engagement element on the Mirror.
/// Tap for the streak sheet. Pimpi's mood comes from the streaks (effort), never from skin results.
struct PimpiStreakBadge: View {
    @Environment(EngagementModel.self) private var engagement
    @State private var showsStreak = false

    var body: some View {
        Button { showsStreak = true } label: {
            Pimpi(mood: engagement.mood)
                .frame(width: 76, height: 76)
                .overlay(alignment: .topTrailing) {
                    if engagement.routine.count > 0 {
                        Label("\(engagement.routine.count)", systemImage: "flame.fill")
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(Color.ds.canvas)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 3)
                            .background(Color.ds.signal, in: Capsule())
                            .contentTransition(.numericText(value: Double(engagement.routine.count)))
                            .offset(x: 6, y: -4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.bouncy(0.88))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows your streaks")
        .accessibilityIdentifier("pimpiStreak")
        .sheet(isPresented: $showsStreak) { StreakSheet() }
        .onChange(of: engagement.milestone) { _, milestone in
            if milestone != nil { showsStreak = true } // celebrate once, with Pimpi
        }
    }

    private var accessibilityLabel: Text {
        engagement.routine.count > 0
            ? Text("Pimpi. Routine streak: \(engagement.routine.count) days")
            : Text("Pimpi. No routine streak yet")
    }
}

/// Streaks in one place: the daily routine streak, the weekly scan streak, freezes, weekend-off and repair.
struct StreakSheet: View {
    @Environment(EngagementModel.self) private var engagement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 72
    /// A streak worth showing off starts at two days.
    private static let minimumSharedDays = 2

    var body: some View {
        @Bindable var engagement = engagement
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Pimpi(mood: engagement.milestone != nil ? .excited : engagement.mood)
                        .frame(width: 150, height: 150)
                    if let milestone = engagement.milestone {
                        Text(milestoneTitle(milestone))
                            .font(.system(.title, design: .rounded).weight(.heavy))
                            .multilineTextAlignment(.center)
                            .popIn()
                    }
                    VStack(spacing: Spacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(Color.ds.signal)
                            Text(engagement.routine.count, format: .number)
                                .font(.system(size: numberSize, weight: .heavy, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText(value: Double(engagement.routine.count)))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("Routine streak: \(engagement.routine.count) days"))
                        Text(routineLine).font(.ds.headline).multilineTextAlignment(.center)
                    }
                    if engagement.canRepair {
                        Button { engagement.repair() } label: {
                            Label("Repair yesterday's miss", systemImage: "bandage.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.dsPrimary)
                    }
                    VStack(spacing: Spacing.sm) {
                        row(icon: "faceid", title: "Scan streak", value: scanValue, detail: scanLine)
                        Divider()
                        row(icon: "snowflake", title: "Streak freezes",
                            value: Text("\(engagement.ledger.available) of \(FreezeLedger.cap)"),
                            detail: Text("A freeze covers one missed day automatically. Earn one every \(StreakEngine.daysPerFreeze) days."))
                        Divider()
                        Toggle(isOn: $engagement.weekendOff) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weekends off").font(.ds.headline)
                                Text("Saturday and Sunday don't count and can't break your streak.")
                                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                            }
                        }
                        .tint(Color.ds.signal)
                    }
                    .dsCard()
                }
                .padding(Spacing.lg)
            }
            .background(Color.ds.canvas)
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

    private func row(icon: String, title: LocalizedStringKey, value: Text, detail: Text) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon).font(.title3).foregroundStyle(Color.ds.signal).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.ds.headline)
                    Spacer()
                    value.font(.ds.headline.monospacedDigit())
                }
                detail.font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func milestoneTitle(_ milestone: EngagementModel.Milestone) -> String {
        switch milestone.kind {
        case .routine: String(localized: "\(milestone.value) days in a row!")
        case .scan: String(localized: "\(milestone.value) weeks of scans in a row!")
        }
    }

    private var routineLine: String {
        switch engagement.routine.status {
        case .none: String(localized: "Check off a routine step to start your streak.")
        case .doneToday: String(localized: "Done for today. See you tomorrow.")
        case .due: String(localized: "Check off today's routine to keep it going.")
        case .atRisk: String(localized: "Today's almost over — one step keeps your streak.")
        case let .broken(previous): String(localized: "Your \(previous)-day streak ended. Start a new one today.")
        }
    }

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
