import SwiftData
import SwiftUI
import SkinalyzeKit

// The journey map (E11): Pimpi walking a winding path of stops, moved along by glow points and Skin School XP.
// The same screen holds the 30-day challenges and every recap.

enum JourneyCopy {
    static func stopName(_ stop: Int) -> String {
        switch stop {
        case 1: String(localized: "First step")
        case 2: String(localized: "Getting started")
        case 3: String(localized: "Warming up")
        case 4: String(localized: "On a roll")
        case 5: String(localized: "Good habits")
        case 6: String(localized: "Steady hands")
        case 7: String(localized: "Routine regular")
        case 8: String(localized: "Sunscreen star")
        case 9: String(localized: "Label reader")
        case 10: String(localized: "Skin scholar")
        case 11: String(localized: "Habit hero")
        default: String(localized: "Pimpi's best friend")
        }
    }
}

/// On the Shelf: where you are on the journey and today's challenge.
struct JourneyCard: View {
    @Environment(QuestModel.self) private var quests
    @Environment(SchoolModel.self) private var school
    @Environment(ChallengeModel.self) private var challenges
    @State private var showsJourney = false

    var body: some View {
        let position = Journey.position(xp: Journey.xp(points: quests.ledger.points, schoolXP: school.progress.xp))
        Button { showsJourney = true } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PimpiRow {
                    Pimpi(mood: .happy).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stop \(position.stop) · \(JourneyCopy.stopName(position.stop))")
                            .font(.ds.headline).foregroundStyle(Color.ds.ink)
                        if let toNext = position.toNext {
                            Text("\(toNext) points to the next stop").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        } else {
                            Text("You reached the end of the path!").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
                }
                ProgressView(value: position.progress).tint(Color.ds.signal)
                if let active = challenges.book.active {
                    Label {
                        Text("\(ChallengeCopy.title(active.kind)): day \(active.progress) of \(ChallengeEngine.goalDays)")
                    } icon: {
                        Image(systemName: ChallengeCopy.symbol(active.kind))
                    }
                    .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.signal)
                }
            }
            .dsCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.bouncy(0.96))
        .accessibilityIdentifier("journeyCard")
        .fullScreenCover(isPresented: $showsJourney) { JourneyView() }
    }
}

struct JourneyView: View {
    @Environment(QuestModel.self) private var quests
    @Environment(SchoolModel.self) private var school
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened: RecapPeriod?

    private static let node: CGFloat = 60
    private static let swing: [CGFloat] = [0, 0.9, 1.3, 0.9, 0, -0.9, -1.3, -0.9]

    var body: some View {
        let position = Journey.position(xp: Journey.xp(points: quests.ledger.points, schoolXP: school.progress.xp))
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Text("Every quest, lesson and routine day moves Pimpi along. Nothing ever moves you back.")
                        .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    path(position)
                    SocialEntryRow()
                    ChallengeSection()
                    recaps
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top)
            .dsCanvas()
            .navigationTitle("Your journey")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label("\(position.xp) points", systemImage: "sparkles")
                        .labelStyle(.titleAndIcon)
                        .font(.ds.headline).foregroundStyle(Color.ds.signal)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sheet(item: $opened) { RecapView(period: $0) }
    }

    private func path(_ position: Journey.Position) -> some View {
        VStack(spacing: Spacing.md) {
            ForEach(1...Journey.stops, id: \.self) { stop in
                stopView(stop, position: position)
                    .offset(x: Self.swing[(stop - 1) % Self.swing.count] * Self.node)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stopView(_ stop: Int, position: Journey.Position) -> some View {
        let reached = stop <= position.stop
        let isHere = stop == position.stop
        return VStack(spacing: Spacing.xxs) {
            ZStack {
                Circle().fill(reached ? Color.ds.positive : Color.ds.hairline)
                    .shadow(color: .black.opacity(reached ? 0.12 : 0), radius: 6, y: 4)
                if isHere {
                    Pimpi(mood: .excited).padding(6)
                } else {
                    Image(systemName: reached ? "checkmark" : "lock.fill")
                        .font(.title2.weight(.bold)).foregroundStyle(reached ? .white : Color.ds.inkTertiary)
                }
            }
            .frame(width: isHere ? Self.node * 1.4 : Self.node, height: isHere ? Self.node * 1.4 : Self.node)
            .overlay {
                if isHere, position.toNext != nil {
                    Circle().trim(from: 0, to: position.progress)
                        .stroke(Color.ds.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-6)
                        .animation(reduceMotion ? nil : .smooth, value: position.progress)
                }
            }
            Text(JourneyCopy.stopName(stop)).font(.ds.footnote.weight(isHere ? .bold : .semibold))
                .foregroundStyle(reached ? Color.ds.ink : Color.ds.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Self.node * 2.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stop \(stop): \(JourneyCopy.stopName(stop))"))
        .accessibilityValue(isHere ? Text("You are here") : reached ? Text("Reached") : Text("Not reached yet"))
        .accessibilityIdentifier("journeyStop.\(stop)")
    }

    private var recaps: some View {
        let calendar = Calendar.current
        let now = RecapData.now
        let today = DayStamp(now, calendar: calendar)
        // On Monday "your week" is the one that just ended; otherwise this week so far.
        let week = RecapEngine.dueWeek(now: now, calendar: calendar) ?? RecapEngine.week(containing: today, calendar: calendar)
        let lastMonth = RecapEngine.previousMonth(now: now, calendar: calendar)
        let wrapped = RecapEngine.latestWrapped(now: now, calendar: calendar)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("Recaps")
            recapRow(week, symbol: "calendar")
            recapRow(lastMonth, symbol: "calendar.badge.checkmark")
            recapRow(wrapped, symbol: "gift.fill")
            if today.month == 12 || today.month == 1 {
                recapRow(.year(today.month == 1 ? today.year - 1 : today.year), symbol: "sparkles")
            }
        }
    }

    private func recapRow(_ period: RecapPeriod, symbol: String) -> some View {
        Button { opened = period } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: symbol).foregroundStyle(Color.ds.signal).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(RecapCopy.title(period)).font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
                    Text(RecapCopy.dates(period)).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .accessibilityIdentifier("recap.\(period.kind.rawValue)")
    }
}
