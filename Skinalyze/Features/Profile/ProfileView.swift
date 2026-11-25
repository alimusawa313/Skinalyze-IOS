import SwiftData
import SwiftUI
import SkinalyzeKit

/// Profile & settings. Neutral avatar, no gender coding; data controls and privacy in one place.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(UserProfile.Key.name) private var name = ""
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @AppStorage(UserProfile.Key.sensitivity) private var sensitivityRaw = ""
    @AppStorage(UserProfile.Key.goals) private var goalsRaw = ""
    @AppStorage(AppLock.enabledKey) private var appLockEnabled = false
    @Query private var scans: [ScanSession]
    @State private var confirmsDelete = false
    @State private var showsPrivacy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            PlacePage {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ProStatusRow()
                    #if DEBUG
                    debug
                    #endif
                    you
                    focus
                }
            } aside: {
                privacy
            } ground: {
                legal
            }
            .navigationTitle("Profile")
            .placeTitle("Profile")
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
            .confirmationDialog(Text("Delete all \(scans.count) scans?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete all scans", role: .destructive) {
                    scans.forEach { AppPersistence.delete($0, in: modelContext) }
                }
            } message: {
                Text("This removes them from this iPhone and your iCloud. It can't be undone.")
            }
        }
    }

    // MARK: Sections

    #if DEBUG
    private var debug: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            DebugAccessToggle().placeSurfaceRow()
            Text(verbatim: "Debug builds only.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                .padding(.horizontal, Spacing.xxs)
        }
    }
    #endif

    private var you: some View {
        PlaceSection("You") {
            HStack(spacing: Spacing.sm) {
                Text("Name").font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    .accessibilityHidden(true)
                TextField("Name", text: $name, prompt: Text("Your name"))
                    .textContentType(.givenName)
                    .font(PlaceType.rowTitle)
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.trailing)
            }
            .placeSurfaceRow()
            chips("Skin type") {
                ForEach(SkinType.allCases, id: \.self) { type in
                    let selected = !skinTypeRaw.isEmpty && SkinType(stored: skinTypeRaw) == type
                    Chip(type.title, isSelected: selected) {
                        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { skinTypeRaw = type.rawValue.capitalized }
                    }
                    .popOnChange(selected)
                }
            }
            chips("Sensitivity") {
                ForEach(UserProfile.Sensitivity.allCases) { level in
                    Chip(level.title, isSelected: sensitivityRaw == level.rawValue) {
                        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { sensitivityRaw = level.rawValue }
                    }
                    .popOnChange(sensitivityRaw == level.rawValue)
                }
            }
        }
    }

    private var focus: some View {
        PlaceSection("Focus") {
            let goals = UserProfile.goals(from: goalsRaw)
            WrapLayout(spacing: Spacing.xs) {
                ForEach(UserProfile.Goal.allCases) { goal in
                    Chip(goal.title, isSelected: goals.contains(goal)) {
                        withDSAnimation(.bouncy, reduceMotion: reduceMotion) {
                            goalsRaw = UserProfile.store(goals.symmetricDifference([goal]))
                        }
                    }
                    .popOnChange(goals.contains(goal))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Focus")
        }
    }

    private var privacy: some View {
        PlaceSection("Privacy & data") {
            Toggle(isOn: $appLockEnabled) {
                Text(AppLock.toggleTitle).font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
            }
            .tint(Color.ds.positive)
            .placeSurfaceRow()
            .sensoryFeedback(Haptic.toggle, trigger: appLockEnabled)
            ReminderSettingsRow()
            Group {
                HiddenScansRow()
                NavigationLink {
                    CreatorKitView()
                } label: {
                    Label("Creator kit", systemImage: "video.badge.waveform")
                }
                NavigationLink {
                    ExportView()
                } label: {
                    Label("Dermatologist visit pack", systemImage: "doc.richtext")
                }
            }
            .labelStyle(PlaceLinkLabelStyle())
            .buttonStyle(ChunkyRowStyle())
            Text("Scans stay on this iPhone and in your own iCloud. \(scans.count) scans saved.")
                .contentTransition(.numericText(value: Double(scans.count)))
                .font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .padding(.horizontal, Spacing.xxs)
        }
    }

    /// The last things on the page, on the hill.
    private var legal: some View {
        VStack(spacing: Spacing.xxs) {
            Button("Privacy policy") { showsPrivacy = true }
                .buttonStyle(PlaceTextButtonStyle())
            Button { confirmsDelete = true } label: {
                Label("Delete all scans", systemImage: "trash")
            }
            .buttonStyle(PlaceTextButtonStyle())
            .disabled(scans.isEmpty)
            Text("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose.")
                .font(.ds.caption.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
    }

    /// A caption and the chips it names, read out as one group.
    private func chips(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                .padding(.horizontal, Spacing.xxs)
                .accessibilityHidden(true)
            WrapLayout(spacing: Spacing.xs) { content() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Metrics {
        static let readingWidth: CGFloat = 720
    }

    private let sections: [(LocalizedStringKey, LocalizedStringKey)] = [
        ("1. No data collection by Skinalyze",
         "Skinalyze does not collect, store, or access your personal data or photos. All analysis runs locally on your device using Apple's on-device machine learning."),
        ("2. Data handling and storage",
         "Photo analysis happens on your device; your data never leaves it during analysis. Saved scans and products are stored in your personal iCloud account via CloudKit, which Skinalyze cannot access."),
        ("3. Facial data",
         "Face photos (and, on iPhones with Face ID, face-shape data used for the 3D view) are used only for skin tracking inside the app. They are never shared, uploaded to us, or used for advertising."),
        ("4. Product images",
         "Product photos are loaded from public product pages when you browse products. No personal data or scan data is sent with these requests."),
        ("5. Data sharing",
         "Skinalyze does not share personal data or facial photos with third parties."),
        ("6. Your rights",
         "You control all saved data. Delete scans in the app (Profile → Delete all scans) or from your iCloud settings at any time."),
        ("7. Cookies and tracking", "Skinalyze does not use cookies or tracking technologies."),
        ("8. Changes", "We may update this policy; changes will be shown in app updates."),
        ("9. Contact", "Questions? Email skinalyze.id@gmail.com"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Your privacy comes first. This explains how your data is handled when you use Skinalyze.")
                        .font(.ds.body.weight(.semibold))
                        .foregroundStyle(Color.ds.ink)
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(section.0).font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
                                .accessibilityAddTraits(.isHeader)
                            Text(section.1).font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: Metrics.readingWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .navigationTitle("Privacy policy")
            .placeTitle("Privacy policy")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

// MARK: - Shared by Profile and what hangs off it, onboarding and the paywall

/// Type that the design system has no token for yet: heavy rounded text at row size.
enum PlaceType {
    static let rowTitle = Font.system(.callout, design: .rounded).weight(.heavy)
    static let sectionTitle = Font.system(.title3, design: .rounded).weight(.heavy)
    static let link = Font.system(.subheadline, design: .rounded).weight(.heavy)
}

private enum PlaceMetrics {
    /// Widest a single column of rows gets.
    static let contentWidth: CGFloat = 560
    static let hillRise: CGFloat = 36
    /// The hill carries on below the last line, so the bottom safe area and rubber-banding never show sky under it.
    static let hillOverscroll: CGFloat = 800
    /// Where the hill starts on short and wide screens, as a fraction of the height.
    static let wideCrest: CGFloat = 0.72
    static let outline: CGFloat = 3
    static let disabledOpacity = 0.45
    static let pressedOpacity = 0.6
}

/// A screen in Pimpi's place: `sky` content on the cream sky, then `ground` content on the hill. `aside` is more sky
/// content that moves next to the ground when there are two panes.
///
/// Tall and narrow (portrait): one column that scrolls; with `pinsGround` the hill reaches the bottom of the screen and
/// nothing scrolls while everything fits. Wide or short (landscape, iPhone Duo open): two panes — either side of the
/// fold on iPhone Duo — over a low hill.
struct PlacePage<Sky: View, Aside: View, Ground: View>: View {
    private let pinsGround: Bool
    private let sky: Sky
    private let aside: Aside
    private let ground: Ground
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(pinsGround: Bool = false, @ViewBuilder sky: () -> Sky, @ViewBuilder aside: () -> Aside,
         @ViewBuilder ground: () -> Ground) {
        self.pinsGround = pinsGround
        self.sky = sky()
        self.aside = aside()
        self.ground = ground()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            AdaptivePair(.split) { leadingPane } secondary: { trailingPane }
                .dsHill(crest: PlaceMetrics.wideCrest, showsFarHill: true)
        } else if verticalSizeClass == .compact {
            // Short and narrow (a phone on its side, the iPhone Duo's outer display): no fold to keep clear of.
            HStack(spacing: 0) {
                leadingPane
                trailingPane
            }
            .dsHill(crest: PlaceMetrics.wideCrest, showsFarHill: true)
        } else if pinsGround {
            ViewThatFits(in: .vertical) {
                column
                ScrollView { column }
            }
            .background(Color.ds.canvas.ignoresSafeArea())
        } else {
            ScrollView { column }
                .background(Color.ds.canvas.ignoresSafeArea())
        }
    }

    private var column: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.lg) {
                sky
                aside
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
            .frame(maxWidth: PlaceMetrics.contentWidth)
            .frame(maxWidth: .infinity)
            ground
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
                .frame(maxWidth: PlaceMetrics.contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(alignment: .top) {
                    HillShape(crest: 0, rise: PlaceMetrics.hillRise)
                        .fill(Color.ds.hill)
                        .padding(.bottom, -PlaceMetrics.hillOverscroll)
                        .accessibilityHidden(true)
                }
                .onHill()
        }
    }

    private var leadingPane: some View {
        ScrollView {
            sky
                .padding(Spacing.lg)
                .frame(maxWidth: PlaceMetrics.contentWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var trailingPane: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                aside
                ground
            }
            .padding(Spacing.lg)
            .frame(maxWidth: PlaceMetrics.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

extension PlacePage where Aside == EmptyView {
    init(pinsGround: Bool = false, @ViewBuilder sky: () -> Sky, @ViewBuilder ground: () -> Ground) {
        self.init(pinsGround: pinsGround, sky: sky, aside: { EmptyView() }, ground: ground)
    }
}

/// A heavy heading and what belongs under it.
struct PlaceSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(PlaceType.sectionTitle)
                .foregroundStyle(Color.ds.ink)
                .padding(.horizontal, Spacing.xxs)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A pressable row or tile (an option, a plan, a link): a white rounded rectangle that stands proud of the ground and
/// sinks when pressed. `chosen` fills it with ink (the option you picked); `outlined` rings it in ink (the plan in use).
/// The label lays itself out — give it its own padding.
struct ChunkyRowStyle: ButtonStyle {
    enum Look: Sendable {
        case plain
        case chosen
        case outlined
    }

    var look: Look = .plain
    var radius: CGFloat = Radius.medium
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let motion = MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation
        configuration.label
            .foregroundStyle(look == .chosen ? Color.ds.canvas : Color.ds.ink)
            .frame(maxWidth: .infinity, minHeight: Chunk.controlHeight)
            .background(shape.fill(look == .chosen ? Color.ds.ink : Color.ds.surface))
            .overlay {
                if look == .outlined { shape.strokeBorder(Color.ds.ink, lineWidth: PlaceMetrics.outline) }
            }
            .offset(y: pressed ? Chunk.depth : 0)
            .background(shape.fill(edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
            .opacity(isEnabled ? 1 : PlaceMetrics.disabledOpacity)
            .animation(motion, value: pressed)
            .animation(motion, value: look)
            .contentShape(shape)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }

    private var edge: Color {
        if look != .plain { return Color.ds.inkEdge }
        return ground == .hill ? Color.ds.edgeOnHill : Color.ds.edge
    }
}

/// An underlined text action for the quiet things: skip, restore, policies.
struct PlaceTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PlaceType.link)
            .underline()
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: Chunk.iconButton)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? PlaceMetrics.pressedOpacity : 1) : PlaceMetrics.disabledOpacity)
    }
}

/// The label of a row that opens another screen: its title, then a chevron.
struct PlaceLinkLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            configuration.title
                .font(PlaceType.rowTitle)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}

extension View {
    /// A resting white row with the hard bottom edge (a field, a switch).
    func placeSurfaceRow() -> some View {
        padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Chunk.controlHeight, alignment: .leading)
            .dsSurface(radius: Radius.medium)
    }

    /// The bar title in the heavy rounded face. Keep `navigationTitle` too: it names the bar for VoiceOver and tests.
    func placeTitle(_ title: LocalizedStringKey) -> some View {
        toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(PlaceType.sectionTitle).foregroundStyle(Color.ds.ink)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

// MARK: - Interaction (shared by Profile, onboarding, the paywall and what hangs off Profile)

private enum BeatMetrics {
    static let popScale: CGFloat = 1.06
    static let popUp = 0.12
    static let hopHeight: CGFloat = -18
    static let hopUp = 0.16
    static let pimpiPress: CGFloat = 0.9
}

extension View {
    /// A quick spring pop (grow, settle) each time `trigger` changes. Still under Reduce Motion.
    func popOnChange(_ trigger: some Equatable) -> some View {
        modifier(BeatModifier(trigger: trigger, kind: .pop))
    }

    /// A little hop (up, land with a bounce) each time `trigger` changes. Still under Reduce Motion.
    func hopOnChange(_ trigger: some Equatable) -> some View {
        modifier(BeatModifier(trigger: trigger, kind: .hop))
    }
}

private struct BeatModifier<Trigger: Equatable>: ViewModifier {
    enum Kind { case pop, hop }

    let trigger: Trigger
    let kind: Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, beat in
            view
                .scaleEffect(kind == .pop && !reduceMotion ? 1 + beat * (BeatMetrics.popScale - 1) : 1)
                .offset(y: kind == .hop && !reduceMotion ? beat * BeatMetrics.hopHeight : 0)
        } keyframes: { _ in
            SpringKeyframe(1, duration: kind == .pop ? BeatMetrics.popUp : BeatMetrics.hopUp)
            SpringKeyframe(0, spring: .bouncy)
        }
    }
}

