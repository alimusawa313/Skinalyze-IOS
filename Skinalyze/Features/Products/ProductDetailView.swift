import SwiftData
import SwiftUI
import SkinalyzeKit

// MARK: - Pieces the Shelf screens share

/// Sizes the Shelf screens share.
enum ShelfPlace {
    /// Room for the floating dock under a page.
    static let dockClearance: CGFloat = 88
    static let pageWidth: CGFloat = 800
    static let hillRise: CGFloat = 40
    /// How far the hill runs past the page's sides (safe areas, the dock in landscape) and past its end (overscroll).
    static let hillBleed: CGFloat = 240
    static let hillRunoff: CGFloat = 1200
    static let disabledOpacity: Double = 0.45
    /// Pimpi beside a heading or a verdict.
    static let pimpi: CGFloat = 72
    /// Pimpi peeking at a camera window.
    static let pimpiPeek: CGFloat = 92
    /// How far a Pimpi at the bottom of the sky reaches down so its feet land on the hill's crest.
    static let pimpiSink: CGFloat = 40
}

/// A scrolling page in Pimpi's place: `sky` sits on the canvas, `ground` sits on a hill that starts behind its top
/// and runs off the end of the page. The hill scrolls with the content.
struct ShelfPlacePage<Sky: View, Ground: View>: View {
    var maxWidth: CGFloat = ShelfPlace.pageWidth
    @ViewBuilder let sky: Sky
    @ViewBuilder let ground: Ground

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                sky
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
                    .zIndex(1) // Pimpi can stand on the crest, in front of the hill
                ground
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, ShelfPlace.hillRise)
                    .padding(.bottom, Spacing.lg)
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) { hill }
                    .onHill()
            }
        }
        .background(Color.ds.canvas.ignoresSafeArea())
    }

    /// The crest spans the page; below it the ground runs past the sides and the end, so no sky shows around it.
    private var hill: some View {
        ZStack(alignment: .top) {
            HillShape(crest: 0, rise: ShelfPlace.hillRise).fill(Color.ds.hill)
            Color.ds.hill
                .padding(.top, ShelfPlace.hillRise)
                .padding(.horizontal, -ShelfPlace.hillBleed)
                .padding(.bottom, -ShelfPlace.hillRunoff)
        }
        .accessibilityHidden(true)
    }
}

/// A row you tap: white and rounded, standing proud of the ground. It sinks when pressed.
struct ShelfRowStyle: ButtonStyle {
    var radius: CGFloat = Radius.medium
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dsGround) private var ground

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Chunk.controlHeight, alignment: .leading)
            .background(shape.fill(Color.ds.surface))
            .offset(y: pressed ? Chunk.depth : 0)
            .background(shape.fill(ground == .hill ? Color.ds.edgeOnHill : Color.ds.edge).offset(y: Chunk.depth))
            .padding(.bottom, Chunk.depth)
            .opacity(isEnabled ? 1 : ShelfPlace.disabledOpacity)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(shape)
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

/// A quiet button that sits on a white panel, where a white button would vanish: sky-coloured, same pressed-in edge.
struct ShelfOnCardButtonStyle: ButtonStyle {
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Chunk.iconButton)
            .background(Capsule().fill(Color.ds.canvas))
            .offset(y: pressed ? Chunk.depthSmall : 0)
            .background(Capsule().fill(Color.ds.edge).offset(y: Chunk.depthSmall))
            .padding(.bottom, Chunk.depthSmall)
            .opacity(isEnabled ? 1 : ShelfPlace.disabledOpacity)
            .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: pressed)
            .contentShape(Capsule())
            .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, isPressed in isPressed }
    }
}

extension ButtonStyle where Self == ShelfRowStyle {
    static var shelfRow: ShelfRowStyle { ShelfRowStyle() }
}

extension ButtonStyle where Self == ShelfOnCardButtonStyle {
    static var shelfOnCard: ShelfOnCardButtonStyle { ShelfOnCardButtonStyle() }
}

/// Pimpi next to a heading, with one handwritten line under it. Pimpi goes above the words at accessibility sizes.
/// Poking Pimpi swaps the line for one of its quips.
struct ShelfPimpiHeading: View {
    let mood: MascotMood
    let title: Text
    var line: Text?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var pokes = 0

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.sm))
        layout {
            PokablePimpi(mood: pokes == 0 ? mood : ShelfQuips.mood(pokes), size: ShelfPlace.pimpi) { pokes += 1 }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title
                    .font(.ds.titleSmall)
                    .foregroundStyle(Color.ds.ink)
                    .accessibilityAddTraits(.isHeader)
                if let shown = pokes == 0 ? line : Text(ShelfQuips.line(pokes)) {
                    shown.font(.ds.pimpiSmall).foregroundStyle(Color.ds.ink).fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
            .dsAnimation(.snappy, value: pokes)
        }
    }
}

/// What Pimpi says when poked on the Shelf screens: Home's quips, about showing up and small habits — never skin.
enum ShelfQuips {
    private static let quips: [(text: LocalizedStringResource, mood: MascotMood)] = [
        ("You showed up. That already counts.", .excited),
        ("Sunscreen first. Feelings later.", .happy),
        ("Wash the pillowcase. That's the whole tip.", .happy),
        ("I'm resting my eyes. You go ahead.", .sleepy),
    ]

    /// The quip for the `pokes`-th poke (1-based).
    static func line(_ pokes: Int) -> LocalizedStringResource { quips[(max(pokes, 1) - 1) % quips.count].text }
    static func mood(_ pokes: Int) -> MascotMood { quips[(max(pokes, 1) - 1) % quips.count].mood }
}

/// The big title and the Done pill at the top of a Shelf sheet.
struct ShelfSheetHeader: View {
    let title: Text
    let done: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            title
                .font(.ds.title)
                .foregroundStyle(Color.ds.ink)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done", action: done).buttonStyle(.chunky(.plain, fullWidth: false))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }
}

/// The last line of a page's sky: words on the leading side and Pimpi on the trailing side, its feet on the hill's
/// crest. Pimpi only reacts here (to what happened, or to a poke); it says nothing.
struct ShelfCrestRow<Leading: View>: View {
    let mood: MascotMood
    @ViewBuilder let leading: Leading
    @State private var pokes = 0

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            leading.frame(maxWidth: .infinity, alignment: .leading)
            PokablePimpi(mood: pokes == 0 ? mood : ShelfQuips.mood(pokes), size: ShelfPlace.pimpiPeek) { pokes += 1 }
        }
        .onChange(of: mood) { pokes = 0 } // a new reaction wins over a poke
        .padding(.bottom, -ShelfPlace.pimpiSink)
    }
}

/// Sizes for `ShelfCameraWindow` (at file scope: a generic type can't hold static stored properties).
private enum ShelfCameraWindowMetrics {
    static let radius: CGFloat = Radius.large
    static let edge: CGFloat = 8
    static let line: CGFloat = 5
    /// How far in from the window's edges the scan line runs.
    static let lineInset: CGFloat = Spacing.lg
    static let sweepSeconds: Double = 1.6
}

/// A dark, rounded camera window with a hard edge. `content` is the live camera (or what stands in for it).
/// While `sweep` is set, a pink scan line sweeps across it (down for a label, sideways for a barcode); under Reduce
/// Motion the line holds still in the middle.
struct ShelfCameraWindow<Content: View>: View {
    var sweep: Axis?
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ShelfCameraWindowMetrics.radius, style: .continuous)
        Color.ds.ink
            .overlay { content }
            .overlay {
                if let sweep { scanLine(sweep) }
            }
            .clipShape(shape)
            .background(shape.fill(Color.ds.inkEdge).offset(y: ShelfCameraWindowMetrics.edge))
            .padding(.bottom, ShelfCameraWindowMetrics.edge)
    }

    private func scanLine(_ axis: Axis) -> some View {
        GeometryReader { proxy in
            let inset = ShelfCameraWindowMetrics.lineInset
            let travel = (axis == .vertical ? proxy.size.height : proxy.size.width) - inset * 2
            let line = Capsule().fill(Color.ds.pimpiBody)
                .frame(width: axis == .vertical ? proxy.size.width - inset * 2 : ShelfCameraWindowMetrics.line,
                       height: axis == .vertical ? ShelfCameraWindowMetrics.line : proxy.size.height - inset * 2)
                .position(x: axis == .vertical ? proxy.size.width / 2 : inset,
                          y: axis == .vertical ? inset : proxy.size.height / 2)
            if reduceMotion {
                line.offset(x: axis == .horizontal ? travel / 2 : 0, y: axis == .vertical ? travel / 2 : 0)
            } else {
                line.phaseAnimator([0.0, 1.0]) { content, phase in
                    content.offset(x: axis == .horizontal ? travel * phase : 0, y: axis == .vertical ? travel * phase : 0)
                } animation: { _ in
                    .easeInOut(duration: ShelfCameraWindowMetrics.sweepSeconds)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Product pieces

/// Product pieces shared by the Shelf: thumbnail, slot picker and the detail page with the verdict.
struct ProductThumbnail: View {
    let product: CatalogProduct

    private enum Metrics {
        static let side: CGFloat = 56
    }

    var body: some View {
        AsyncImage(url: product.photoURL) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: product.slot?.systemImage ?? "drop")
                .foregroundStyle(Color.ds.inkTertiary)
        }
        .frame(width: Metrics.side, height: Metrics.side)
        .background(Color.ds.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
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
                            Text(product.name)
                                .font(.system(.callout, design: .rounded).weight(.heavy))
                                .foregroundStyle(Color.ds.ink)
                            Text(product.brand).font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                        }
                        Spacer()
                        if product.productID == productID {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ds.positive)
                        }
                    }
                }
                .listRowBackground(Color.ds.surface)
            }
            .scrollContentBackground(.hidden)
            .dsCanvas()
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
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @State private var checkAllowed: Bool?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let photo: CGFloat = 150
        static let photoInset: CGFloat = 22
        /// The bottle leans gently from side to side, like the mock's.
        static let tiltRest: Double = -7
        static let tiltLean: Double = -3
        static let tiltSeconds: Double = 2
    }

    var body: some View {
        let guidance = SkinTypeGuidance.for(SkinType(stored: skinTypeRaw))
        let helpful = guidance.lookFor.map { $0.name.lowercased() }
        let caution = guidance.avoid.map { $0.name.lowercased() }
        ShelfPlacePage {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                ProductCheckGate(key: "product-\(product.productID)", allowed: $checkAllowed) {
                    ProductCheckSummary(product: product)
                }
            }
        } ground: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ProductToolsSection(product: product)
                ingredients(helpful: helpful, caution: caution)
                if let link = product.link.flatMap(URL.init(string:)) {
                    Link("View source page", destination: link)
                        .font(.system(.callout, design: .rounded).weight(.heavy))
                        .underline()
                        .foregroundStyle(Color.ds.ink)
                        .frame(maxWidth: .infinity, minHeight: Chunk.iconButton)
                }
            }
        }
        // Clear of the floating dock.
        .safeAreaPadding(.bottom, ShelfPlace.dockClearance)
        .navigationTitle(product.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if checkAllowed == true {
            ShareCardButton {
                // The same rule-based verdict the page shows.
                .verdict(product: product, result: ProductVerdictEngine.evaluate(
                    ingredients: product.ingredientList.map { $0.lowercased() },
                    profile: VerdictProfileBuilder.make(latest: scans.first)))
            }
            }
        }
    }

    /// The product photo on a soft disc, with what it is beside it (under it at accessibility sizes).
    private var hero: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.lg))
        return layout {
            AsyncImage(url: product.photoURL) { image in
                image.resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            } placeholder: {
                Image(systemName: product.slot?.systemImage ?? "drop")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            .padding(Metrics.photoInset)
            .phaseAnimator(reduceMotion ? [Metrics.tiltRest] : [Metrics.tiltRest, Metrics.tiltLean]) { content, tilt in
                content.rotationEffect(.degrees(tilt), anchor: .bottom)
            } animation: { _ in
                .easeInOut(duration: Metrics.tiltSeconds)
            }
            .frame(width: Metrics.photo, height: Metrics.photo)
            .background(Circle().fill(Color.ds.hillFar))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let slot = product.slot {
                    Text(slot.title)
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .dsSurface(radius: Radius.small)
                }
                Text(product.name)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(product.brand)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ingredients(helpful: [String], caution: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionTitle("Ingredients")
            if product.ingredientList.isEmpty {
                Text("No ingredient list for this product yet.").font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
            }
            ForEach(Array(product.ingredientList.enumerated()), id: \.offset) { _, ingredient in
                let name = ingredient.lowercased()
                let isHelpful = helpful.contains { name.contains($0) }
                let isCaution = caution.contains { name.contains($0) }
                IngredientPill(name: ingredient, fit: isHelpful ? .helpful : (isCaution ? .caution : .plain))
            }
        }
    }
}

/// One ingredient as a white pill: a mark for how it fits your skin type, its name, and a note when it is flagged.
private struct IngredientPill: View {
    enum Fit {
        case helpful, caution, plain
    }

    let name: String
    let fit: Fit

    private enum Metrics {
        static let plainDot: CGFloat = 8
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            mark.frame(minWidth: Spacing.lg).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                switch fit {
                case .helpful: note(Text("Good for your skin type"))
                case .caution: note(Text("Go easy for your skin type"))
                case .plain: EmptyView()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: Chunk.iconButton)
        .dsSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var mark: some View {
        switch fit {
        case .helpful:
            Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Color.ds.positive)
        case .caution:
            Image(systemName: "exclamationmark.circle.fill").font(.title3).foregroundStyle(Color.ds.caution)
        case .plain:
            Circle().fill(Color.ds.hairline).frame(width: Metrics.plainDot, height: Metrics.plainDot)
        }
    }

    private func note(_ text: Text) -> some View {
        text.font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
    }
}
