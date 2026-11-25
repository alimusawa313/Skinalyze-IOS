import SwiftData
import SwiftUI
import SkinalyzeKit
import VisionKit

// P8 barcode scan. Catalog products imported from Open Beauty Facts carry their barcode; any other barcode is linked
// to a product once (remembered on this phone),
// or — only when the user taps for it — looked up in Open Beauty Facts, a free public product database. Only the
// barcode number is sent; nothing about the user.

enum BarcodeLinks {
    private static let key = "barcodeLinks"

    /// A product this phone linked the barcode to, else the catalog product carrying that barcode.
    static func product(for code: String) -> CatalogProduct? {
        (UserDefaults.standard.dictionary(forKey: key)?[code] as? Int).flatMap { ProductCatalog.shared.product(id: $0) }
            ?? ProductCatalog.shared.product(barcode: code)
    }

    static func link(_ code: String, to productID: Int) {
        var links = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        links[code] = productID
        UserDefaults.standard.set(links, forKey: key)
    }
}

struct BarcodeScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse)
    private var scans: [ScanSession]
    @State private var code: String?
    @State private var typed = ""
    @State private var linked: CatalogProduct?
    @State private var linking = false
    @State private var lookup: Lookup = .idle
    @State private var checkAllowed: Bool?

    enum Lookup: Equatable {
        case idle, loading, notFound, failed
        case found(OnlineProduct)
    }

    private enum Metrics {
        /// Width over height of the camera window.
        static let windowAspect: CGFloat = 3 / 2
        static let windowMaxHeight: CGFloat = 300
    }

    private var isCameraAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    /// Curious while reading, worried about a barcode it doesn't know, happy once it knows the product.
    private var mood: MascotMood {
        guard let code else { return .curious }
        return BarcodeLinks.product(for: code) == nil ? .worried : .happy
    }

    var body: some View {
        NavigationStack {
            ShelfPlacePage {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let code {
                        Label(code, systemImage: "barcode")
                            .font(.system(.headline, design: .rounded).weight(.heavy).monospacedDigit())
                            .foregroundStyle(Color.ds.ink)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: Chunk.iconButton)
                            .dsSurface(radius: Chunk.iconButton / 2)
                    } else if isCameraAvailable {
                        ShelfCameraWindow(sweep: .horizontal) { BarcodeCamera { found in accept(found) } }
                            .aspectRatio(Metrics.windowAspect, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: Metrics.windowMaxHeight)
                    }
                    ShelfCrestRow(mood: mood) { crestText }
                }
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let code { result(for: code) } else { typeIn }
                }
                .id(code) // a new result pops in fresh
                .popIn()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ShelfSheetHeader(title: Text("Scan a barcode")) { dismiss() }
                    .background(Color.ds.canvas.ignoresSafeArea())
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sensoryFeedback(Haptic.capture, trigger: code) { _, new in new != nil }
            .navigationDestination(item: $linked) { ProductDetailView(product: $0) }
            .sheet(isPresented: $linking) {
                if let code { LinkBarcodeView(code: code) { product in linked = product } }
            }
        }
    }

    /// What sits beside Pimpi: the camera hint while reading, or that the barcode is new.
    @ViewBuilder private var crestText: some View {
        if let code {
            if BarcodeLinks.product(for: code) == nil {
                Text("Skinalyze doesn't know this barcode yet.")
                    .font(.ds.titleSmall)
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        } else if isCameraAvailable {
            Text("Point the camera at the barcode on the pack.")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
        }
    }

    /// The numbers typed by hand, and Pimpi's nudge while the camera reads.
    @ViewBuilder private var typeIn: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            TextField("Or type the numbers", text: $typed)
                .keyboardType(.numberPad)
                .font(.system(.body, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Color.ds.ink)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Chunk.controlHeight)
                .dsSurface(radius: Chunk.controlHeight / 2)
                .accessibilityIdentifier("barcodeField")
            Button("Check") { accept(typed) }
                .buttonStyle(.chunky(.filled, fullWidth: false, minHeight: Chunk.controlHeight))
                .disabled(Barcode.normalized(typed) == nil)
                .accessibilityIdentifier("barcodeCheck")
        }
        if isCameraAvailable {
            Text("Stripy side up, please.")
                .font(.ds.pimpi)
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func accept(_ raw: String) {
        guard let normalized = Barcode.normalized(raw) else { return }
        code = normalized
        lookup = .idle
        if let product = BarcodeLinks.product(for: normalized) { linked = product }
    }

    @ViewBuilder private func result(for code: String) -> some View {
        if let product = BarcodeLinks.product(for: code) {
            Button("Open \(product.name)") { linked = product }.buttonStyle(.chunky)
        } else {
            Button("Link it to a product") { linking = true }
                .buttonStyle(.chunky)
                .accessibilityIdentifier("linkBarcode")
            onlineLookup(code)
        }
        Button("Scan another") { self.code = nil; typed = "" }.buttonStyle(.chunkyPlain)
    }

    @ViewBuilder private func onlineLookup(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            switch lookup {
            case .idle:
                Button("Look it up online") { Task { await fetch(code) } }
                    .buttonStyle(.chunkyPlain)
                    .accessibilityIdentifier("lookupOnline")
                Text("Sends only this barcode number to Open Beauty Facts, a free public product database.")
                    .font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    .padding(.horizontal, Spacing.md)
            case .loading:
                ProgressView().tint(Color.ds.ink).frame(maxWidth: .infinity, minHeight: Chunk.controlHeight)
            case .notFound:
                note(Text("Open Beauty Facts doesn't have it either. Try a label scan for the ingredients."))
            case .failed:
                note(Text("Couldn't reach Open Beauty Facts. Check your connection and try again."))
            case let .found(product):
                found(product)
            }
        }
        .dsAnimation(.bouncy, value: lookup)
        .sensoryFeedback(Haptic.success, trigger: lookup) { _, new in if case .found = new { true } else { false } }
    }

    private func note(_ text: Text) -> some View {
        text.font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(Color.ds.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func found(_ product: OnlineProduct) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text([product.brand, product.name].compactMap { $0 }.joined(separator: " · "))
                .font(.ds.titleSmall).foregroundStyle(Color.ds.ink)
            if let match = ProductCatalog.shared.bestMatch(forTitle: "\(product.brand ?? "") \(product.name)") {
                Button("Open \(match.name) in Skinalyze") {
                    BarcodeLinks.link(product.barcode, to: match.productID)
                    linked = match
                }
                .buttonStyle(.chunky)
            } else if let text = product.ingredients, IngredientParser.parse(text).count >= 3 {
                ProductCheckGate(key: "barcode-\(product.barcode)", allowed: $checkAllowed) {
                    VerdictCard(result: ProductVerdictEngine.evaluate(ingredients: IngredientParser.parse(text),
                                                                      profile: VerdictProfileBuilder.make(latest: scans.first)))
                }
            } else {
                note(Text("No ingredient list there. Try a label scan."))
            }
            Text("Product data from Open Beauty Facts (openbeautyfacts.org), shared under the Open Database License.")
                .font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
        }
        .padding(.top, Spacing.sm)
    }

    private func fetch(_ code: String) async {
        guard let url = OpenBeautyFacts.url(for: code) else { return }
        lookup = .loading
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Skinalyze-iOS (product lookup)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                lookup = (response as? HTTPURLResponse)?.statusCode == 404 ? .notFound : .failed
                return
            }
            lookup = OpenBeautyFacts.parse(data, barcode: code).map(Lookup.found) ?? .notFound
        } catch {
            lookup = .failed
        }
    }
}

/// Pick the catalog product this barcode belongs to; remembered on this phone.
private struct LinkBarcodeView: View {
    let code: String
    let onLinked: (CatalogProduct) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(query.count >= 2 ? Array(ProductCatalog.shared.search(query).prefix(30)) : []) { product in
                Button {
                    BarcodeLinks.link(code, to: product.productID)
                    dismiss()
                    onLinked(product)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        ProductThumbnail(product: product)
                        VStack(alignment: .leading) {
                            Text(product.name)
                                .font(.system(.callout, design: .rounded).weight(.heavy))
                                .foregroundStyle(Color.ds.ink)
                            Text(product.brand).font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                }
                .listRowBackground(Color.ds.surface)
            }
            .scrollContentBackground(.hidden)
            .dsCanvas()
            .searchable(text: $query, prompt: Text("Product or brand"))
            .navigationTitle("Which product is it?")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

private struct BarcodeCamera: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
                                                qualityLevel: .balanced, recognizesMultipleItems: false,
                                                isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                    onCode(value)
                    return
                }
            }
        }
    }
}
