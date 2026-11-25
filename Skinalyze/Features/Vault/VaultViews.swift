import SwiftData
import SwiftUI
import SkinalyzeKit

// P13 private vault: hide a scan from the Mirror, Deck, widgets and exports; see hidden scans only after Face ID /
// Touch ID / passcode. "Keep it secret" also removes the vault's entry from Profile — then it opens by pressing and
// holding the Deck title, so someone browsing the phone wouldn't know it's there.

enum Vault {
    static let secretKey = "vaultSecret"
}

/// On a scan: hide it, or show it again.
struct HideScanButton: View {
    let session: ScanSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        Menu {
            if session.isHidden {
                Button("Show in Mirror and Deck", systemImage: "eye") { setHidden(false) }
            } else {
                Button("Hide this scan", systemImage: "eye.slash") { confirming = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityIdentifier("scanMore")
        .confirmationDialog("Hide this scan?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Hide", role: .destructive) {
                setHidden(true)
                dismiss()
            }
        } message: {
            Text("It leaves the Mirror, Deck, widgets and exports. Find it again in Profile → Hidden scans, behind \(AppLock.biometryName).")
        }
    }

    private func setHidden(_ hidden: Bool) {
        session.isHidden = hidden
        try? modelContext.save()
    }
}

/// The hidden scans, after authentication every time the list opens. Dusk in Pimpi's place: Pimpi in sunglasses
/// guards them on the hill.
struct HiddenScansView: View {
    @Query(filter: #Predicate<ScanSession> { $0.isHidden }, sort: \ScanSession.createdAt, order: .reverse)
    private var scans: [ScanSession]
    @AppStorage(Vault.secretKey) private var secret = false
    @State private var unlocked = false
    @State private var failed = false
    /// The scheme outside the vault, so a scan opened from here looks like it does everywhere else.
    @Environment(\.colorScheme) private var outsideScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let pimpi: CGFloat = 170
        static let pimpiCompact: CGFloat = 110
        static let hillRise: CGFloat = 40
        /// How far the hill rises behind Pimpi's feet.
        static let hillOverlap: CGFloat = 30
        static let rowHeight: CGFloat = 64
        static let maxWidth: CGFloat = 520
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pokable; hops when the vault opens and when secret mode flips.
                PokablePimpi(mood: unlocked ? .excited : .happy, size: pimpiSize, cheer: "\(unlocked)-\(secret)")
                    .environment(\.pimpiOutfit, .sunglasses)
                    .padding(.top, Spacing.sm)
                    .zIndex(1) // Pimpi stands in front of the hill that rises behind its feet
                VStack(spacing: Spacing.lg) {
                    SpeechBubble(Text(line), tail: .up)
                        .id(line.key)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                    if unlocked { list } else { locked }
                }
                .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: unlocked)
                .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: secret)
                .frame(maxWidth: Metrics.maxWidth)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: .infinity)
                .background(alignment: .top) {
                    HillShape(crest: 0, rise: Metrics.hillRise)
                        .fill(Color.ds.hill)
                        .padding(.top, -Metrics.hillOverlap)
                        .accessibilityHidden(true)
                }
                .onHill()
            }
        }
        // Sky above, hill below, so overscroll and short content never show a seam.
        .background {
            VStack(spacing: 0) {
                Color.ds.canvas
                Color.ds.hill
            }
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark) // the vault is dusk by design
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Hidden scans")
        .toolbarTitleDisplayMode(.inline)
        .task { await unlock() }
        .sensoryFeedback(Haptic.success, trigger: unlocked) { _, isUnlocked in isUnlocked }
        .sensoryFeedback(Haptic.failure, trigger: failed) { _, didFail in didFail }
        .sensoryFeedback(Haptic.toggle, trigger: secret)
    }

    private var pimpiSize: CGFloat { verticalSizeClass == .compact ? Metrics.pimpiCompact : Metrics.pimpi }

    /// About keeping a secret, never about the scans themselves.
    private var line: LocalizedStringResource {
        guard unlocked else { return "Shh. I'm guarding these." }
        return secret ? "What vault? Never heard of it." : "Just between us."
    }

    private var locked: some View {
        VStack(spacing: Spacing.lg) {
            Label {
                Text(failed ? "Couldn't unlock. Try again." : "Unlock with \(AppLock.biometryName) to see them.")
            } icon: {
                Image(systemName: "lock.fill").symbolEffect(.wiggle, value: failed)
            }
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            Button("Unlock") { Task { await unlock() } }
                .buttonStyle(.chunky)
                .accessibilityIdentifier("vaultUnlock")
        }
    }

    private var list: some View {
        VStack(spacing: Spacing.sm) {
            if scans.isEmpty {
                Text("No hidden scans. Hide one from its result screen (••• → Hide this scan).")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
            }
            ForEach(Array(scans.enumerated()), id: \.element.id) { offset, scan in
                NavigationLink {
                    ScanResultView(session: scan).environment(\.colorScheme, outsideScheme)
                } label: {
                    HStack {
                        Text(scan.createdAt, format: .dateTime.day().month().year().hour().minute())
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Spacing.xs)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                }
                .buttonStyle(.chunky(.plain, fullWidth: true, minHeight: Metrics.rowHeight))
                .popIn(delay: MotionToken.stagger(offset))
            }
            secretToggle
                .padding(.top, Spacing.sm)
                .popIn(delay: MotionToken.stagger(scans.count))
        }
    }

    private var secretToggle: some View {
        Toggle(isOn: $secret) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Keep hidden scans secret")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                Text("Removes Hidden scans from Profile. To open it, press and hold the Deck title.")
                    .font(.ds.footnote)
                    .foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .tint(Color.ds.positive)
        .accessibilityIdentifier("vaultSecret")
        .dsCard(padding: Spacing.md)
    }

    private func unlock() async {
        #if DEBUG
        // UI tests can't answer Face ID.
        if UserDefaults.standard.bool(forKey: "vaultSkipAuth") {
            unlocked = true
            return
        }
        #endif
        unlocked = await AppLock.authenticate()
        failed = !unlocked
    }
}

/// Profile's entry, unless the user keeps the vault secret.
struct HiddenScansRow: View {
    @AppStorage(Vault.secretKey) private var secret = false

    var body: some View {
        if !secret {
            NavigationLink {
                HiddenScansView()
            } label: {
                Label("Hidden scans", systemImage: "eye.slash")
            }
            .accessibilityIdentifier("hiddenScansRow")
        }
    }
}
