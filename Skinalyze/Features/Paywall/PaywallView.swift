import StoreKit
import SwiftUI
import SkinalyzeKit

/// Why the paywall opened — it decides the first line the user reads.
enum PaywallReason: Identifiable, Equatable {
    case scanLimit(nextFreeScan: Date)
    case history
    case turn3D
    case turntable
    case productChecks
    case school
    case areaHistory
    case zoneMap
    case dupes
    case dermPack
    case healthPatterns
    case welcome
    case profile

    var id: String {
        switch self {
        case .scanLimit: "scanLimit"
        case .history: "history"
        case .turn3D: "turn3D"
        case .turntable: "turntable"
        case .productChecks: "productChecks"
        case .school: "school"
        case .areaHistory: "areaHistory"
        case .zoneMap: "zoneMap"
        case .dupes: "dupes"
        case .dermPack: "dermPack"
        case .healthPatterns: "healthPatterns"
        case .welcome: "welcome"
        case .profile: "profile"
        }
    }

    var headline: Text {
        switch self {
        case .scanLimit:
            Text("Today's free scan is done. Your next one opens at midnight.")
        case .history: Text("Free keeps your newest \(FreeLimits.historyScans) scans open. Pro opens them all.")
        case .turn3D: Text("Turn your 3D scan and see every side with Pro.")
        case .turntable: Text("The 3D turntable video comes with Pro.")
        case .productChecks: Text("You've used this month's \(FreeLimits.productChecksPerMonth) free product checks.")
        case .school: Text("The rest of Skin School comes with Pro.")
        case .areaHistory: Text("Follow any patch of skin through every scan with Pro.")
        case .zoneMap: Text("See every area of your face over time with Pro.")
        case .dupes: Text("Find products with a similar formula with Pro.")
        case .dermPack: Text("The dermatologist visit pack comes with Pro.")
        case .healthPatterns: Text("See your sleep and cycle next to your scans with Pro.")
        case .welcome: Text("That was your first scan. Pro lets you scan as often as you like.")
        case .profile: Text("Everything Skinalyze can do, without limits.")
        }
    }
}

/// The paywall in Pimpi's place: Pimpi in its crown and what Pro adds on the sky, the plans as the App Store gives
/// them, the one button, restore and plain terms on the hill. It can always be closed.
struct PaywallView: View {
    let reason: PaywallReason

    @Environment(ProAccess.self) private var access
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = ProAccess.ProductID.annual
    @State private var isWorking = false
    @State private var message: LocalizedStringKey?
    @State private var trialEligible = false
    @State private var showsPrivacy = false
    /// Pimpi hops when the paywall opens and whenever a plan is picked.
    @State private var hops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let pimpi: CGFloat = 124
    }

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    private var selected: Product? { access.products.first { $0.id == selectedID } ?? access.products.first }

    var body: some View {
        PlacePage {
            VStack(spacing: Spacing.lg) {
                hero
                benefits
            }
        } ground: {
            VStack(spacing: Spacing.md) {
                plans
                footer
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
        .task(id: selectedID) {
            trialEligible = await selected?.subscription?.isEligibleForIntroOffer ?? false
        }
        .task {
            if access.loadState != .loaded { await access.loadProducts() }
        }
        .onAppear { hops += 1 }
        .onChange(of: selectedID) { hops += 1 }
        .sensoryFeedback(Haptic.toggle, trigger: selectedID)
        .onChange(of: access.policy.hasFullAccess) { _, full in
            if full { dismiss() }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Not now") { dismiss() }
                .buttonStyle(.chunky(.plain, fullWidth: false))
                .accessibilityIdentifier("paywallClose")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .background(Color.ds.canvas)
    }

    private var hero: some View {
        VStack(spacing: Spacing.xs) {
            PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: hops)
                .environment(\.pimpiOutfit, .crown)
            Text(verbatim: "Skinalyze Pro")
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
                .accessibilityAddTraits(.isHeader)
            reason.headline
                .font(.ds.callout.weight(.semibold))
                .foregroundStyle(Color.ds.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            benefit("Scan as often as you like")
            benefit("Your whole history and Compare")
            benefit("Turn your 3D scan and export the turntable")
            benefit("Unlimited product checks")
            benefit("Share without the Skinalyze mark")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xs)
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.ds.canvas, Color.ds.positive)
        }
    }

    @ViewBuilder private var plans: some View {
        switch access.loadState {
        case .loaded:
            VStack(spacing: Spacing.sm) {
                ForEach(access.products, id: \.id) { product in
                    PlanRow(product: product, isSelected: product.id == selected?.id) {
                        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { selectedID = product.id }
                    }
                }
                Button {
                    Task { await buy() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView().tint(Color.ds.canvas)
                        } else if trialEligible, selected?.subscription?.introductoryOffer?.paymentMode == .freeTrial {
                            Text("Start free trial").transition(.push(from: .bottom))
                        } else {
                            Text("Continue").transition(.push(from: .bottom))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .dsAnimation(.bouncy, value: trialEligible)
                }
                .buttonStyle(.chunky)
                .disabled(isWorking || selected == nil)
                .padding(.top, Spacing.xs)
                .accessibilityIdentifier("paywallBuy")
                if let message {
                    Text(message).font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.ink)
                        .multilineTextAlignment(.center)
                }
            }
        case .unavailable:
            VStack(spacing: Spacing.sm) {
                Text("Plans aren't available right now.").font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
                Button("Try again") { Task { await access.loadProducts() } }
                    .buttonStyle(.chunky(.plain, fullWidth: false))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywallUnavailable")
        case .idle, .loading:
            ProgressView().tint(Color.ds.ink)
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Button("Restore purchases") { Task { await restore() } }
                .buttonStyle(PlaceTextButtonStyle())
                .disabled(isWorking)
                .accessibilityIdentifier("paywallRestore")
            Text("Plans renew automatically until you cancel. Cancel any time in Settings, at least a day before renewal. A free trial turns into the paid plan when it ends.")
                .font(.ds.caption.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.xs) {
                if let url = Self.termsURL {
                    Button("Terms of use") { openURL(url) }
                        .accessibilityAddTraits(.isLink)
                }
                Button("Privacy policy") { showsPrivacy = true }
            }
            .buttonStyle(PlaceTextButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private func buy() async {
        guard let selected else { return }
        isWorking = true
        message = nil
        let outcome = await access.purchase(selected)
        isWorking = false
        switch outcome {
        case .success: dismiss()
        case .cancelled: break
        case .pending: message = "Your purchase is waiting for approval."
        case .failed: message = "The purchase didn't go through. You weren't charged."
        }
    }

    private func restore() async {
        isWorking = true
        message = nil
        let restored = await access.restore()
        isWorking = false
        if restored { dismiss() } else { message = "No earlier purchase was found for this Apple Account." }
    }
}

/// One plan, with the price exactly as the App Store states it: a white row with a radio dot; the chosen one is
/// ringed in ink.
private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let radio: CGFloat = 24
        static let radioRing: CGFloat = 3
        static let radioDot: CGFloat = 12
    }

    var body: some View {
        Button(action: select) {
            HStack(spacing: Spacing.sm) {
                radio
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).font(.system(.headline, design: .rounded).weight(.heavy))
                    if product.subscription?.introductoryOffer?.paymentMode == .freeTrial {
                        Text("Includes a free trial")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.ds.positive)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.xs)
                priceText.font(PlaceType.rowTitle)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(ChunkyRowStyle(look: isSelected ? .outlined : .plain))
        .popOnChange(isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("plan.\(product.id)")
    }

    private var radio: some View {
        Circle()
            .strokeBorder(Color.ds.ink, lineWidth: Metrics.radioRing)
            .frame(width: Metrics.radio, height: Metrics.radio)
            .overlay {
                Circle().fill(Color.ds.ink)
                    .frame(width: Metrics.radioDot, height: Metrics.radioDot)
                    .scaleEffect(isSelected ? 1 : 0)
            }
            .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: isSelected)
            .accessibilityHidden(true)
    }

    private var priceText: Text {
        switch product.subscription?.subscriptionPeriod.unit {
        case .week: Text("\(product.displayPrice) a week")
        case .month: Text("\(product.displayPrice) a month")
        case .year: Text("\(product.displayPrice) a year")
        default: Text(product.displayPrice)
        }
    }
}

extension View {
    /// Presents the paywall for a reason set by this screen. Each gated screen owns its own sheet, so the paywall
    /// can open on top of whatever sheet is already showing.
    func paywallSheet(_ reason: Binding<PaywallReason?>) -> some View {
        sheet(item: reason) { PaywallView(reason: $0) }
    }
}

/// Profile row: shows what the user has and opens the paywall (which also holds Restore purchases). Pimpi wears its
/// crown here.
struct ProStatusRow: View {
    @Environment(ProAccess.self) private var access
    @State private var paywall: PaywallReason?

    private enum Metrics {
        static let pimpi: CGFloat = 64
        static let rowHeight: CGFloat = 72
    }

    var body: some View {
        if access.isSubscribed {
            resting {
                Text("Skinalyze Pro is active").font(PlaceType.rowTitle)
            }
        } else if access.policy.hasFullAccess {
            resting {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everything is unlocked").font(PlaceType.rowTitle)
                    Text("You were here before Pro, so you keep it all.")
                        .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                }
            }
        } else {
            Button { paywall = .profile } label: {
                HStack(spacing: Spacing.xs) {
                    crownedPimpi
                    Text("See Skinalyze Pro")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .accessibilityHidden(true)
                }
                .padding(.leading, Spacing.xs)
                .padding(.trailing, Spacing.lg)
                .frame(minHeight: Metrics.rowHeight)
            }
            .buttonStyle(ChunkyRowStyle(look: .chosen, radius: Radius.large))
            .accessibilityIdentifier("profilePro")
            .paywallSheet($paywall)
        }
    }

    private var crownedPimpi: some View {
        Pimpi(mood: .excited)
            .environment(\.pimpiOutfit, .crown)
            .frame(width: Metrics.pimpi, height: Metrics.pimpi)
    }

    /// What you have, as a resting white row with Pimpi.
    private func resting(@ViewBuilder _ text: () -> some View) -> some View {
        HStack(spacing: Spacing.xs) {
            crownedPimpi
            text()
                .foregroundStyle(Color.ds.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.lg)
        .frame(minHeight: Metrics.rowHeight)
        .dsSurface(radius: Radius.large)
        .accessibilityElement(children: .combine)
    }
}

/// Over a scan card that free history no longer opens.
struct LockedCardCover: View {
    private enum Metrics {
        static let veil = 0.88
    }

    var body: some View {
        ZStack {
            Rectangle().fill(Color.ds.canvas.opacity(Metrics.veil))
            VStack(spacing: Spacing.xs) {
                Image(systemName: "lock.fill").font(.title)
                Text(verbatim: "Pro").font(PlaceType.sectionTitle)
            }
            .foregroundStyle(Color.ds.ink)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Shows a product verdict when this month's free checks allow it, and otherwise says why with a way to Pro.
/// Records the check the first time it is shown.
struct ProductCheckGate<Content: View>: View {
    let key: String
    @Binding var allowed: Bool?
    @ViewBuilder let content: Content

    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @State private var paywall: PaywallReason?

    var body: some View {
        Group {
            switch allowed {
            case .some(true): content
            case .some(false): locked
            case .none: ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task(id: key) {
            let policy = access?.policy ?? AccessPolicy(hasFullAccess: true)
            let ledger = ProductCheckLedger()
            let canCheck = ledger.canCheck(key, policy: policy)
            if canCheck {
                let isNew = ledger.record(key)
                quests?.did(.productCheck, isPro: policy.hasFullAccess, counts: isNew)
            }
            allowed = canCheck
        }
        .onChange(of: access?.policy.hasFullAccess) { _, full in
            if full == true { allowed = true }
        }
        .paywallSheet($paywall)
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Product check", systemImage: "lock.fill").font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
            Text("You've used this month's \(FreeLimits.productChecksPerMonth) free product checks. Products you already checked stay open.")
                .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
            Button { paywall = .productChecks } label: {
                Text("See Skinalyze Pro").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky)
            .accessibilityIdentifier("productCheckLocked")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}

#if DEBUG
/// Profile, debug builds only: see the app as a free user on a phone that keeps everything.
struct DebugAccessToggle: View {
    @Environment(ProAccess.self) private var access

    var body: some View {
        Toggle(isOn: Binding(get: { access.debugOverride == false }, set: { access.setDebugOverride($0 ? false : nil) })) {
            Text(verbatim: "Act as a free user").font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
        }
        .tint(Color.ds.positive)
    }
}
#endif
