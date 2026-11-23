import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Vision
import SkinalyzeKit

/// Share-sheet Product Check: Safari pages (read in-page via JS preprocessing — no extra network fetch), shared text,
/// or a photo/screenshot of a label (on-device OCR). Shows the verdict right in the sheet. No ML model or 3D here,
/// keeping the extension well under its memory budget.
final class ShareViewController: UIViewController {
    private let model = ShareCheckModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareCheckView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.load(from: items) }
    }
}

@Observable
@MainActor
final class ShareCheckModel {
    enum Phase: Equatable {
        case loading
        case needsProfile
        case result(title: String?, VerdictResult)
        /// This month's free product checks are used (the same allowance as in the app).
        case limitReached
    }

    var phase: Phase = .loading

    func load(from items: [NSExtensionItem]) async {
        guard let context = SharedContext.load() else {
            phase = .needsProfile
            return
        }
        let (pageTitle, text, url) = await extract(from: items)
        // Shopping apps (TikTok Shop, Shopee, Tokopedia) share a link and/or the product name as text.
        let shop = ProductCatalog.shared.shopMatch(url: url, text: pageTitle == nil ? text : nil)
        let title = pageTitle ?? shop?.product.map { "\($0.brand) \($0.name)" } ?? shop?.title
        let matched = shop?.product ?? title.flatMap(ProductCatalog.shared.bestMatch(forTitle:))
        let catalogIngredients = matched?.ingredients ?? ""
        let combined = [text, catalogIngredients].filter { !$0.isEmpty }.joined(separator: ", ")
        // A product is identified by its page title, or else by what was read from it.
        let key = "share-" + (title ?? combined).lowercased().trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
        let policy = AccessPolicy(hasFullAccess: await SharedAccess.hasFullAccess())
        let ledger = ProductCheckLedger()
        guard ledger.canCheck(key, policy: policy) else {
            phase = .limitReached
            return
        }
        ledger.record(key)
        phase = .result(title: title, context.verdict(forIngredientText: combined))
    }

    private func extract(from items: [NSExtensionItem]) async -> (title: String?, text: String, url: URL?) {
        var title: String?
        var texts: [String] = []
        var sharedURL: URL?
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier),
               let dict = try? await provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier) as? [String: Any],
               let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
                title = results["title"] as? String
                texts.append(results["ingredients"] as? String ?? "")
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                      let image = await loadImage(provider) {
                texts.append(Self.recognizeText(in: image))
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                      let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                texts.append(text)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                      let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                sharedURL = url
                if ShopLinkParser.shop(of: url) == .other {
                    title = title ?? url.lastPathComponent.replacingOccurrences(of: "-", with: " ")
                }
            }
        }
        return (title, texts.joined(separator: ", "), sharedURL)
    }

    private func loadImage(_ provider: NSItemProvider) async -> CGImage? {
        let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
        if let url = item as? URL, let data = try? Data(contentsOf: url) { return UIImage(data: data)?.cgImage }
        if let data = item as? Data { return UIImage(data: data)?.cgImage }
        return (item as? UIImage)?.cgImage
    }

    nonisolated static func recognizeText(in image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "id-ID"]
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return ""
        }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }
}

struct ShareCheckView: View {
    let model: ShareCheckModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    switch model.phase {
                    case .loading:
                        ProgressView("Reading ingredients…").frame(maxWidth: .infinity, minHeight: 200)
                    case .needsProfile:
                        Text("Open Skinalyze once to set up your skin profile, then share again.")
                            .font(.ds.body)
                    case .limitReached:
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label("Product check", systemImage: "lock.fill").font(.ds.headline)
                            Text("You've used this month's \(FreeLimits.productChecksPerMonth) free product checks. Products you already checked stay open.")
                                .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
                            Text("Open Skinalyze to see Skinalyze Pro.").font(.ds.callout)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dsCard()
                    case let .result(title, result):
                        if let title { Text(title).font(.ds.titleSmall).lineLimit(2) }
                        ShareVerdict(result: result)
                    }
                }
                .padding(Spacing.md)
            }
            .dsCanvas()
            .navigationTitle("Is it good for me?")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done", action: done) }
        }
        .tint(Color.ds.signal)
    }
}

private struct ShareVerdict: View {
    let result: VerdictResult

    private var tint: Color {
        switch result.verdict {
        case .goodMatch: .ds.positive
        case .notEnoughInfo: .ds.inkSecondary
        default: .ds.caution
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(result.verdict.title, systemImage: result.verdict.systemImage)
                .font(.ds.title)
                .foregroundStyle(tint)
            ForEach(result.reasons) { reason in
                Text(reason.text).font(.ds.callout)
            }
            if result.verdict == .notEnoughInfo {
                Text("Share a photo of the ingredient list for a better read.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            Text("General information based on your profile, not medical advice.")
                .font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}
