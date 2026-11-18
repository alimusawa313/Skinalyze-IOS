import SwiftUI
import SkinalyzeKit

/// Short, paged onboarding (replaces the fake chat). Progress + Back on every step; optional steps can be skipped.
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
    @State private var step: Step = .welcome
    @State private var goals: Set<UserProfile.Goal> = []
    @State private var showsPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            header
            AdaptivePair(.split) {
                illustration
            } secondary: {
                ScrollView {
                    content
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            footer
        }
        .dsCanvas()
        .sheet(isPresented: $showsPrivacyPolicy) { PrivacyPolicyView() }
        .sensoryFeedback(Haptic.scrub, trigger: step)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            if step != .welcome {
                Button { go(-1) } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            }
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(Color.ds.signal)
                .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
        }
        .frame(minHeight: 44)
        .padding(.horizontal, Spacing.lg)
    }

    private var illustration: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 0.35
            ContourMotif(phase: phase, rings: 8)
                .stroke(Color.ds.signal.opacity(0.55), lineWidth: 1.2)
                .frame(maxWidth: 240, maxHeight: 240)
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 280)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button(primaryTitle, action: advance)
                .buttonStyle(.dsPrimary)
                .disabled(!canContinue)
            if step == .name {
                Button("Skip") { go(1) }
                    .font(.subheadline)
                    .foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            StepText(title: "See how your skin is changing",
                     message: "A one-minute scan, private to your phone. Track breakouts by face zone and see which products actually help.")
        case .goals:
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepText(title: "What would you like to focus on?", message: "Pick any — you can change this later.")
                ForEach(UserProfile.Goal.allCases) { goal in
                    SelectCard(title: goal.title, subtitle: nil, systemImage: goal.systemImage,
                               isSelected: goals.contains(goal)) {
                        goals.formSymmetricDifference([goal])
                    }
                }
            }
        case .skinType:
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepText(title: "How does your skin usually feel?", message: "This shapes ingredient suggestions.")
                ForEach(SkinType.allCases, id: \.self) { type in
                    SelectCard(title: type.title, subtitle: type.blurb, systemImage: nil,
                               isSelected: !skinTypeRaw.isEmpty && SkinType(stored: skinTypeRaw) == type) {
                        skinTypeRaw = type.rawValue.capitalized
                    }
                }
            }
        case .sensitivity:
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepText(title: "How sensitive is your skin?", message: "Does it sting or redden with new products?")
                ForEach(UserProfile.Sensitivity.allCases) { level in
                    SelectCard(title: level.title, subtitle: nil, systemImage: nil, isSelected: sensitivityRaw == level.rawValue) {
                        sensitivityRaw = level.rawValue
                    }
                }
            }
        case .name:
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepText(title: "What should we call you?", message: "Optional — used only for greetings on this phone.")
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .onSubmit(advance)
                    .padding(Spacing.md)
                    .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.small))
                    .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Color.ds.hairline))
            }
        case .privacy:
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepText(title: "Private by design",
                         message: "Photos are analysed on this iPhone. Saved scans stay on your device and your own iCloud — never on our servers.")
                Label("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose.", systemImage: "info.circle")
                    .font(.ds.footnote)
                    .foregroundStyle(Color.ds.inkSecondary)
                Button("Read the privacy policy") { showsPrivacyPolicy = true }
                    .font(.subheadline.weight(.semibold))
            }
        }
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.ds.display).foregroundStyle(Color.ds.ink)
            Text(message).font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Large tappable option card used in onboarding.
struct SelectCard: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.ds.signal : Color.ds.inkSecondary)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ds.headline).foregroundStyle(Color.ds.ink)
                    if let subtitle {
                        Text(subtitle).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.ds.signal : Color.ds.hairline)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(Spacing.md)
            .background(isSelected ? Color.ds.signalSoft : Color.ds.surface,
                        in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(isSelected ? Color.ds.signal.opacity(0.5) : Color.ds.hairline))
            .dsAnimation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(Haptic.toggle, trigger: isSelected)
    }
}
