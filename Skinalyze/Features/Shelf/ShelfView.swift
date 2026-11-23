import SwiftUI
import SkinalyzeKit

/// Your products as a shelf: four big bouncy tiles (one per routine step) and one question — "is it good for me?".
struct ShelfView: View {
    @Environment(AppModel.self) private var appModel
    @State private var query = ""
    @FocusState private var isSearching: Bool
    @State private var showsLabelScanner = false
    @State private var editingSlot: ProductCatalog.Slot?
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 54

    private var results: [CatalogProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? [] : Array(ProductCatalog.shared.search(trimmed).prefix(40))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Shelf")
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    searchBar
                    if query.isEmpty {
                        RecapBanner()
                        ShelfToolsCard()
                        JourneyCard()
                        SkinSchoolCard()
                        tiles
                        ShareShelfButton()
                        RoutineChecklist()
                        JournalCard()
                    } else {
                        resultList
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .safeAreaPadding(.bottom, 88)
            .background(ShelfBackdrop())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogProduct.self) { ProductDetailView(product: $0) }
            .sheet(item: $editingSlot) { ProductPicker(slot: $0) }
            .sheet(isPresented: $showsLabelScanner) { LabelScannerView() }
        }
        .onAppear { if appModel.selectedTab == .search { isSearching = true } }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkle.magnifyingglass").font(.headline).accessibilityHidden(true)
                TextField("Is it good for me?", text: $query)
                    .focused($isSearching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("shelfSearch")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 56)
            .glassEffect(.regular.interactive(), in: Capsule())
            Button { showsLabelScanner = true } label: {
                Image(systemName: "text.viewfinder").font(.title3.weight(.semibold)).frame(width: 56, height: 56)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .buttonStyle(.bouncy)
            .accessibilityLabel("Scan a label")
        }
        .dsAnimation(.bouncy, value: query.isEmpty)
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            ForEach(Array(ProductCatalog.Slot.allCases.enumerated()), id: \.element) { index, slot in
                ShelfTile(slot: slot, hue: Self.hue(index)) { editingSlot = slot }
                    .popIn(delay: MotionToken.stagger(index) * 2)
            }
        }
    }

    private var resultList: some View {
        LazyVStack(spacing: Spacing.sm) {
            if results.isEmpty {
                Text("Nothing on the shelf matches “\(query)”. Try a label scan.")
                    .font(.ds.body).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(results.enumerated()), id: \.element.productID) { index, product in
                NavigationLink(value: product) {
                    HStack(spacing: Spacing.md) {
                        ProductThumbnail(product: product)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).font(.ds.headline).lineLimit(2)
                            Text(product.brand).font(.ds.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(Spacing.sm)
                    .background(Color.ds.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                }
                .buttonStyle(.bouncy(0.96))
                .accessibilityIdentifier("shelfResult")
                .popIn(delay: MotionToken.stagger(index))
            }
        }
    }

    static func hue(_ index: Int) -> Color {
        let bands: [BreakoutBand] = [.calm, .mild, .active, .flared]
        return Color.ds.band(bands[index % bands.count])
    }
}

/// One routine step as a chunky coloured tile: the product photo floats on it; empty tiles invite you to add one.
private struct ShelfTile: View {
    let slot: ProductCatalog.Slot
    let hue: Color
    let edit: () -> Void
    @AppStorage private var productID: Int

    init(slot: ProductCatalog.Slot, hue: Color, edit: @escaping () -> Void) {
        self.slot = slot
        self.hue = hue
        self.edit = edit
        _productID = AppStorage(wrappedValue: 0, slot.storageKey)
    }

    private var product: CatalogProduct? { ProductCatalog.shared.product(id: productID) }

    var body: some View {
        Group {
            if let product {
                NavigationLink(value: product) { face(product) }
                    .contextMenu {
                        Button("Swap product", systemImage: "arrow.triangle.2.circlepath", action: edit)
                        Button("Take off the shelf", systemImage: "minus.circle", role: .destructive) {
                            RoutineHistory.stopped(productID)
                            productID = 0
                        }
                    }
            } else {
                Button(action: edit) { face(nil) }
                    .accessibilityHint("Pick your \(slot.title.lowercased())")
            }
        }
        .buttonStyle(.bouncy)
        .sensoryFeedback(Haptic.toggle, trigger: productID)
    }

    private func face(_ product: CatalogProduct?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ZStack {
                if let product {
                    AsyncImage(url: product.photoURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: slot.systemImage).font(.system(size: 44, weight: .semibold))
                    }
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
                } else {
                    Image(systemName: "plus").font(.system(size: 40, weight: .heavy))
                        .symbolEffect(.bounce, options: .repeat(.periodic(delay: 3)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
            .foregroundStyle(.black.opacity(0.7))
            .accessibilityHidden(true)
            Text(slot.title).font(.system(.title3, design: .rounded).weight(.heavy))
            Text(product?.name ?? String(localized: "Add yours"))
                .font(.ds.footnote.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .opacity(0.75)
        }
        .foregroundStyle(.black)
        .padding(Spacing.md)
        .background(hue.gradient, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shelfTile.\(slot.rawValue)")
    }
}

private struct ShelfBackdrop: View {
    var body: some View {
        ZStack {
            Color.ds.canvas
            RadialGradient(colors: [Color.ds.band(.mild).opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color.ds.band(.calm).opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}
