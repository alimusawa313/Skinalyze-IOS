import SwiftUI
import SkinalyzeKit

// The first week (ONBOARDING-PLAN.md §5.3): a chip on Home shows how far along the seven small steps you are; it
// opens the path. Steps count whenever they're done and missing a day costs nothing. Finishing earns Pimpi's scarf.
// Effort only, never skin results.

/// "First week 3/7" beside the streak, until the week is done and celebrated.
struct FirstWeekChip: View {
    let progress: FirstWeekPath.Progress
    @State private var showsPath = false

    var body: some View {
        Button { showsPath = true } label: {
            Label {
                Text("\(progress.done.count)/\(FirstWeekPath.Step.allCases.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(progress.done.count)))
            } icon: {
                Image(systemName: "shoeprints.fill")
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
        }
        .buttonStyle(.chunky(.plain, fullWidth: false))
        .accessibilityLabel(Text("First week: \(progress.done.count) of \(FirstWeekPath.Step.allCases.count) done"))
        .accessibilityIdentifier("firstWeekChip")
        .sheet(isPresented: $showsPath) { FirstWeekSheet(progress: progress) }
    }
}

/// The seven steps, done ones ticked and today's suggestion lit, with the scarf waiting at the end.
struct FirstWeekSheet: View {
    let progress: FirstWeekPath.Progress
    @Environment(\.dismiss) private var dismiss

    private enum Metrics {
        static let pimpi: CGFloat = 84
        static let mark: CGFloat = 36
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    PimpiRow {
                        Pimpi(mood: progress.isComplete ? .excited : .happy)
                            .environment(\.pimpiOutfit, .scarf)
                            .frame(width: Metrics.pimpi, height: Metrics.pimpi)
                            .accessibilityHidden(true)
                        Text(progress.isComplete ? "You did your whole first week. The scarf is yours!"
                                                 : "Seven small things. Do them any day. Finish them all and I get a scarf.")
                            .font(.ds.pimpiSmall)
                            .foregroundStyle(Color.ds.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(FirstWeekPath.Step.allCases.enumerated()), id: \.element) { index, step in
                        row(step, number: index + 1)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.ds.canvas.ignoresSafeArea())
            .navigationTitle("Your first week")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func row(_ step: FirstWeekPath.Step, number: Int) -> some View {
        let done = progress.done.contains(step)
        let isCurrent = progress.current == step
        return HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(done ? Color.ds.positive : (isCurrent ? Color.ds.signal : Color.ds.surface))
                if done {
                    Image(systemName: "checkmark").font(.footnote.weight(.heavy)).foregroundStyle(Color.ds.surface)
                } else {
                    Text("\(number)").font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(isCurrent ? Color.ds.surface : Color.ds.ink)
                }
            }
            .frame(width: Metrics.mark, height: Metrics.mark)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(FirstWeekCopy.title(step))
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .strikethrough(done, color: Color.ds.inkSecondary)
                Text(FirstWeekCopy.hint(step))
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .dsSurface(radius: Radius.medium, fill: isCurrent ? Color.ds.surface : Color.ds.surface.opacity(done ? 0.6 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? Text("Done") : (isCurrent ? Text("Up next") : Text("Not done yet")))
    }
}

/// Finishing the week: Pimpi in its new scarf.
struct FirstWeekDoneView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private enum Metrics {
        static let pimpi: CGFloat = 180
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: shown)
                .environment(\.pimpiOutfit, .scarf)
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            Text("First week done!")
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
            Text("You showed up seven times. Pimpi's new scarf is in your wardrobe.")
                .font(.ds.body.weight(.semibold))
                .foregroundStyle(Color.ds.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Yay!") { dismiss() }
                .buttonStyle(.chunky)
                .accessibilityIdentifier("firstWeekDoneClose")
        }
        .padding(Spacing.lg)
        .background(Color.ds.canvas.ignoresSafeArea())
        .onAppear { withDSAnimation(.bouncy, reduceMotion: reduceMotion) { shown = true } }
        .sensoryFeedback(.success, trigger: shown)
    }
}

enum FirstWeekCopy {
    static func title(_ step: FirstWeekPath.Step) -> LocalizedStringKey {
        switch step {
        case .firstScan: "First scan, and one product on your shelf"
        case .routine: "Tick off your routine"
        case .lesson: "Finish a Skin School lesson"
        case .productCheck: "Ask \u{201C}Is it good for me?\u{201D}"
        case .compare: "Scan again and compare"
        case .chest: "Open a quest chest"
        case .journey: "Visit your journey map"
        }
    }

    static func hint(_ step: FirstWeekPath.Step) -> LocalizedStringKey {
        switch step {
        case .firstScan: "Scan from Home; add a product on the Shelf."
        case .routine: "The morning or evening button on Home."
        case .lesson: "Two minutes, on the Shelf."
        case .productCheck: "Search any product on the Shelf."
        case .compare: "On another day: Deck, then Compare."
        case .chest: "Finish a day's quests to earn one."
        case .journey: "The journey card on the Shelf."
        }
    }
}
