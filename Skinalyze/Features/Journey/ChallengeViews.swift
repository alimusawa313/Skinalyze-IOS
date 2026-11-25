import SwiftUI
import SkinalyzeKit

/// 30-day challenges (E17) in the journey screen: the running one with a ring, the ones to pick, and the finished
/// ones to share. Missed days never count against you, and there's no deadline.
struct ChallengeSection: View {
    @Environment(ChallengeModel.self) private var challenges
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingStop = false
    @State private var sharing: ShareCardSource?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("30-day challenges")
            if let active = challenges.book.active {
                running(active)
            } else {
                Text("Pick one. Thirty days done finishes it; a missed day costs nothing.")
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(ChallengeKind.allCases, id: \.self) { kind in
                    Button { withDSAnimation(.smooth, reduceMotion: reduceMotion) { challenges.start(kind) } } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: ChallengeCopy.symbol(kind)).font(.title3.weight(.bold)).foregroundStyle(Color.ds.signal)
                                .frame(minWidth: EffortMetrics.mark)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(ChallengeCopy.title(kind)).font(.effortRow).foregroundStyle(Color.ds.ink)
                                Text(ChallengeCopy.detail(kind)).font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "plus").font(.effortRow).foregroundStyle(Color.ds.ink)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.effortRow)
                    .accessibilityHint(Text("Starts this challenge"))
                    .accessibilityIdentifier("challenge.start.\(kind.rawValue)")
                }
            }
            ForEach(challenges.book.finished.reversed(), id: \.id) { done in
                Button { sharing = .challenge(done) } label: {
                    HStack(spacing: Spacing.sm) {
                        EffortMark(done: true) { EmptyView() }
                        Text(ChallengeCopy.title(done.kind)).font(.effortRow).foregroundStyle(Color.ds.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.arrow.up").font(.effortRow).foregroundStyle(Color.ds.ink)
                    }
                }
                .buttonStyle(.effortRow)
                .accessibilityLabel(Text("Share: \(ChallengeCopy.title(done.kind))"))
            }
        }
        .sheet(item: $sharing) { ShareCardSheet(source: $0) }
        .confirmationDialog("Stop this challenge?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop challenge", role: .destructive) {
                withDSAnimation(.smooth, reduceMotion: reduceMotion) { challenges.stop() }
            }
        } message: {
            Text("The days you've done so far will be cleared.")
        }
    }

    private func running(_ active: Challenge) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) { runningTitle(active); Spacer(minLength: Spacing.xs); runningDay(active) }
                    VStack(alignment: .leading, spacing: Spacing.xxs) { runningTitle(active); runningDay(active) }
                }
                EffortBar(value: Double(active.progress) / Double(max(ChallengeEngine.goalDays, 1)))
                Text(ChallengeCopy.detail(active.kind)).font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if active.kind == .handsOff {
                Button { withDSAnimation(.bouncy, reduceMotion: reduceMotion) { challenges.toggleHandsOff() } } label: {
                    Label(challenges.isDoneToday ? "Done for today" : "I kept my hands off today",
                          systemImage: challenges.isDoneToday ? "checkmark.circle.fill" : "hand.raised")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(challenges.isDoneToday ? .chunkyPlain : .chunky)
                .sensoryFeedback(Haptic.toggle, trigger: challenges.isDoneToday)
                .accessibilityIdentifier("challenge.handsOff")
            } else if challenges.isDoneToday {
                Label("Today counts!", systemImage: "checkmark.circle.fill")
                    .font(.effortNote).foregroundStyle(Color.ds.positive)
            }
            Button("Stop challenge", role: .destructive) { confirmingStop = true }
                .buttonStyle(.plain)
                .font(.effortNote)
                .foregroundStyle(Color.ds.inkSecondary)
                .underline()
                .frame(minHeight: Chunk.iconButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}

extension ChallengeSection {
    private func runningTitle(_ active: Challenge) -> some View {
        Label {
            Text(ChallengeCopy.title(active.kind))
        } icon: {
            Image(systemName: ChallengeCopy.symbol(active.kind)).foregroundStyle(Color.ds.signal)
        }
        .font(.ds.titleSmall).foregroundStyle(Color.ds.ink)
    }

    private func runningDay(_ active: Challenge) -> some View {
        Text("Day \(active.progress) of \(ChallengeEngine.goalDays)")
            .font(.effortRow.monospacedDigit()).foregroundStyle(Color.ds.ink)
            .contentTransition(.numericText(value: Double(active.progress)))
    }
}

/// Shown once when a challenge reaches thirty days.
struct ChallengeFinishedView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @State private var sharing: ShareCardSource?
    @State private var celebrated = false

    private enum Metrics {
        static let pimpi: CGFloat = 200
    }

    var body: some View {
        EffortStage {
            VStack(spacing: Spacing.md) {
                Text("Challenge finished!")
                    .font(.ds.display).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("\(ChallengeCopy.title(challenge.kind)): all thirty days done. That's a real habit now.")
                    .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: celebrated ? 1 : 0)
            }
        } ground: {
            VStack(spacing: Spacing.sm) {
                Button { sharing = .challenge(challenge) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.chunky)
                Button { dismiss() } label: { Text("Done").underline() }
                    .buttonStyle(.plain)
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .frame(minHeight: Chunk.iconButton)
            }
        }
        .sensoryFeedback(.success, trigger: celebrated)
        .onAppear { celebrated = true }
        .sheet(item: $sharing) { ShareCardSheet(source: $0) }
    }
}

extension Challenge: @retroactive Identifiable {}
