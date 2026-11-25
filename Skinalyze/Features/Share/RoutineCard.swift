import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import SkinalyzeKit

// G7 routine cards: "my shelf" as a picture with a QR code; whoever opens the link (or scans the code) sees those
// products checked against *their* skin. Product names only — no photo of anyone.

struct RoutineShare {
    struct Item: Hashable {
        let slot: String
        let brand: String
        let name: String
    }

    let items: [Item]
    let link: URL
    let qr: UIImage?
}

enum RoutineLink {
    static func url(for productIDs: [Int]) -> URL {
        var components = URLComponents()
        components.scheme = "skinalyze"
        components.host = "shelf"
        components.queryItems = [URLQueryItem(name: "p", value: productIDs.map(String.init).joined(separator: ","))]
        return components.url!
    }

    /// Product ids from a shared link; unknown or malformed ids are dropped, at most eight.
    static func productIDs(from url: URL) -> [Int] {
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "p" }?.value ?? ""
        return Array(raw.split(separator: ",").compactMap { Int($0) }.filter { ProductCatalog.shared.product(id: $0) != nil }.prefix(8))
    }

    static func qr(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}

extension ShareCardSource {
    @MainActor
    static func routine(productIDs: [Int]) -> ShareCardSource {
        let products = productIDs.compactMap { ProductCatalog.shared.product(id: $0) }
        let link = RoutineLink.url(for: products.map(\.productID))
        let share = RoutineShare(items: products.map { .init(slot: $0.slot?.title ?? "", brand: $0.brand, name: $0.name) },
                                 link: link, qr: RoutineLink.qr(for: link))
        return ShareCardSource(fileName: "skinalyze-shelf", offersHideFace: false) { _ in .routine(share) }
    }
}

struct RoutineShareCard: View {
    let share: RoutineShare
    let format: ShareCardFormat

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("My shelf").font(CardMetrics.title)
            ForEach(share.items, id: \.self) { item in
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.slot.uppercased()).font(CardMetrics.label).foregroundStyle(Color.ds.signal)
                    Text(item.name).font(format == .square ? CardMetrics.body : CardMetrics.heading).lineLimit(2)
                    Text(item.brand).font(CardMetrics.note).opacity(CardMetrics.softText)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: Spacing.sm) {
                if let qr = share.qr {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 72, height: 72)
                        .padding(4).background(.white, in: RoundedRectangle(cornerRadius: 6))
                }
                Text("Scan to check these for your skin in Skinalyze").font(CardMetrics.note).opacity(CardMetrics.softText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The "Share my shelf" button under the tiles.
struct ShareShelfButton: View {
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0

    var body: some View {
        let ids = [cleanser, toner, moisturizer, sunscreen].filter { $0 > 0 }
        if !ids.isEmpty {
            ShareCardButton { .routine(productIDs: ids) }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("shareShelf")
        }
    }
}

/// Opened from someone's shelf link: their products, each one tap away from a check for your skin.
struct SharedShelfView: View {
    let productIDs: [Int]
    @Environment(\.dismiss) private var dismiss

    private enum Metrics {
        static let pimpi: CGFloat = 96
        /// Where the hill starts, as a share of the screen height.
        static let crest: CGFloat = 0.3
    }

    private var products: [CatalogProduct] {
        productIDs.compactMap { ProductCatalog.shared.product(id: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm) {
                        PokablePimpi(mood: .curious, size: Metrics.pimpi)
                        SpeechBubble(Text("Tap a product to see if it suits your skin."), tail: .leading)
                    }
                    VStack(spacing: Spacing.sm) {
                        ForEach(Array(products.enumerated()), id: \.element.productID) { index, product in
                            NavigationLink(value: product) {
                                HStack(spacing: Spacing.sm) {
                                    ProductThumbnail(product: product)
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(product.name)
                                            .font(.system(.callout, design: .rounded).weight(.heavy))
                                            .foregroundStyle(Color.ds.ink)
                                            .lineLimit(2)
                                        Text(product.brand).font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.footnote.weight(.heavy)).foregroundStyle(Color.ds.ink)
                                }
                                .padding(Spacing.md)
                                .dsSurface(radius: Radius.medium)
                            }
                            .buttonStyle(.bouncy(0.97))
                            .popIn(delay: MotionToken.stagger(index))
                        }
                    }
                    .onHill()
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .dsHill(crest: Metrics.crest)
            .navigationTitle("A friend's shelf")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: CatalogProduct.self) { ProductDetailView(product: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SharedShelf: Identifiable {
    let id = UUID()
    let productIDs: [Int]
}
