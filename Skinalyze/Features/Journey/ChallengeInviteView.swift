import SwiftUI
import SkinalyzeKit

/// Opened by `skinalyze://challenge/<kind>` (the App Store in-app event): offers that challenge, or shows how it's
/// going when it's already running. Starting it over a different running challenge asks first, since that one's
/// days are cleared.
struct ChallengeInviteView: View {
    let kind: ChallengeKind
    @Environment(ChallengeModel.self) private var challenges
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingSwitch = false

    private enum Metrics {
        static let pimpi: CGFloat = 180
    }

    private var running: Challenge? { challenges.book.active.flatMap { $0.kind == kind ? $0 : nil } }
    private var other: Challenge? { challenges.book.active.flatMap { $0.kind == kind ? nil : $0 } }

    var body: some View {
        EffortStage {
            VStack(spacing: Spacing.md) {
                Image(systemName: ChallengeCopy.symbol(kind))
                    .font(.ds.display).foregroundStyle(Color.ds.signal)
                    .accessibilityHidden(true)
                Text(ChallengeCopy.title(kind))
                    .font(.ds.display).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                message
                    .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let running {
                    EffortBar(value: Double(running.progress) / Double(max(ChallengeEngine.goalDays, 1)))
                }
                PokablePimpi(mood: running == nil ? .happy : .excited, size: Metrics.pimpi, cheer: running?.progress ?? 0)
            }
        } ground: {
            VStack(spacing: Spacing.sm) {
                if running != nil {
                    Button { dismiss() } label: { Text("Keep going") }
                        .buttonStyle(.chunky)
                } else {
                    Button {
                        if other == nil { start() } else { confirmingSwitch = true }
                    } label: {
                        Text("Start the challenge")
                    }
                    .buttonStyle(.chunky)
                    .accessibilityIdentifier("challengeInvite.start")
                    Button { dismiss() } label: { Text("Not now").underline() }
                        .buttonStyle(.plain)
                        .font(.effortNote).foregroundStyle(Color.ds.ink)
                        .frame(minHeight: Chunk.iconButton)
                }
            }
        }
        .sensoryFeedback(.success, trigger: running != nil)
        .confirmationDialog("Switch challenges?", isPresented: $confirmingSwitch, titleVisibility: .visible) {
            Button("Start \(ChallengeCopy.title(kind))", role: .destructive) { start() }
        } message: {
            if let other {
                Text("The days you've done on \(ChallengeCopy.title(other.kind)) will be cleared.")
            }
        }
    }

    private var message: Text {
        if let running {
            return Text("Day \(running.progress) of \(ChallengeEngine.goalDays). \(ChallengeCopy.detail(kind))")
        }
        if let other {
            return Text("You're on \(ChallengeCopy.title(other.kind)) right now. One challenge at a time.")
        }
        return Text("\(ChallengeCopy.detail(kind)) Thirty days done finishes it; a missed day costs nothing.")
    }

    private func start() {
        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { challenges.start(kind) }
    }
}
