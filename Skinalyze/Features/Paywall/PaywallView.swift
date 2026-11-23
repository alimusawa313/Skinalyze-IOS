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
        case .welcome: Text("That was your first scan. Pro lets you scan as often as you like.")
        case .profile: Text("Everything Skinalyze can do, without limits.")
        }
    }
}

/// The paywall: Pimpi, what Pro adds, the plans as the App Store gives them, restore, and plain terms.
/// It can always be closed.
struct PaywallView: View {
    let reason: PaywallReason

    @Environment(ProAccess.self) private var access
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ProAccess.ProductID.annual
    @State private var isWorking = false
    @State private var message: LocalizedStringKey?
    @State private var trialEligible = false
    @State private var showsPrivacy = false

    private static let pimpiSide: CGFloat = 112
    private static let contentWidth: CGFloat = 520
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    private var selected: Product? { access.products.first { $0.id == selectedID } ?? access.products.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.xs) {
                        Pimpi(mood: .excited).frame(width: Self.pimpiSide, height: Self.pimpiSide)
                        Text(verbatim: "Skinalyze Pro").font(.ds.display)
                        reason.headline.font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    benefits
                    plans
                    footer
                }
                .padding(Spacing.lg)
                .frame(maxWidth: Self.contentWidth)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }.accessibilityIdentifier("paywallClose")
                }
            }
            .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
        }
        .task(id: selectedID) {
            trialEligible = await selected?.subscription?.isEligibleForIntroOffer ?? false
        }
        .task {
            if access.loadState != .loaded { await access.loadProducts() }
        }
        .onChange(of: access.policy.hasFullAccess) { _, full in
            if full { dismiss() }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            benefit("infinity", "Scan as often as you like")
            benefit("square.stack.3d.up", "Your whole history and Compare")
            benefit("rotate.3d", "Turn your 3D scan and export the turntable")
            benefit("checkmark.seal", "Unlimited product checks")
            benefit("sparkles", "Share without the Skinalyze mark")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func benefit(_ icon: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).font(.ds.callout)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.ds.signal)
        }
    }

    @ViewBuilder private var plans: some View {
        switch access.loadState {
        case .loaded:
            VStack(spacing: Spacing.sm) {
                ForEach(access.products, id: \.id) { product in
                    PlanRow(product: product, isSelected: product.id == selected?.id) { selectedID = product.id }
                }
                Button {
                    Task { await buy() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView()
                        } else if trialEligible, selected?.subscription?.introductoryOffer?.paymentMode == .freeTrial {
                            Text("Start free trial")
                        } else {
                            Text("Continue")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dsPrimary)
                .disabled(isWorking || selected == nil)
                .accessibilityIdentifier("paywallBuy")
                if let message {
                    Text(message).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
                }
            }
        case .unavailable:
            VStack(spacing: Spacing.sm) {
                Text("Plans aren't available right now.").font(.ds.callout)
                Button("Try again") { Task { await access.loadProducts() } }.buttonStyle(.glass)
            }
            .accessibilityIdentifier("paywallUnavailable")
        case .idle, .loading:
            ProgressView()
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            Button("Restore purchases") { Task { await restore() } }
                .font(.ds.callout.weight(.semibold))
                .disabled(isWorking)
                .accessibilityIdentifier("paywallRestore")
            Text("Plans renew automatically until you cancel. Cancel any time in Settings, at least a day before renewal. A free trial turns into the paid plan when it ends.")
                .font(.ds.caption).foregroundStyle(Color.ds.inkTertiary).multilineTextAlignment(.center)
            HStack(spacing: Spacing.lg) {
                if let url = Self.termsURL { Link("Terms of use", destination: url) }
                Button("Privacy policy") { showsPrivacy = true }
            }
            .font(.ds.caption.weight(.semibold))
        }
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

/// One plan, with the price exactly as the App Store states it.
private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.ds.signal : Color.ds.inkTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).font(.ds.headline).foregroundStyle(Color.ds.ink)
                    if product.subscription?.introductoryOffer?.paymentMode == .freeTrial {
                        Text("Includes a free trial").font(.ds.caption).foregroundStyle(Color.ds.positive)
                    }
                }
                Spacer(minLength: Spacing.xs)
                priceText.font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Color.ds.signal : Color.ds.hairline, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("plan.\(product.id)")
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

/// Profile row: shows what the user has and opens the paywall (which also holds Restore purchases).
struct ProStatusRow: View {
    @Environment(ProAccess.self) private var access
    @State private var paywall: PaywallReason?

    var body: some View {
        if access.isSubscribed {
            Label("Skinalyze Pro is active", systemImage: "checkmark.seal.fill")
        } else if access.policy.hasFullAccess {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everything is unlocked")
                    Text("You were here before Pro, so you keep it all.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
            } icon: {
                Image(systemName: "heart.fill")
            }
        } else {
            Button { paywall = .profile } label: {
                Label("See Skinalyze Pro", systemImage: "sparkles")
            }
            .accessibilityIdentifier("profilePro")
            .paywallSheet($paywall)
        }
    }
}

/// Over a scan card that free history no longer opens.
struct LockedCardCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: Spacing.xs) {
                Image(systemName: "lock.fill").font(.title)
                Text(verbatim: "Pro").font(.ds.headline)
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
            Label("Product check", systemImage: "lock.fill").font(.ds.headline)
            Text("You've used this month's \(FreeLimits.productChecksPerMonth) free product checks. Products you already checked stay open.")
                .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
            Button { paywall = .productChecks } label: {
                Text("See Skinalyze Pro").frame(maxWidth: .infinity)
            }
            .buttonStyle(.dsPrimary)
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
            Text(verbatim: "Act as a free user")
        }
    }
}
#endif
