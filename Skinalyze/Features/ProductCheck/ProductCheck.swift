import SwiftData
import SwiftUI
import VisionKit
import SkinalyzeKit

/// Builds the personal verdict profile from the user's settings, latest scan and current routine.
@MainActor
enum VerdictProfileBuilder {
    static func make(latest: ScanSession?) -> VerdictProfile {
        let defaults = UserDefaults.standard
        let sensitivity = defaults.string(forKey: UserProfile.Key.sensitivity) ?? ""
        let routine = UserProfile.currentProductIDs
            .compactMap(ProductCatalog.shared.product(id:))
            .flatMap(\.ingredientList)
            .map { $0.lowercased() }
        return VerdictProfile(
            skinType: SkinType(stored: defaults.string(forKey: UserProfile.Key.skinType) ?? ""),
            isSensitive: !sensitivity.isEmpty && sensitivity != UserProfile.Sensitivity.notSensitive.rawValue,
            latestCounts: latest?.counts ?? LesionCounts(),
            routineCategories: ProductVerdictEngine.categories(of: routine)
        )
    }
}

extension ProductVerdict {
    /// Pimpi's face next to a verdict. Pimpi reacts; it never says anything about the verdict.
    var pimpiMood: MascotMood {
        switch self {
        case .goodMatch: .happy
        case .useWithCaution, .probablyNotForYou: .worried
        case .notEnoughInfo: .curious
        }
    }

    var tint: Color {
        switch self {
        case .goodMatch: .ds.positive
        case .useWithCaution: .ds.caution
        case .probablyNotForYou: .ds.signal
        case .notEnoughInfo: .ds.inkSecondary
        }
    }
}

/// "Is this good for me?" — deterministic verdict with reasons (never an LLM decision): one big coloured line with
/// its icon, the reasons under it, and Pimpi beside it pulling a face that matches.
struct VerdictCard: View {
    let result: VerdictResult
    /// Off where Pimpi already stands nearby (the label check), so there is only one of it on screen.
    var showsPimpi = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown = false

    private enum Metrics {
        static let pimpi: CGFloat = 84
        static let reasonRise: CGFloat = 8
        static let maxReasons = 4
        /// The verdict stamps in: from big and tilted down to its place.
        static let stampScale: CGFloat = 1.5
        static let stampTilt: Double = -8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if showsPimpi && !typeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    title.frame(maxWidth: .infinity, alignment: .leading)
                    Pimpi(mood: result.verdict.pimpiMood).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                }
            } else {
                if showsPimpi {
                    Pimpi(mood: result.verdict.pimpiMood).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                }
                title
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(result.reasons.prefix(Metrics.maxReasons).enumerated()), id: \.element.id) { index, reason in
                    Label {
                        Text(reason.text).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: icon(for: reason.kind)).foregroundStyle(tint(for: reason.kind))
                    }
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown || reduceMotion ? 0 : Metrics.reasonRise)
                    .animation(MotionToken.smooth.resolved(reduceMotion: reduceMotion).animation
                        .delay(reduceMotion ? 0 : MotionToken.stagger(index + 1)), value: shown)
                }
            }
            if result.verdict == .notEnoughInfo {
                Text("We couldn't recognise enough ingredients. Try scanning the full ingredient list.")
                    .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
            }
            Text("Based on your skin profile and recent scans. General information, not medical advice.")
                .font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) { shown = true }
        }
        .sensoryFeedback(Haptic.capture, trigger: shown)
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Label(result.verdict.title, systemImage: result.verdict.systemImage + ".fill")
            .font(.system(.title, design: .rounded).weight(.heavy))
            .foregroundStyle(result.verdict.tint)
            .fixedSize(horizontal: false, vertical: true)
            .symbolEffect(.bounce, value: shown)
            .scaleEffect(shown || reduceMotion ? 1 : Metrics.stampScale, anchor: .leading)
            .rotationEffect(.degrees(shown || reduceMotion ? 0 : Metrics.stampTilt), anchor: .leading)
            .opacity(shown ? 1 : 0)
            .accessibilityAddTraits(.isHeader)
    }

    private func icon(for kind: VerdictReason.Kind) -> String {
        switch kind {
        case .positive: "checkmark.circle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .negative: "xmark.circle.fill"
        }
    }

    private func tint(for kind: VerdictReason.Kind) -> Color {
        switch kind {
        case .positive: Color.ds.positive
        case .caution: Color.ds.caution
        case .negative: Color.ds.signal
        }
    }
}

/// Verdict (and, when there's enough data, "did it help?") for a catalog product.
struct ProductCheckSummary: View {
    let product: CatalogProduct
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]

    var body: some View {
        let profile = VerdictProfileBuilder.make(latest: scans.first)
        VStack(alignment: .leading, spacing: Spacing.md) {
            VerdictCard(result: ProductVerdictEngine.evaluate(
                ingredients: product.ingredientList.map { $0.lowercased() }, profile: profile))
            if let effect {
                Label(effect.summary, systemImage: "chart.line.downtrend.xyaxis")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard()
            }
        }
    }

    private var effect: ProductEffect? {
        guard let entry = RoutineHistory.all()[product.productID] else { return nil }
        return ProductEffect.evaluate(points: scans.map(InsightEngine.Point.init), startedAt: entry.startedAt)
    }
}

/// Point the camera at an ingredient label (live text) → personal verdict. Fully on device (VisionKit).
/// The camera window sits on the sky with Pimpi watching beside it; the verdict lands on the hill.
struct LabelScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @State private var recognizedText = ""
    @State private var result: VerdictResult?
    @State private var pastedText = ""
    /// One label scan counts as one product check, however long the camera keeps reading it.
    @State private var checkKey = "label-\(UUID().uuidString)"
    @State private var checkAllowed: Bool?

    private enum Metrics {
        /// Width over height of the camera window.
        static let windowAspect: CGFloat = 4 / 3
        static let windowMaxHeight: CGFloat = 340
        static let pasteMinHeight: CGFloat = 120
    }

    private var isLiveAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    /// Pimpi reacts to the verdict once it is showing; until then it is curious.
    private var mood: MascotMood {
        guard checkAllowed == true, let result else { return .curious }
        return result.verdict.pimpiMood
    }

    var body: some View {
        NavigationStack {
            ShelfPlacePage {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if isLiveAvailable {
                        ShelfCameraWindow(sweep: result == nil ? .vertical : nil) { LiveTextScanner(text: $recognizedText) }
                            .aspectRatio(Metrics.windowAspect, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: Metrics.windowMaxHeight)
                    } else {
                        Text("Live label scanning isn't available here. Paste the ingredient list instead.")
                            .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                        TextEditor(text: $pastedText)
                            .font(.ds.body)
                            .foregroundStyle(Color.ds.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: Metrics.pasteMinHeight)
                            .padding(Spacing.sm)
                            .dsSurface(radius: Radius.medium)
                            .onChange(of: pastedText) { _, text in recognizedText = text }
                    }
                    ShelfCrestRow(mood: mood) {
                        if result == nil {
                            Text("Hold the ingredient list steady inside the frame.")
                                .font(.system(.footnote, design: .rounded).weight(.heavy))
                                .foregroundStyle(Color.ds.ink)
                        }
                    }
                }
            } ground: {
                if let result {
                    ProductCheckGate(key: checkKey, allowed: $checkAllowed) { VerdictCard(result: result, showsPimpi: false) }
                } else {
                    Text("Show me the back of the bottle.")
                        .font(.ds.pimpi)
                        .foregroundStyle(Color.ds.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ShelfSheetHeader(title: Text("Check a label")) { dismiss() }
                    .background(Color.ds.canvas.ignoresSafeArea())
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .onChange(of: recognizedText) { _, text in
                let ingredients = IngredientParser.parse(text)
                guard ingredients.count >= 3 else { return }
                result = ProductVerdictEngine.evaluate(ingredients: ingredients, profile: VerdictProfileBuilder.make(latest: scans.first))
            }
            .sensoryFeedback(Haptic.success, trigger: result?.verdict)
        }
    }
}

private struct LiveTextScanner: UIViewControllerRepresentable {
    @Binding var text: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        do {
            try scanner.startScanning()
        } catch {
            context.coordinator.text = ""
        }
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            text = allItems.compactMap { item in
                if case let .text(recognized) = item { return recognized.transcript }
                return nil
            }.joined(separator: ", ")
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            self.dataScanner(dataScanner, didUpdate: addedItems, allItems: allItems)
        }
    }
}
