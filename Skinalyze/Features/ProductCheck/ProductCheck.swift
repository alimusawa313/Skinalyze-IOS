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

/// "Is this good for me?" — deterministic verdict with reasons (never an LLM decision).
struct VerdictCard: View {
    let result: VerdictResult
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var tint: Color {
        switch result.verdict {
        case .goodMatch: .ds.positive
        case .useWithCaution: .ds.caution
        case .probablyNotForYou: .ds.signal
        case .notEnoughInfo: .ds.inkSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(result.verdict.title, systemImage: result.verdict.systemImage)
                .font(.ds.title)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: shown)
            ForEach(Array(result.reasons.prefix(4).enumerated()), id: \.element.id) { index, reason in
                Label(reason.text, systemImage: icon(for: reason.kind))
                    .font(.ds.callout)
                    .foregroundStyle(Color.ds.ink)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown || reduceMotion ? 0 : 8)
                    .animation(MotionToken.smooth.resolved(reduceMotion: reduceMotion).animation
                        .delay(reduceMotion ? 0 : MotionToken.stagger(index + 1)), value: shown)
            }
            if result.verdict == .notEnoughInfo {
                Text("We couldn't recognise enough ingredients. Try scanning the full ingredient list.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            Text("Based on your skin profile and recent scans. General information, not medical advice.")
                .font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .onAppear { shown = true }
        .accessibilityElement(children: .combine)
    }

    private func icon(for kind: VerdictReason.Kind) -> String {
        switch kind {
        case .positive: "checkmark.circle"
        case .caution: "exclamationmark.circle"
        case .negative: "xmark.circle"
        }
    }
}

/// Verdict (and, when there's enough data, "did it help?") for a catalog product.
struct ProductCheckSummary: View {
    let product: CatalogProduct
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]

    var body: some View {
        let profile = VerdictProfileBuilder.make(latest: scans.first)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VerdictCard(result: ProductVerdictEngine.evaluate(
                ingredients: product.ingredientList.map { $0.lowercased() }, profile: profile))
            if let effect {
                Label(effect.summary, systemImage: "chart.line.downtrend.xyaxis")
                    .font(.ds.callout)
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
struct LabelScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @State private var recognizedText = ""
    @State private var result: VerdictResult?
    @State private var pastedText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    LiveTextScanner(text: $recognizedText)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        .frame(maxHeight: 320)
                } else {
                    Text("Live label scanning isn't available here. Paste the ingredient list instead.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                    TextEditor(text: $pastedText)
                        .frame(minHeight: 120)
                        .padding(Spacing.xs)
                        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.small))
                        .onChange(of: pastedText) { _, text in recognizedText = text }
                }
                if let result {
                    ScrollView { VerdictCard(result: result) }
                } else {
                    Text("Hold the ingredient list steady inside the frame.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .dsCanvas()
            .navigationTitle("Check a label")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
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
