import SwiftUI
import SkinalyzeKit

/// Short, paged onboarding in Pimpi's place: Pimpi hosts each step from the sky, the question and its options sit under
/// it, and the one button waits on the hill. Progress + Back on every step; optional steps can be skipped.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, goals, skinType, sensitivity, name, privacy
    }

    @AppStorage(UserProfile.Key.onboardingComplete) private var onboardingComplete = false
    @AppStorage(UserProfile.Key.name) private var name = ""
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @AppStorage(UserProfile.Key.sensitivity) private var sensitivityRaw = ""
    @AppStorage(UserProfile.Key.goals) private var goalsRaw = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var step: Step = .welcome
    @State private var goals: Set<UserProfile.Goal> = []
    @State private var showsPrivacyPolicy = false
    /// Counts the user's picks, so Pimpi hops for each one.
    @State private var cheers = 0

    private enum Metrics {
        static let pimpi: CGFloat = 150
        static let pimpiCompact: CGFloat = 110
        static let segmentHeight: CGFloat = 8
        static let segmentGap: CGFloat = 6
        static let contentWidth: CGFloat = 560
        static let hillRise: CGFloat = 40
        /// How far the hill reaches above the button.
        static let hillAbove: CGFloat = 36
        /// Where the hill starts on short and wide screens, as a fraction of the height.
        static let wideCrest: CGFloat = 0.72
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                VStack(spacing: 0) {
                    header
                    AdaptivePair(.split) {
                        host(size: Metrics.pimpi).frame(maxHeight: .infinity)
                    } secondary: {
                        VStack(spacing: 0) {
                            scrollingContent
                            footer.onHill()
                        }
                    }
                }
                .dsHill(crest: Metrics.wideCrest, showsFarHill: true)
            } else if verticalSizeClass == .compact {
                // A phone on its side, the iPhone Duo's outer display in landscape: Pimpi on the left.
                VStack(spacing: 0) {
                    header
                    HStack(spacing: Spacing.lg) {
                        host(size: Metrics.pimpiCompact)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        VStack(spacing: 0) {
                            scrollingContent
                            footer.onHill()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .dsHill(crest: Metrics.wideCrest, showsFarHill: true)
            } else {
                VStack(spacing: 0) {
                    header
                    host(size: Metrics.pimpi)
                    scrollingContent
                    footer
                        .padding(.top, Metrics.hillAbove)
                        .background(alignment: .top) { hill }
                        .onHill()
                }
                .background(Color.ds.canvas.ignoresSafeArea())
            }
        }
        .sheet(isPresented: $showsPrivacyPolicy) { PrivacyPolicyView() }
        .sensoryFeedback(Haptic.scrub, trigger: step)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if step != .welcome {
                    Button { go(-1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.chunkyIcon)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.accessibilityHidden(true)
                }
            }
            .frame(width: Chunk.iconButton, height: Chunk.iconButton + Chunk.depthSmall)
            progress
            Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    /// One segment per step; the ones you've reached are ink.
    private var progress: some View {
        HStack(spacing: Metrics.segmentGap) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.ds.ink : Color.ds.edge)
                    .frame(height: Metrics.segmentHeight)
                    .popOnChange(item == step)
            }
        }
        .dsAnimation(.bouncy, value: step)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    /// Pimpi hosts every step, with a mood (and on two steps an outfit) that fits the question.
    private func host(size: CGFloat) -> some View {
        PokablePimpi(mood: mood, size: size, cheer: cheers + step.rawValue)
            .environment(\.pimpiOutfit, outfit)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xs)
    }

    private var mood: MascotMood {
        switch step {
        case .welcome: .excited
        case .goals: .curious
        case .skinType, .name, .privacy: .happy
        case .sensitivity: .worried
        }
    }

    private var outfit: PimpiOutfit? {
        switch step {
        case .name: .partyHat
        case .privacy: .sunglasses
        default: nil
        }
    }

    private var scrollingContent: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: Metrics.contentWidth)
                .frame(maxWidth: .infinity)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// The hill the button stands on, carried on past the bottom edge.
    private var hill: some View {
        HillShape(crest: 0, rise: Metrics.hillRise)
            .fill(Color.ds.hill)
            .ignoresSafeArea(edges: [.bottom, .horizontal])
            .accessibilityHidden(true)
    }

    private var footer: some View {
        Button(action: advance) {
            Text(primaryTitle).contentTransition(.interpolate)
        }
        .buttonStyle(.chunky)
        .disabled(!canContinue)
        .frame(maxWidth: Metrics.contentWidth)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            StepText(title: "See how your skin is changing",
                     message: "A one-minute scan, private to your phone. Track breakouts by face zone and see which products actually help.")
        case .goals:
            VStack(spacing: Spacing.md) {
                StepText(title: "What would you like to focus on?", message: "Pick any — you can change this later.")
                LazyVGrid(columns: goalColumns, spacing: Spacing.sm) {
                    ForEach(UserProfile.Goal.allCases) { goal in
                        SelectCard(title: goal.title, subtitle: nil, systemImage: goal.systemImage,
                                   isSelected: goals.contains(goal), isTile: true) {
                            goals.formSymmetricDifference([goal])
                            cheers += 1
                        }
                    }
                }
            }
        case .skinType:
            VStack(spacing: Spacing.md) {
                StepText(title: "How does your skin usually feel?", message: "This shapes ingredient suggestions.")
                VStack(spacing: Spacing.sm) {
                    ForEach(SkinType.allCases, id: \.self) { type in
                        SelectCard(title: type.title, subtitle: type.blurb, systemImage: nil,
                                   isSelected: !skinTypeRaw.isEmpty && SkinType(stored: skinTypeRaw) == type) {
                            skinTypeRaw = type.rawValue.capitalized
                            cheers += 1
                        }
                    }
                }
            }
        case .sensitivity:
            VStack(spacing: Spacing.md) {
                StepText(title: "How sensitive is your skin?", message: "Does it sting or redden with new products?")
                VStack(spacing: Spacing.sm) {
                    ForEach(UserProfile.Sensitivity.allCases) { level in
                        SelectCard(title: level.title, subtitle: nil, systemImage: nil,
                                   isSelected: sensitivityRaw == level.rawValue) {
                            sensitivityRaw = level.rawValue
                            cheers += 1
                        }
                    }
                }
            }
        case .name:
            VStack(spacing: Spacing.md) {
                StepText(title: "What should we call you?", message: "Optional — used only for greetings on this phone.")
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .onSubmit(advance)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .placeSurfaceRow()
                Button("Skip") { go(1) }
                    .buttonStyle(PlaceTextButtonStyle())
            }
        case .privacy:
            VStack(spacing: Spacing.md) {
                StepText(title: "Private by design",
                         message: "Photos are analysed on this iPhone. Saved scans stay on your device and your own iCloud — never on our servers.")
                Label("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose.", systemImage: "info.circle")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard()
                Button("Read the privacy policy") { showsPrivacyPolicy = true }
                    .buttonStyle(PlaceTextButtonStyle())
            }
        }
    }

    /// Two tiles a row; one per row at the largest text sizes so the words never squeeze.
    private var goalColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top), count: count)
    }

    // MARK: - Logic

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .welcome: "Get started"
        case .privacy: "Start using Skinalyze"
        default: "Continue"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .goals: !goals.isEmpty
        case .skinType: !skinTypeRaw.isEmpty
        case .sensitivity: !sensitivityRaw.isEmpty
        default: true
        }
    }

    private func advance() {
        guard canContinue else { return }
        if step == .goals { goalsRaw = UserProfile.store(goals) }
        if step == .privacy {
            onboardingComplete = true
        } else {
            go(1)
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        withDSAnimation(.smooth, reduceMotion: reduceMotion) { step = next }
    }
}

private struct StepText: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
            Text(message)
                .font(.ds.body.weight(.semibold))
                .foregroundStyle(Color.ds.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A pressable option: a white row (or a square-ish tile) that turns ink-filled when chosen.
struct SelectCard: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isSelected: Bool
    var isTile = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let tileHeight: CGFloat = 76
    }

    var body: some View {
        Button {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion, action)
        } label: {
            Group {
                if isTile { tile } else { row }
            }
        }
        .buttonStyle(ChunkyRowStyle(look: isSelected ? .chosen : .plain))
        .popOnChange(isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(Haptic.toggle, trigger: isSelected)
    }

    private var tile: some View {
        VStack(spacing: Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage).font(.title3.weight(.bold)).accessibilityHidden(true)
            }
            Text(title)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Metrics.tileHeight)
    }

    private var row: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage).font(.title3.weight(.bold)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded).weight(.heavy))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}
