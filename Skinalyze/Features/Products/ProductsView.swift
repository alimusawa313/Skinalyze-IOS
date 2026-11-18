import SwiftUI
import SkinalyzeKit

/// Routine slots (cleanser · toner · moisturizer · sunscreen). Products used at scan time feed Compare and insights.
struct ProductsView: View {
    @State private var editingSlot: ProductCatalog.Slot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    RoutineChecklist()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Spacing.md)], spacing: Spacing.md) {
                        ForEach(ProductCatalog.Slot.allCases) { slot in
                            SlotCard(slot: slot) { editingSlot = slot }
                        }
                    }
                    Text("Products you add here are remembered with every scan, so you can see what changed when.")
                        .font(.ds.footnote)
                        .foregroundStyle(Color.ds.inkSecondary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .navigationTitle("Routine")
            .navigationDestination(for: CatalogProduct.self) { ProductDetailView(product: $0) }
            .sheet(item: $editingSlot) { slot in
                ProductPicker(slot: slot)
            }
        }
    }
}

private struct SlotCard: View {
    let slot: ProductCatalog.Slot
    let edit: () -> Void
    @AppStorage private var productID: Int

    init(slot: ProductCatalog.Slot, edit: @escaping () -> Void) {
        self.slot = slot
        self.edit = edit
        _productID = AppStorage(wrappedValue: 0, slot.storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(slot.title, systemImage: slot.systemImage).font(.ds.label).foregroundStyle(Color.ds.inkSecondary)
            if let product = ProductCatalog.shared.product(id: productID) {
                NavigationLink(value: product) {
                    HStack(spacing: Spacing.sm) {
                        ProductThumbnail(product: product)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).font(.ds.headline).foregroundStyle(Color.ds.ink).lineLimit(2)
                            Text(product.brand).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                HStack {
                    Button("Change", action: edit)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        RoutineHistory.stopped(productID)
                        productID = 0
                    }
                }
                .font(.subheadline.weight(.semibold))
            } else {
                Button(action: edit) {
                    Label("Add your \(slot.title.lowercased())", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.dsSecondary)
            }
        }
        .dsCard()
        .sensoryFeedback(Haptic.toggle, trigger: productID)
    }
}

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

private struct ProductPicker: View {
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
