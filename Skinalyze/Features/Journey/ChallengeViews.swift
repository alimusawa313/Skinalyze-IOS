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
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                ForEach(ChallengeKind.allCases, id: \.self) { kind in
                    Button { withAnimation(.smooth) { challenges.start(kind) } } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: ChallengeCopy.symbol(kind)).font(.title3).foregroundStyle(Color.ds.signal)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ChallengeCopy.title(kind)).font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
                                Text(ChallengeCopy.detail(kind)).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.ds.signal)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bouncy(0.96))
                    .dsCard()
                    .accessibilityHint(Text("Starts this challenge"))
                    .accessibilityIdentifier("challenge.start.\(kind.rawValue)")
                }
            }
            ForEach(challenges.book.finished.reversed(), id: \.id) { done in
                Button { sharing = .challenge(done) } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "medal.fill").foregroundStyle(Color.ds.positive)
                        Text(ChallengeCopy.title(done.kind)).font(.ds.callout).foregroundStyle(Color.ds.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.arrow.up").foregroundStyle(Color.ds.inkSecondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Share: \(ChallengeCopy.title(done.kind))"))
            }
        }
        .sheet(item: $sharing) { ShareCardSheet(source: $0) }
        .confirmationDialog("Stop this challenge?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop challenge", role: .destructive) { withAnimation(.smooth) { challenges.stop() } }
        } message: {
            Text("The days you've done so far will be cleared.")
        }
    }

    private func running(_ active: Challenge) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle().stroke(Color.ds.hairline, lineWidth: 8)
                    Circle().trim(from: 0, to: Double(active.progress) / Double(ChallengeEngine.goalDays))
                        .stroke(Color.ds.signal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .smooth, value: active.progress)
                    Image(systemName: ChallengeCopy.symbol(active.kind)).font(.title2).foregroundStyle(Color.ds.signal)
                }
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ChallengeCopy.title(active.kind)).font(.ds.headline)
                    Text("Day \(active.progress) of \(ChallengeEngine.goalDays)")
                        .font(.ds.callout.monospacedDigit()).foregroundStyle(Color.ds.signal)
                        .contentTransition(.numericText(value: Double(active.progress)))
                    Text(ChallengeCopy.detail(active.kind)).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if active.kind == .handsOff {
                Button { challenges.toggleHandsOff() } label: {
                    Label(challenges.isDoneToday ? "Done for today" : "I kept my hands off today",
                          systemImage: challenges.isDoneToday ? "checkmark.circle.fill" : "hand.raised")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(challenges.isDoneToday ? Color.ds.positive : Color.ds.signal)
                .sensoryFeedback(Haptic.toggle, trigger: challenges.isDoneToday)
                .accessibilityIdentifier("challenge.handsOff")
            } else if challenges.isDoneToday {
                Label("Today counts!", systemImage: "checkmark.circle.fill")
                    .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.positive)
            }
            Button("Stop challenge", role: .destructive) { confirmingStop = true }
                .font(.ds.footnote)
                .frame(minHeight: 44)
        }
        .dsCard()
    }
}

/// Shown once when a challenge reaches thirty days.
struct ChallengeFinishedView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @State private var sharing: ShareCardSource?
    @State private var celebrated = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: 0)
            Pimpi(mood: .excited).frame(maxWidth: 200, maxHeight: 200)
            Text("Challenge finished!").font(.ds.title).multilineTextAlignment(.center)
            Text("\(ChallengeCopy.title(challenge.kind)): all thirty days done. That's a real habit now.")
                .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button { sharing = .challenge(challenge) } label: {
                Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent).tint(Color.ds.signal)
            Button("Done") { dismiss() }.frame(minHeight: 44)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
        .dsCanvas()
        .sensoryFeedback(.success, trigger: celebrated)
        .onAppear { celebrated = true }
        .sheet(item: $sharing) { ShareCardSheet(source: $0) }
    }
}

extension Challenge: @retroactive Identifiable {}
