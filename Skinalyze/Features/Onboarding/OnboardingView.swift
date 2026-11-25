import SwiftUI
import SkinalyzeKit

/// First run (docs/redesign/ONBOARDING-PLAN.md §4): ten short scenes in Pimpi's place. Pimpi hosts each one from the
/// sky with a prop (name tag, backpack, promise box, plan); you do one small thing; the one button waits on the hill.
/// Pimpi walking along a path is the progress; Back is always there; optional scenes can be skipped. The last scene
/// goes straight into the first scan. The scene survives rotation, folding and quitting (`@SceneStorage`).
struct OnboardingView: View {
    @AppStorage(UserProfile.Key.onboardingComplete) private var onboardingComplete = false
    @AppStorage(UserProfile.Key.name) private var name = ""
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @AppStorage(UserProfile.Key.sensitivity) private var sensitivityRaw = ""
    @AppStorage(UserProfile.Key.goals) private var goalsRaw = ""
    @SceneStorage("onboardingScene") private var storedScene: String?

    @Environment(AppModel.self) private var appModel: AppModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scene: OnboardingScene = .wake
    /// iPhone Duo half folded with the hinge across the screen: Pimpi above the fold, the question and button below.
    @State private var hasHorizontalFold = false
    @State private var flow = OnboardingSceneState()
    /// Every answer makes Pimpi hop.
    @State private var cheers = 0

    private enum Metrics {
        static let pimpi: CGFloat = 150
        static let pimpiCompact: CGFloat = 104
        /// Scenes with more to read get a smaller Pimpi, so the options stay above the hill.
        static let pimpiReading: CGFloat = 112
        static let contentWidth: CGFloat = 560
        static let hillRise: CGFloat = 40
        /// How far the hill reaches above the button.
        static let hillAbove: CGFloat = 36
        /// Where the hill starts on short and wide screens, as a fraction of the height.
        static let wideCrest: CGFloat = 0.72
        /// Tabletop: the hill starts at the fold, so the lower half is ground.
        static let tabletopCrest: CGFloat = 0.5
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPhone Duo unfolded (and other wide windows): Pimpi on one side, the question on the other.
                VStack(spacing: 0) {
                    header
                    AdaptivePair(.split) {
                        host(size: Metrics.pimpi).frame(maxHeight: .infinity)
                    } secondary: {
                        scrollingContent.safeAreaInset(edge: .bottom, spacing: 0) { footerOnFlatHill }
                    }
                }
                .dsHill(crest: Metrics.wideCrest, showsFarHill: true)
            } else if hasHorizontalFold {
                // Tabletop: nothing on the fold. The system's split puts Pimpi on the upper half (seen from a
                // distance) and the question, options and button on the lower, stable half (for touch).
                VStack(spacing: 0) {
                    header
                    AdaptivePair(.split) {
                        host(size: Metrics.pimpiReading).frame(maxHeight: .infinity)
                    } secondary: {
                        scrollingContent.safeAreaInset(edge: .bottom, spacing: 0) { footerOnFlatHill }
                    }
                }
                .dsHill(crest: Metrics.tabletopCrest, showsFarHill: true)
            } else if verticalSizeClass == .compact {
                // A phone on its side, the iPhone Duo's outer display in landscape: Pimpi on the left.
                VStack(spacing: 0) {
                    header
                    HStack(spacing: Spacing.lg) {
                        host(size: Metrics.pimpiCompact)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        scrollingContent
                            .safeAreaInset(edge: .bottom, spacing: 0) { footerOnFlatHill }
                            .frame(maxWidth: .infinity)
                    }
                }
                .dsHill(crest: Metrics.wideCrest, showsFarHill: true)
            } else {
                VStack(spacing: 0) {
                    header
                    host(size: readingScenes.contains(scene) || dynamicTypeSize.isAccessibilitySize
                         ? Metrics.pimpiReading : Metrics.pimpi)
                    // The footer is the scroll view's bottom inset: options scroll behind the hill (never under the
                    // button), and the last one can always scroll fully above it.
                    scrollingContent.safeAreaInset(edge: .bottom, spacing: 0) {
                        footer
                            .padding(.top, Metrics.hillAbove)
                            .background(alignment: .top) { hill }
                            .onHill()
                    }
                }
                .background(Color.ds.canvas.ignoresSafeArea())
            }
        }
        .onHorizontalFoldChange { hasHorizontalFold = $0 }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "resetOnboarding") { storedScene = nil }
            #endif
            scene = OnboardingFlow.resume(from: storedScene)
        }
        .onChange(of: scene) { _, new in storedScene = new.rawValue }
        .sensoryFeedback(Haptic.scrub, trigger: scene)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if OnboardingFlow.previous(before: scene) != nil {
                    Button { go(back: true) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.chunkyIcon)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("onboardingBack")
                } else {
                    Color.clear.accessibilityHidden(true)
                }
            }
            .frame(width: Chunk.iconButton, height: Chunk.iconButton + Chunk.depthSmall)
            PimpiPathProgress(progress: OnboardingFlow.progress(scene))
            // A fixed-size placeholder when there's no Skip: a bare Color.clear would grow and stretch the header.
            if OnboardingFlow.optionalScenes.contains(scene) {
                Button("Skip") { go() }
                    .buttonStyle(PlaceTextButtonStyle())
                    .fixedSize()
                    .accessibilityIdentifier("onboardingSkip")
            } else {
                Color.clear.frame(width: Chunk.iconButton, height: Chunk.iconButton).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    /// Pimpi and the scene's prop.
    private func host(size: CGFloat) -> some View {
        OnboardingHost(scene: scene, state: flow, name: name, goals: answers.goals, size: size, cheer: cheers) {
            if scene == .wake { wake() } else { cheers += 1 }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
    }

    private var scrollingContent: some View {
        ScrollView {
            OnboardingSceneContent(scene: scene, state: $flow, answers: answersBinding, cheer: { cheers += 1 },
                                   advance: advance)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: Metrics.contentWidth)
                .frame(maxWidth: .infinity)
                .id(scene)
                .transition(reduceMotion ? .opacity : .asymmetric(
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

    /// The footer where the whole screen already stands on a hill (wide and landscape layouts): an opaque strip of
    /// hill behind the button with a soft top edge, so scrolled options pass behind it instead of under the button.
    private var footerOnFlatHill: some View {
        footer
            .padding(.top, Spacing.sm)
            .background(alignment: .top) {
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.ds.hill.opacity(0), Color.ds.hill], startPoint: .top, endPoint: .bottom)
                        .frame(height: Spacing.md)
                    Color.ds.hill
                }
                .padding(.top, -Spacing.md)
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(true)
            }
            .onHill()
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button(action: primaryAction) {
                Text(primaryTitle).contentTransition(.interpolate)
            }
            .buttonStyle(.chunky)
            .disabled(!canContinue)
            .accessibilityIdentifier("onboardingContinue")
            if scene == .camera {
                Button("Look around first") { finish(scanNow: false) }
                    .buttonStyle(PlaceTextButtonStyle())
                    .accessibilityIdentifier("onboardingLookAround")
            }
        }
        .frame(maxWidth: Metrics.contentWidth)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity)
    }

    private var readingScenes: Set<OnboardingScene> { [.skinCheck, .sensitivity, .shelf, .plan] }

    // MARK: - Answers

    private var answers: OnboardingAnswers {
        var answers = OnboardingAnswers()
        answers.name = name
        answers.goals = UserProfile.goals(from: goalsRaw)
        answers.skinType = skinTypeRaw.isEmpty ? nil : SkinType(stored: skinTypeRaw)
        answers.sensitivity = UserProfile.Sensitivity(rawValue: sensitivityRaw)
        return answers
    }

    private var answersBinding: Binding<OnboardingAnswers> {
        Binding {
            answers
        } set: { new in
            name = new.name
            goalsRaw = UserProfile.store(new.goals)
            skinTypeRaw = new.skinType.map { $0.rawValue.capitalized } ?? ""
            sensitivityRaw = new.sensitivity?.rawValue ?? ""
        }
    }

    // MARK: - Logic

    private var primaryTitle: LocalizedStringKey {
        switch scene {
        case .wake: flow.isAwake ? "Hi, Pimpi!" : "Wake Pimpi"
        case .promise: flow.isSealed ? "Continue" : "Press and hold to seal it"
        case .plan: "Keep my plan"
        case .camera: flow.cameraDenied ? "Open Settings" : "Let Pimpi look"
        default: "Continue"
        }
    }

    private var canContinue: Bool {
        switch scene {
        case .promise: flow.isSealed
        case .skinCheck: answers.skinType != nil && flow.skinCheckRevealed
        default: OnboardingFlow.canContinue(scene, answers)
        }
    }

    private func primaryAction() {
        switch scene {
        case .wake where !flow.isAwake: wake()
        case .camera: Task { await askForCamera() }
        default: advance()
        }
    }

    private func wake() {
        guard !flow.isAwake else { return }
        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { flow.isAwake = true }
        cheers += 1
    }

    private func advance() {
        guard canContinue else { return }
        go()
    }

    private func go(back: Bool = false) {
        let next = back ? OnboardingFlow.previous(before: scene) : OnboardingFlow.next(after: scene)
        guard let next, next != .firstScan else { return }
        withDSAnimation(.smooth, reduceMotion: reduceMotion) { scene = next }
    }

    private func askForCamera() async {
        if flow.cameraDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
            return
        }
        let granted: Bool = switch CameraSession.authorizationStatus() {
        case .authorized: true
        case .notDetermined: await CameraSession.requestAccess()
        default: false
        }
        if granted {
            finish(scanNow: true)
        } else {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { flow.cameraDenied = true }
        }
    }

    /// Onboarding is over: straight into the coached first scan, or Home with the first-week path waiting.
    private func finish(scanNow: Bool) {
        storedScene = nil
        FirstScanCoaching.isPending = true
        FirstWeekTracking.isActive = true
        if scanNow { appModel?.startScan() }
        onboardingComplete = true
    }
}

/// What the scenes keep while the user is in them (the answers themselves are stored as they're given).
struct OnboardingSceneState: Equatable {
    var isAwake = false
    var isSealed = false
    var skinCheckRevealed = false
    var cameraDenied = false
}

/// Only people who came through this onboarding walk the first-week path (existing users get coach marks only).
enum FirstWeekTracking {
    private static let key = "firstWeekActive"

    static var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// The first scan after onboarding is coached (ONBOARDING-PLAN.md §5.1); cleared when that scan is saved.
enum FirstScanCoaching {
    private static let key = "firstScanCoachingPending"

    static var isPending: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    private static let tourKey = "resultTourPending"

    /// The coached scan was saved: its result gets the tour.
    static var resultTourPending: Bool {
        get { UserDefaults.standard.bool(forKey: tourKey) }
        set { UserDefaults.standard.set(newValue, forKey: tourKey) }
    }

    /// A scan was saved: if it was the coached one, hand over to the result tour.
    static func scanSaved() {
        guard isPending else { return }
        isPending = false
        resultTourPending = true
    }
}
