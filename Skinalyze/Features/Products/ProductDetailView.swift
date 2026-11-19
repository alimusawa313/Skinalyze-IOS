import SwiftUI
import SkinalyzeKit

/// Product pieces shared by the Shelf: thumbnail, slot picker and the detail page with the verdict.
struct ProductThumbnail: View {
    let product: CatalogProduct

    var body: some View {
        AsyncImage(url: product.photoURL) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: product.slot?.systemImage ?? "drop")
                .foregroundStyle(Color.ds.inkTertiary)
        }
        .frame(width: 56, height: 56)
        .background(Color.ds.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.small))
        .accessibilityHidden(true)
    }
}

struct ProductPicker: View {
    let slot: ProductCatalog.Slot
    @Environment(\.dismiss) private var dismiss
    @AppStorage private var productID: Int
    @State private var query = ""

    init(slot: ProductCatalog.Slot) {
        self.slot = slot
        _productID = AppStorage(wrappedValue: 0, slot.storageKey)
    }

    var body: some View {
        NavigationStack {
            List(ProductCatalog.shared.search(query, in: slot)) { product in
                Button {
                    if productID > 0 { RoutineHistory.stopped(productID) }
                    productID = product.productID
                    RoutineHistory.started(product.productID)
                    dismiss()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        ProductThumbnail(product: product)
                        VStack(alignment: .leading) {
                            Text(product.name).font(.ds.callout).foregroundStyle(Color.ds.ink)
                            Text(product.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                        }
                        Spacer()
                        if product.productID == productID {
                            Image(systemName: "checkmark").foregroundStyle(Color.ds.signal)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Name, brand or ingredient")
            .navigationTitle(slot.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}

/// Product details with ingredients highlighted for *your* skin type.
struct ProductDetailView: View {
    let product: CatalogProduct
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""

    var body: some View {
        let guidance = SkinTypeGuidance.for(SkinType(stored: skinTypeRaw))
        let helpful = guidance.lookFor.map { $0.name.lowercased() }
        let caution = guidance.avoid.map { $0.name.lowercased() }
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    ProductThumbnail(product: product)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(product.brand).font(.ds.label).foregroundStyle(Color.ds.inkSecondary)
                        Text(product.name).font(.ds.title)
                        if let slot = product.slot {
                            Text(slot.title).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                }
                ProductCheckSummary(product: product)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SectionTitle("Ingredients")
                    if product.ingredientList.isEmpty {
                        Text("No ingredient list for this product yet.").font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
                    }
                    ForEach(Array(product.ingredientList.enumerated()), id: \.offset) { _, ingredient in
                        let name = ingredient.lowercased()
                        let isHelpful = helpful.contains { name.contains($0) }
                        let isCaution = caution.contains { name.contains($0) }
                        HStack {
                            Text(ingredient).font(.ds.callout)
                            Spacer()
                            if isHelpful {
                                Image(systemName: "checkmark.circle").foregroundStyle(Color.ds.positive)
                                    .accessibilityLabel("Good for your skin type")
                            } else if isCaution {
                                Image(systemName: "exclamationmark.circle").foregroundStyle(Color.ds.caution)
                                    .accessibilityLabel("Go easy for your skin type")
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .dsCard()
                if let link = product.link.flatMap(URL.init(string:)) {
                    Link("View source page", destination: link).font(.subheadline.weight(.semibold))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .dsCanvas()
        .navigationTitle(product.name)
        .toolbarTitleDisplayMode(.inline)
    }
}
