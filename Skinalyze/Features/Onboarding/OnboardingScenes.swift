import SwiftUI
import SkinalyzeKit

// The scenes of the first run (ONBOARDING-PLAN.md §4). `OnboardingHost` is Pimpi and the scene's prop up in the sky;
// `OnboardingSceneContent` is the question and its options under it. Every gesture has a plain button alternative.

/// Pimpi up in the sky, in the scene's mood and pose, with the scene's prop beside it.
struct OnboardingHost: View {
    let scene: OnboardingScene
    let state: OnboardingSceneState
    let name: String
    let goals: Set<UserProfile.Goal>
    let size: CGFloat
    let cheer: Int
    let poke: () -> Void

    @AppStorage(UserProfile.Key.sensitivity) private var sensitivityRaw = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if scene == .promise { PromiseBox(isSealed: state.isSealed) }
            PokablePimpi(mood: mood, size: size, cheer: cheer, onPoke: poke)
                .environment(\.pimpiPose, pose)
                .environment(\.pimpiOutfit, outfit)
                .accessibilityLabel(Text(scene == .wake && !state.isAwake ? "Pimpi, asleep. Tap to wake" : "Pimpi"))
                .accessibilityIdentifier("onboardingPimpi")
            if scene == .goals {
                GoalBackpack(goals: UserProfile.Goal.allCases.filter(goals.contains))
            }
            if scene == .hello { NameTag(name: name).padding(.bottom, Spacing.lg) }
        }
    }

    private var mood: MascotMood {
        switch scene {
        case .wake: state.isAwake ? .excited : .sleepy
        case .goals, .shelf, .plan: .excited
        case .skinCheck, .camera: .curious
        case .sensitivity: sensitivityRaw == UserProfile.Sensitivity.very.rawValue ? .worried : .happy
        case .hello, .promise, .firstScan: .happy
        }
    }

    private var pose: PimpiPose? {
        switch scene {
        case .wake where state.isAwake: .wave
        case .hello: .wave
        default: nil
        }
    }

    private var outfit: PimpiOutfit? {
        switch scene {
        case .promise where state.isSealed: .sunglasses
        case .plan: .partyHat
        default: nil
        }
    }
}

struct OnboardingSceneContent: View {
    let scene: OnboardingScene
    @Binding var state: OnboardingSceneState
    @Binding var answers: OnboardingAnswers
    let cheer: () -> Void
    let advance: () -> Void

    @Environment(AppModel.self) private var appModel: AppModel?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsPrivacyPolicy = false

    var body: some View {
        Group {
            switch scene {
            case .wake: wake
            case .hello: hello
            case .goals: goals
            case .skinCheck: SkinCheckScene(answers: $answers, revealed: $state.skinCheckRevealed, cheer: cheer)
            case .sensitivity: sensitivity
            case .shelf: OnboardingShelf()
            case .promise: promise
            case .plan: plan
            case .camera, .firstScan: camera
            }
        }
        .sheet(isPresented: $showsPrivacyPolicy) { PrivacyPolicyView() }
    }

    // MARK: Scenes

    @ViewBuilder private var wake: some View {
        if state.isAwake {
            StepText(title: "Hi, I'm Pimpi!",
                     message: "I'll help you keep an eye on your skin: one quick scan a day, private to your phone.")
        } else {
            StepText(title: "Psst… Pimpi's napping",
                     message: "Tap Pimpi to wake it up.")
        }
    }

    private var hello: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "What should I call you?", message: "Optional. It stays on this phone.")
            TextField("Your name", text: $answers.name)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .onSubmit(advance)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .placeSurfaceRow()
                .accessibilityIdentifier("onboardingName")
            if appModel?.pendingInvite != nil {
                Label("A friend invited you. You'll be friends once we're done.", systemImage: "person.2.fill")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
                    .dsCard()
            }
        }
    }

    private var goals: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "What are we packing for?", message: "Pick any. Tap again to take it out.")
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(UserProfile.Goal.allCases) { goal in
                    SelectCard(title: goal.title, subtitle: nil, systemImage: goal.systemImage,
                               isSelected: answers.goals.contains(goal), isTile: true) {
                        answers.goals.formSymmetricDifference([goal])
                        cheer()
                    }
                    .accessibilityIdentifier("goal.\(goal.rawValue)")
                }
            }
        }
    }

    private var sensitivity: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "When you try something new…", message: "How does your skin usually react?")
            VStack(spacing: Spacing.sm) {
                ForEach(UserProfile.Sensitivity.allCases) { level in
                    SelectCard(title: SensitivityCopy.answer(level), subtitle: nil, systemImage: nil,
                               isSelected: answers.sensitivity == level) {
                        answers.sensitivity = level
                        cheer()
                    }
                    .accessibilityIdentifier("sensitivity.\(level.id)")
                }
            }
            if answers.sensitivity == .very {
                Text("Then we'll go gently. I'll remind you to patch-test new things first.")
                    .font(.ds.pimpiSmall)
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    private var promise: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "My promise to you",
                     message: "Your photos stay on this iPhone and in your own iCloud. Never on our servers.")
            HoldToSeal(isSealed: $state.isSealed, tapSeals: typeSize.isAccessibilitySize)
            Label("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose.", systemImage: "info.circle")
                .font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsCard()
            Button("Read the privacy policy") { showsPrivacyPolicy = true }
                .buttonStyle(PlaceTextButtonStyle())
        }
    }

    private var plan: some View {
        let skinType = answers.skinType ?? .normal
        return StarterPlanCard(plan: StarterPlan.make(goals: answers.goals, skinType: skinType,
                                                      sensitivity: answers.sensitivity ?? .notSensitive),
                               skinType: skinType)
    }

    private var camera: some View {
        VStack(spacing: Spacing.md) {
            if state.cameraDenied {
                StepText(title: "No problem",
                         message: "You can let me use the camera in Settings any time. Everything else works without it.")
            } else {
                StepText(title: "Let me take a look",
                         message: "I look at your skin right here on your phone, with the front camera. Nothing is uploaded.")
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.sm, alignment: .top),
              count: typeSize.isAccessibilitySize ? 1 : 2)
    }
}

enum SensitivityCopy {
    static func answer(_ level: UserProfile.Sensitivity) -> String {
        switch level {
        case .notSensitive: String(localized: "It's usually fine")
        case .somewhat: String(localized: "Sometimes it gets a bit red")
        case .very: String(localized: "It often stings or turns red")
        }
    }
}

// MARK: - Midday check

/// Three quick questions instead of "what's your skin type?". "I already know" skips to the four types.
private struct SkinCheckScene: View {
    @Binding var answers: OnboardingAnswers
    @Binding var revealed: Bool
    let cheer: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picked: [SkinTypeQuiz.Answer] = []
    @State private var choosingMyself = false

    private let questions = SkinTypeQuiz.Question.allCases

    var body: some View {
        VStack(spacing: Spacing.md) {
            if revealed, let type = answers.skinType {
                result(type)
            } else if choosingMyself {
                chooser
            } else {
                question
            }
        }
        .onAppear { if answers.skinType != nil { revealed = true } }
    }

    private var question: some View {
        let index = min(picked.count, questions.count - 1)
        let current = questions[index]
        return VStack(spacing: Spacing.md) {
            StepText(title: SkinCheckCopy.question(current), message: "Question \(index + 1) of \(questions.count)")
                .id(current)
                .transition(.push(from: .trailing))
            VStack(spacing: Spacing.sm) {
                ForEach(SkinTypeQuiz.Answer.allCases, id: \.self) { answer in
                    SelectCard(title: SkinCheckCopy.answer(answer, for: current), subtitle: nil,
                               systemImage: SkinCheckCopy.icon(answer), isSelected: false) {
                        pick(answer)
                    }
                    .accessibilityIdentifier("skinCheck.\(answer)")
                }
            }
            Button("I already know my skin type") {
                withDSAnimation(.smooth, reduceMotion: reduceMotion) { choosingMyself = true }
            }
            .buttonStyle(PlaceTextButtonStyle())
            .accessibilityIdentifier("skinCheckKnow")
        }
    }

    private func pick(_ answer: SkinTypeQuiz.Answer) {
        cheer()
        withDSAnimation(.smooth, reduceMotion: reduceMotion) {
            picked.append(answer)
            if picked.count == questions.count {
                answers.skinType = SkinTypeQuiz.result(tZone: picked[0], cheeks: picked[1], afterWashing: picked[2])
                revealed = true
            }
        }
    }

    private func result(_ type: SkinType) -> some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "Sounds like \(type.title.lowercased()) skin", message: LocalizedStringKey(type.blurb))
            Button("Not quite? Choose it yourself") {
                withDSAnimation(.smooth, reduceMotion: reduceMotion) {
                    revealed = false
                    choosingMyself = true
                }
            }
            .buttonStyle(PlaceTextButtonStyle())
        }
    }

    private var chooser: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "How does your skin usually feel?", message: "This shapes ingredient suggestions.")
            VStack(spacing: Spacing.sm) {
                ForEach(SkinType.allCases, id: \.self) { type in
                    SelectCard(title: type.title, subtitle: type.blurb, systemImage: nil, isSelected: answers.skinType == type) {
                        answers.skinType = type
                        cheer()
                        withDSAnimation(.smooth, reduceMotion: reduceMotion) { revealed = true }
                    }
                }
            }
            Button("Take the quick check instead") {
                withDSAnimation(.smooth, reduceMotion: reduceMotion) {
                    picked = []
                    choosingMyself = false
                }
            }
            .buttonStyle(PlaceTextButtonStyle())
        }
    }
}

enum SkinCheckCopy {
    static func question(_ question: SkinTypeQuiz.Question) -> LocalizedStringKey {
        switch question {
        case .tZone: "By midday, your forehead and nose are…"
        case .cheeks: "Your cheeks usually feel…"
        case .afterWashing: "Half an hour after washing, with nothing on, your skin feels…"
        }
    }

    static func answer(_ answer: SkinTypeQuiz.Answer, for question: SkinTypeQuiz.Question) -> String {
        switch (question, answer) {
        case (.tZone, .oily): String(localized: "Shiny")
        case (.tZone, .balanced): String(localized: "About the same as morning")
        case (.tZone, .dry): String(localized: "Tight or a bit flaky")
        case (.cheeks, .oily): String(localized: "Shiny too")
        case (.cheeks, .balanced): String(localized: "Comfortable")
        case (.cheeks, .dry): String(localized: "Tight or rough")
        case (.afterWashing, .oily): String(localized: "Already a bit oily again")
        case (.afterWashing, .balanced): String(localized: "Comfortable")
        case (.afterWashing, .dry): String(localized: "Tight, I want moisturiser")
        }
    }

    static func icon(_ answer: SkinTypeQuiz.Answer) -> String {
        switch answer {
        case .oily: "sparkles"
        case .balanced: "face.smiling"
        case .dry: "wind"
        }
    }
}

// MARK: - Your shelf

/// Four empty spots on a shelf; tap one to find the product. Optional.
private struct OnboardingShelf: View {
    @State private var picking: ProductCatalog.Slot?
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0

    var body: some View {
        VStack(spacing: Spacing.md) {
            StepText(title: "What's on your shelf?",
                     message: "Add what you use now, so I can check it against your skin. You can skip this.")
            VStack(spacing: Spacing.sm) {
                ForEach(ProductCatalog.Slot.allCases) { slot in
                    let product = ProductCatalog.shared.product(id: id(for: slot))
                    Button { picking = slot } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: product == nil ? "plus.circle.fill" : slot.systemImage)
                                .font(.title3.weight(.bold))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.title).font(.system(.headline, design: .rounded).weight(.heavy))
                                Text(product.map { "\($0.brand) · \($0.name)" } ?? String(localized: "Add"))
                                    .font(.system(.footnote, design: .rounded).weight(.bold))
                                    .opacity(0.85) // softer than the title, still readable on white and on ink
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(ChunkyRowStyle(look: product == nil ? .plain : .chosen))
                    .popOnChange(product != nil)
                    .accessibilityIdentifier("onboardingSlot.\(slot.rawValue)")
                }
            }
        }
        .sheet(item: $picking) { ProductPicker(slot: $0) }
    }

    private func id(for slot: ProductCatalog.Slot) -> Int {
        switch slot {
        case .cleanser: cleanser
        case .toner: toner
        case .moisturizer: moisturizer
        case .sunscreen: sunscreen
        }
    }
}

// MARK: - Shared pieces

struct StepText: View {
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
                        .opacity(0.85) // softer than the title, still readable on white and on ink
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}
