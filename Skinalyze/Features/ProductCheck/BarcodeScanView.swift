import SwiftData
import SwiftUI
import SkinalyzeKit
import VisionKit

// P8 barcode scan. The catalog has no barcodes, so a barcode is linked to a product once (remembered on this phone),
// or — only when the user taps for it — looked up in Open Beauty Facts, a free public product database. Only the
// barcode number is sent; nothing about the user.

enum BarcodeLinks {
    private static let key = "barcodeLinks"

    static func product(for code: String) -> CatalogProduct? {
        (UserDefaults.standard.dictionary(forKey: key)?[code] as? Int).flatMap { ProductCatalog.shared.product(id: $0) }
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if code == nil { scanner }
                    if let code { result(for: code) }
                }
                .padding(Spacing.md)
            }
            .dsCanvas()
            .navigationTitle("Scan a barcode")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $linked) { ProductDetailView(product: $0) }
            .sheet(isPresented: $linking) {
                if let code { LinkBarcodeView(code: code) { product in linked = product } }
            }
        }
    }

    @ViewBuilder private var scanner: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            BarcodeCamera { found in accept(found) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                .frame(height: 280)
            Text("Point the camera at the barcode on the pack.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        }
        HStack {
            TextField("Or type the numbers", text: $typed)
                .keyboardType(.numberPad)
                .padding(Spacing.sm)
                .frame(minHeight: 44)
                .background(Color.ds.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityIdentifier("barcodeField")
            Button("Check") { accept(typed) }
                .buttonStyle(.borderedProminent).tint(Color.ds.signal)
                .disabled(Barcode.normalized(typed) == nil)
                .accessibilityIdentifier("barcodeCheck")
        }
    }

    private func accept(_ raw: String) {
        guard let normalized = Barcode.normalized(raw) else { return }
        code = normalized
        lookup = .idle
        if let product = BarcodeLinks.product(for: normalized) { linked = product }
    }

    @ViewBuilder private func result(for code: String) -> some View {
        Label(code, systemImage: "barcode").font(.ds.headline.monospacedDigit())
        if let product = BarcodeLinks.product(for: code) {
            Button("Open \(product.name)") { linked = product }.buttonStyle(.borderedProminent).tint(Color.ds.signal)
        } else {
            Text("Skinalyze doesn't know this barcode yet.").font(.ds.callout)
            Button("Link it to a product") { linking = true }
                .buttonStyle(.bordered).frame(minHeight: 44)
                .accessibilityIdentifier("linkBarcode")
            onlineLookup(code)
        }
        Button("Scan another") { self.code = nil; typed = "" }.frame(minHeight: 44)
    }

    @ViewBuilder private func onlineLookup(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            switch lookup {
            case .idle:
                Button("Look it up online") { Task { await fetch(code) } }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                    .accessibilityIdentifier("lookupOnline")
                Text("Sends only this barcode number to Open Beauty Facts, a free public product database.")
                    .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
            case .loading:
                ProgressView()
            case .notFound:
                Text("Open Beauty Facts doesn't have it either. Try a label scan for the ingredients.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            case .failed:
                Text("Couldn't reach Open Beauty Facts. Check your connection and try again.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            case let .found(product):
                found(product)
            }
        }
        .dsCard()
    }

    @ViewBuilder private func found(_ product: OnlineProduct) -> some View {
        Text([product.brand, product.name].compactMap { $0 }.joined(separator: " · ")).font(.ds.headline)
        if let match = ProductCatalog.shared.bestMatch(forTitle: "\(product.brand ?? "") \(product.name)") {
            Button("Open \(match.name) in Skinalyze") {
                BarcodeLinks.link(product.barcode, to: match.productID)
                linked = match
            }
            .buttonStyle(.borderedProminent).tint(Color.ds.signal)
        } else if let text = product.ingredients, IngredientParser.parse(text).count >= 3 {
            ProductCheckGate(key: "barcode-\(product.barcode)", allowed: $checkAllowed) {
                VerdictCard(result: ProductVerdictEngine.evaluate(ingredients: IngredientParser.parse(text),
                                                                  profile: VerdictProfileBuilder.make(latest: scans.first)))
            }
        } else {
            Text("No ingredient list there. Try a label scan.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        }
        Text("Product data from Open Beauty Facts (openbeautyfacts.org), shared under the Open Database License.")
            .font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
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
                    VStack(alignment: .leading) {
                        Text(product.name).font(.ds.callout)
                        Text(product.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                    }
                }
            }
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
