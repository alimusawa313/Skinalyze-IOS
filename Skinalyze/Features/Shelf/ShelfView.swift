import SwiftData
import SwiftUI
import SkinalyzeKit

/// Your products as a literal shelf: the four routine steps standing on a plank, one question — "is it good for
/// me?" — above it, and everything else about your routine on the hill below.
struct ShelfView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var query = ""
    @FocusState private var isSearching: Bool
    @State private var showsLabelScanner = false
    @State private var showsBarcode = false
    @State private var editingSlot: ProductCatalog.Slot?
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 46
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Morning or evening: dims the steps that part of the day skips, and drives today's checklist below.
    @State private var part = RoutineChecklist.partNow
    /// The product lifted off the plank; its verdict shows beside Pimpi.
    @State private var selected: ProductCatalog.Slot?
    @State private var verdictAllowed: Bool?
    @State private var pokes = 0

    private enum Metrics {
        static let pageWidth: CGFloat = 900
        static let maxResults = 40
        static let pimpi: CGFloat = 92
        /// How much of Pimpi shows above the hill's crest.
        static let pimpiStand: CGFloat = 64
        /// The drawing's feet sit above the bottom of its frame; this much lower puts them on the hill.
        static let pimpiFeet: CGFloat = 18
        static let slotsPerRowLargeType = 2
        static let bubbleReasons = 2
    }

    private var results: [CatalogProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? [] : Array(ProductCatalog.shared.search(trimmed).prefix(Metrics.maxResults))
    }

    private var isShelfEmpty: Bool { [cleanser, toner, moisturizer, sunscreen].allSatisfy { $0 == 0 } }

    /// Pimpi stands on the crest of the hill, except at accessibility sizes where its line needs the whole width.
    private var pimpiStandsOnCrest: Bool { query.isEmpty && !typeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ShelfPlacePage(maxWidth: Metrics.pageWidth) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Shelf")
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ds.ink)
                        .accessibilityAddTraits(.isHeader)
                    searchBar
                    if query.isEmpty {
                        PillPicker(RoutineChecklist.Part.allCases.map { (value: $0, title: $0.title) }, selection: $part)
                        shelf
                    }
                }
                .padding(.bottom, pimpiStandsOnCrest ? Metrics.pimpiStand - Spacing.lg : 0)
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if query.isEmpty {
                        pimpi
                        RecapBanner()
                        ShelfToolsCard()
                        UVCard()
                        JourneyCard()
                        SkinSchoolCard()
                        ShareShelfButton()
                        RoutineChecklist(part: $part)
                        JournalCard()
                    } else {
                        resultList
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .safeAreaPadding(.bottom, ShelfPlace.dockClearance)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: CatalogProduct.self) { ProductDetailView(product: $0) }
            .sheet(item: $editingSlot) { ProductPicker(slot: $0) }
            .sheet(isPresented: $showsLabelScanner) { LabelScannerView() }
            .sheet(isPresented: $showsBarcode) { BarcodeScanView() }
        }
        .onAppear { if appModel.selectedTab == .search { isSearching = true } }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass").font(.headline.weight(.heavy)).accessibilityHidden(true)
                TextField("Is it good for me?", text: $query)
                    .focused($isSearching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("shelfSearch")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(minWidth: Chunk.iconButton, minHeight: Chunk.iconButton)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.system(.body, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .padding(.leading, Spacing.md)
            .padding(.trailing, query.isEmpty ? Spacing.md : Spacing.xxs)
            .frame(minHeight: Chunk.controlHeight)
            .dsSurface(radius: Chunk.controlHeight / 2)
            scanButton("text.viewfinder") { showsLabelScanner = true }
                .accessibilityLabel("Scan a label")
            scanButton("barcode.viewfinder") { showsBarcode = true }
                .accessibilityLabel("Scan a barcode")
                .accessibilityIdentifier("scanBarcode")
        }
        .dsAnimation(.bouncy, value: query.isEmpty)
    }

    private func scanButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: Chunk.controlHeight, height: Chunk.controlHeight)
        }
        .buttonStyle(ChunkyIconButtonStyle(depth: Chunk.depth))
    }

    private var resultList: some View {
        LazyVStack(spacing: Spacing.sm) {
            if results.isEmpty {
                Text("Nothing on the shelf matches “\(query)”. Try a label scan.")
                    .font(.ds.body.weight(.semibold)).foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(results.enumerated()), id: \.element.productID) { index, product in
                NavigationLink(value: product) {
                    HStack(spacing: Spacing.md) {
                        ProductThumbnail(product: product)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(product.name)
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Text(product.brand)
                                .font(.ds.footnote.weight(.semibold))
                                .foregroundStyle(Color.ds.inkSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.heavy)).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.shelfRow)
                .accessibilityIdentifier("shelfResult")
                .popIn(delay: MotionToken.stagger(index))
            }
        }
    }

    // MARK: The shelf

    /// One plank with all four steps; two planks of two when the text is very large.
    private var shelf: some View {
        let slots = ProductCatalog.Slot.allCases
        let perRow = typeSize.isAccessibilitySize ? Metrics.slotsPerRowLargeType : slots.count
        let rows = stride(from: 0, to: slots.count, by: perRow).map { Array(slots[$0..<min($0 + perRow, slots.count)]) }
        return VStack(spacing: Spacing.lg) {
            ForEach(rows, id: \.self) { row in
                ShelfPlank(slots: row, selected: selected, resting: Set(ProductCatalog.Slot.allCases).subtracting(part.slots),
                           edit: { editingSlot = $0 }, select: select)
            }
        }
        .sensoryFeedback(Haptic.toggle, trigger: selected)
    }

    /// Lifts a product off the plank (or puts it back when it is already up).
    private func select(_ slot: ProductCatalog.Slot) {
        withDSAnimation(.bouncy, reduceMotion: reduceMotion) {
            verdictAllowed = nil
            pokes = 0
            selected = selected == slot ? nil : slot
        }
    }

    // MARK: Pimpi

    private var selectedProduct: CatalogProduct? {
        guard let selected else { return nil }
        let id = UserDefaults.standard.integer(forKey: selected.storageKey)
        return ProductCatalog.shared.product(id: id)
    }

    private func verdict(for product: CatalogProduct) -> VerdictResult {
        ProductVerdictEngine.evaluate(ingredients: product.ingredientList.map { $0.lowercased() },
                                      profile: VerdictProfileBuilder.make(latest: scans.first))
    }

    /// Pimpi pulls a face at a verdict once it is showing; poked, it plays; otherwise the shelf decides.
    private func mood(_ result: VerdictResult?) -> MascotMood {
        if let result, verdictAllowed == true { return result.verdict.pimpiMood }
        if pokes > 0 { return ShelfQuips.mood(pokes) }
        return isShelfEmpty ? .curious : .happy
    }

    private var line: Text {
        if pokes > 0 { return Text(ShelfQuips.line(pokes)) }
        return isShelfEmpty
            ? Text("Nothing here yet. Show me the label and I'll take a look.")
            : Text("A tidy shelf is half the routine.")
    }

    private func poke() {
        withDSAnimation(.bouncy, reduceMotion: reduceMotion) {
            selected = nil
            pokes += 1
        }
    }

    /// Pimpi's line, or the lifted product's verdict in a bubble beside it (facts in plain type, never Pimpi's voice).
    @ViewBuilder private func bubble(_ product: CatalogProduct?, result: VerdictResult?) -> some View {
        if let product, let result {
            ShelfVerdictBubble(product: product, result: result, maxReasons: Metrics.bubbleReasons, allowed: $verdictAllowed)
                .id(product.productID)
                .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
        } else {
            SpeechBubble(line, tail: typeSize.isAccessibilitySize ? .down : .leading)
                .contentTransition(.opacity)
                .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
        }
    }

    @ViewBuilder private var pimpi: some View {
        let product = selectedProduct
        let result = product.map(verdict(for:))
        if typeSize.isAccessibilitySize {
            VStack(spacing: Spacing.xs) {
                bubble(product, result: result)
                PokablePimpi(mood: mood(result), size: Metrics.pimpi, onPoke: poke)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .top, spacing: Spacing.xs) {
                PokablePimpi(mood: mood(result), size: Metrics.pimpi, onPoke: poke)
                    // Lifted out of the ground so its feet land on the crest.
                    .padding(.top, -(ShelfPlace.hillRise + Metrics.pimpiStand - Metrics.pimpiFeet))
                bubble(product, result: result).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The lifted product's verdict beside Pimpi: its name (opens the product), the verdict and its first reasons.
/// It counts as a product check, like opening the product does.
private struct ShelfVerdictBubble: View {
    let product: CatalogProduct
    let result: VerdictResult
    let maxReasons: Int
    @Binding var allowed: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false

    private enum Metrics {
        static let tail: CGFloat = 18
        static let tailRadius: CGFloat = 4
        static let stampScale: CGFloat = 1.4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            NavigationLink(value: product) {
                HStack(spacing: Spacing.xxs) {
                    Text(product.name).multilineTextAlignment(.leading)
                    Image(systemName: "chevron.right").font(.footnote.weight(.heavy)).accessibilityHidden(true)
                }
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .frame(minHeight: Chunk.iconButton, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bouncy(0.96))
            ProductCheckGate(key: "product-\(product.productID)", allowed: $allowed) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label(result.verdict.title, systemImage: result.verdict.systemImage + ".fill")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(result.verdict.tint)
                        .scaleEffect(stamped || reduceMotion ? 1 : Metrics.stampScale, anchor: .leading)
                        .opacity(stamped ? 1 : 0)
                        .symbolEffect(.bounce, value: stamped)
                    ForEach(Array(result.reasons.prefix(maxReasons).enumerated()), id: \.element.id) { index, reason in
                        Text(reason.text)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.ds.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(stamped ? 1 : 0)
                            .animation(MotionToken.smooth.resolved(reduceMotion: reduceMotion).animation
                                .delay(reduceMotion ? 0 : MotionToken.stagger(index + 1)), value: stamped)
                    }
                }
                .accessibilityElement(children: .combine)
                .onAppear {
                    withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) { stamped = true }
                }
                .sensoryFeedback(Haptic.capture, trigger: stamped)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Metrics.tailRadius, style: .continuous)
                .fill(Color.ds.surface)
                .frame(width: Metrics.tail, height: Metrics.tail)
                .rotationEffect(.degrees(45))
                .offset(x: -Spacing.xs, y: Spacing.lg)
                .accessibilityHidden(true)
        }
        .dsSurface(radius: Radius.large)
    }
}

/// A white plank with a hard edge, the steps standing on it and their names underneath.
private struct ShelfPlank: View {
    let slots: [ProductCatalog.Slot]
    let selected: ProductCatalog.Slot?
    /// Steps this part of the day skips (sunscreen in the evening): they rest, dimmed.
    let resting: Set<ProductCatalog.Slot>
    let edit: (ProductCatalog.Slot) -> Void
    let select: (ProductCatalog.Slot) -> Void

    private enum Metrics {
        static let plank: CGFloat = 16
        static let nameScale: CGFloat = 0.7
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: Spacing.xs) {
                    ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                        ShelfSlot(slot: slot, isSelected: selected == slot, isResting: resting.contains(slot),
                                  edit: { edit(slot) }, select: { select(slot) })
                            .frame(maxWidth: .infinity)
                            .popIn(delay: MotionToken.stagger(index) * 2)
                    }
                }
                .padding(.horizontal, Spacing.sm)
                Color.clear
                    .frame(height: Metrics.plank)
                    .dsSurface(radius: Metrics.plank / 2)
                    .accessibilityHidden(true)
            }
            // The names are read out as part of each step's button.
            HStack(alignment: .top, spacing: Spacing.xs) {
                ForEach(slots) { slot in
                    Text(slot.title)
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(resting.contains(slot) ? Color.ds.inkSecondary : Color.ds.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(Metrics.nameScale)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .accessibilityHidden(true)
        }
    }
}

/// One routine step on the shelf: the product's photo when you have one, a dashed outline inviting you to add one.
private struct ShelfSlot: View {
    let slot: ProductCatalog.Slot
    let isSelected: Bool
    let isResting: Bool
    let edit: () -> Void
    let select: () -> Void
    @AppStorage private var productID: Int

    private enum Metrics {
        /// How tall a product may stand on the plank.
        static let height: CGFloat = 132
        static let bottle = CGSize(width: 56, height: 104)
        static let empty: CGFloat = 70
        static let dash: CGFloat = 3
        static let dashPattern: [CGFloat] = [7, 6]
        /// How far a tapped product lifts off the plank.
        static let lift: CGFloat = 14
        static let restingOpacity: Double = 0.4
    }

    init(slot: ProductCatalog.Slot, isSelected: Bool, isResting: Bool, edit: @escaping () -> Void, select: @escaping () -> Void) {
        self.slot = slot
        self.isSelected = isSelected
        self.isResting = isResting
        self.edit = edit
        self.select = select
        _productID = AppStorage(wrappedValue: 0, slot.storageKey)
    }

    private var product: CatalogProduct? { ProductCatalog.shared.product(id: productID) }

    var body: some View {
        Group {
            if let product {
                Button(action: select) { face(product) }
                    .accessibilityHint(Text("Shows the verdict"))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        .offset(y: isSelected ? -Metrics.lift : 0)
        .opacity(isResting ? Metrics.restingOpacity : 1)
        .dsAnimation(.bouncy, value: isSelected)
        .dsAnimation(.snappy, value: isResting)
        .accessibilityLabel(Text(verbatim: "\(slot.title), \(product?.name ?? String(localized: "Add yours"))"))
        .accessibilityIdentifier("shelfTile.\(slot.rawValue)")
        .sensoryFeedback(Haptic.toggle, trigger: productID)
    }

    private func face(_ product: CatalogProduct?) -> some View {
        Group {
            if let product {
                AsyncImage(url: product.photoURL) { image in
                    image.resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                } placeholder: {
                    bottle
                }
            } else {
                Image(systemName: "plus")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .frame(width: Metrics.empty, height: Metrics.empty)
                    .background {
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .strokeBorder(Color.ds.ink, style: StrokeStyle(lineWidth: Metrics.dash, lineCap: .round, dash: Metrics.dashPattern))
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.height, alignment: .bottom)
        .contentShape(Rectangle())
    }

    /// Stands in for the photo until it loads: a plain bottle in the step's colour.
    private var bottle: some View {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            .fill(tint)
            .frame(width: Metrics.bottle.width, height: Metrics.bottle.height)
            .overlay {
                Image(systemName: slot.systemImage).font(.title3.weight(.bold)).foregroundStyle(Color.ds.pimpiEye)
            }
    }

    private var tint: Color {
        switch slot {
        case .cleanser: Color.ds.band(.calm)
        case .toner: Color.ds.band(.mild)
        case .moisturizer: Color.ds.pimpiHighlight
        case .sunscreen: Color.ds.sun
        }
    }
}
