import SwiftUI
import SkinalyzeKit

/// Earlier ↔ later, in Pimpi's place: the two photos in one white frame with a wipe handle on the sky, the index
/// "a → b" beside Pimpi, and the per-type counts as white pills on the hill. Side by side when wide (iPhone Duo
/// open: before | after across the fold, so no draggable handle ever sits on the fold).
struct CompareView: View {
    @Environment(TutorialModel.self) private var tutorial: TutorialModel?
    let earlier: ScanSession
    let later: ScanSession

    @Environment(\.dismiss) private var dismiss
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var angle: CaptureAngle = .front
    @State private var split: CGFloat = 0.5
    /// Both photos re-rendered with the eyes on the same points, so the faces line up exactly.
    @State private var alignedEarlier: AlignedPhoto?
    @State private var alignedLater: AlignedPhoto?
    @State private var sharedCard: ShareCardSource?
    @State private var sharedVideo: VideoShareSource?
    /// The later index shown; it rolls up or down from the earlier one when the screen opens.
    @State private var shownLater: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let maxWidth: CGFloat = 1100
        static let pimpi: CGFloat = 78
        static let pillMinWidth: CGFloat = 150
        static let pillHeight: CGFloat = 46
        static let pimpiLineTilt: Double = -6
        static let pimpiLineWidth: CGFloat = 96
        /// Where the hill starts, as a fraction of the screen height.
        static let hillCrest: CGFloat = 0.6
        static let index: CGFloat = 46
        static let indexMinScale: CGFloat = 0.5
        static let rollDelay: Double = 0.35
    }

    @ScaledMetric(relativeTo: .largeTitle) private var indexSize: CGFloat = Metrics.index

    var body: some View {
        compareBody.onAppear { tutorial?.noteCompared() }
    }

    @ViewBuilder private var compareBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                topBar
                if ScanFlow.sequence.count > 1 {
                    PillPicker(ScanFlow.sequence.map { (value: $0, title: GuidanceCopy.title(for: $0)) }, selection: $angle)
                        .accessibilityLabel("Angle")
                }
                photos
                totals
                Group {
                    typeTable
                    if earlier.hasZoneData && later.hasZoneData { zoneTable }
                    productChanges
                }
                .onHill()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: Metrics.maxWidth)
            .frame(maxWidth: .infinity)
        }
        .dsHill(crest: Metrics.hillCrest)
        .sheet(item: $sharedCard) { ShareCardSheet(source: $0) }
        .sheet(item: $sharedVideo) { VideoShareSheet(source: $0) }
        .onAppear { quests?.did(.lookBack, isPro: access?.policy.hasFullAccess ?? false) }
        .task {
            guard shownLater == nil else { return }
            shownLater = earlier.breakoutIndex
            try? await Task.sleep(for: .seconds(Metrics.rollDelay))
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { shownLater = later.breakoutIndex }
        }
        .task(id: angle) { await alignPhotos() }
        .navigationTitle("Compare")
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            Button { dismiss() } label: {
                Label("Done", systemImage: "xmark")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.chunkyIcon)
            Spacer(minLength: 0)
            Text("Compare")
                .font(.ds.title)
                .foregroundStyle(Color.ds.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            shareMenu
        }
        .padding(.top, Spacing.md)
    }

    private var shareMenu: some View {
        Menu {
            Button("Picture", systemImage: "photo") {
                guard let before = alignedEarlier?.image, let after = alignedLater?.image else { return }
                sharedCard = .compare(earlier: earlier, later: later, earlierPhoto: before, laterPhoto: after)
            }
            Button("Slider video", systemImage: "slider.horizontal.below.rectangle") {
                guard let before = alignedEarlier?.image, let after = alignedLater?.image else { return }
                sharedVideo = .wipe(CompareShare(earlier: before, later: after, earlierDate: earlier.createdAt,
                                                 laterDate: later.createdAt, earlierIndex: earlier.breakoutIndex,
                                                 laterIndex: later.breakoutIndex))
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.button)
        .buttonStyle(.chunkyIcon)
        .accessibilityIdentifier("compareShare")
        .disabled(alignedEarlier == nil || alignedLater == nil)
    }

    private func alignPhotos() async {
        async let earlierPhoto = align(earlier)
        async let laterPhoto = align(later)
        let (first, second) = await (earlierPhoto, laterPhoto)
        withAnimation(.smooth) {
            alignedEarlier = first
            alignedLater = second
        }
    }

    private func align(_ scan: ScanSession) async -> AlignedPhoto? {
        guard let image = image(scan) else { return nil }
        return await FaceAligner.shared.aligned(image, key: "\(scan.id)-\(angle.rawValue)")
    }

    private func image(_ scan: ScanSession) -> UIImage? {
        let index = scan.sortedCaptures.firstIndex { $0.angle == angle } ?? 0
        return scan.uiImage(at: index)
    }

    // MARK: Photos

    @ViewBuilder private var photos: some View {
        if horizontalSizeClass == .regular {
            // Before | after as passive images; no draggable handle that could land on the iPhone Duo fold.
            HStack(alignment: .top, spacing: Spacing.xl) {
                labelled(earlier, title: "Earlier")
                labelled(later, title: "Later")
            }
        } else if let before = alignedEarlier?.image, let after = alignedLater?.image {
            VStack(spacing: Spacing.sm) {
                WipeComparison(before: before, after: after, split: $split)
                    .overlay(alignment: .bottomLeading) { tag("Earlier", earlier) }
                    .overlay(alignment: .bottomTrailing) { tag("Later", later) }
                    .photoFrame()
                Label("Lined up by your eyes", systemImage: "eye")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Color.ds.surfaceRaised
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { ProgressView().tint(Color.ds.ink) }
                .photoFrame()
        }
    }

    private func labelled(_ scan: ScanSession, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.ds.label).textCase(.uppercase).foregroundStyle(Color.ds.inkSecondary)
            Text(scan.createdAt, format: .dateTime.day().month().year())
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
            if let aligned = scan == earlier ? alignedEarlier : alignedLater {
                ScanPhotoView(image: aligned.image, detections: scan.detections(for: angle, types: Set(LesionType.allCases)),
                              mapPoint: { aligned.map($0) })
                    .photoFrame()
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// A white date pill on the photo.
    private func tag(_ title: LocalizedStringKey, _ scan: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.ds.label).foregroundStyle(Color.ds.inkSecondary)
            Text(scan.createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Color.ds.surface))
        .padding(Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: Numbers

    /// Pimpi beside "a → b"; Pimpi's line is about showing up, never about the result.
    private var totals: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) {
                pimpi
                index
                Spacer(minLength: 0)
                pimpiLine.frame(width: Metrics.pimpiLineWidth)
            }
            HStack(spacing: Spacing.sm) {
                pimpi
                index
            }
            index
        }
    }

    /// Pokable; hops when the angle changes (looking back is the effort it cheers).
    private var pimpi: some View {
        PokablePimpi(size: Metrics.pimpi, cheer: angle)
    }

    private var pimpiLine: some View {
        Text("You kept showing up.")
            .font(.ds.pimpiSmall)
            .foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .rotationEffect(.degrees(Metrics.pimpiLineTilt))
    }

    private var index: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text("Breakout index").font(.system(.subheadline, design: .rounded).weight(.heavy))
                DeltaBadge(delta: later.breakoutIndex - earlier.breakoutIndex)
            }
            Group {
                let rolled = shownLater ?? later.breakoutIndex
                Text("\(earlier.breakoutIndex) → \(rolled)")
                    .font(.system(size: indexSize, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(rolled)))
                    .lineLimit(1)
                    .minimumScaleFactor(Metrics.indexMinScale)
            }
        }
        .foregroundStyle(Color.ds.ink)
        .accessibilityElement(children: .combine)
    }

    private var pillColumns: [GridItem] {
        [GridItem(.adaptive(minimum: Metrics.pillMinWidth), spacing: Spacing.sm)]
    }

    private var typeTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("By type")
            LazyVGrid(columns: pillColumns, spacing: Spacing.sm) {
                ForEach(Array(LesionType.allCases.enumerated()), id: \.element) { offset, type in
                    pill(order: offset) {
                        Text(LesionGlyph.displayName(for: type))
                        Spacer(minLength: Spacing.xs)
                        Text("\(earlier.counts[type]) → \(later.counts[type])").monospacedDigit()
                    }
                }
            }
        }
    }

    private var zoneTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("By zone")
            LazyVGrid(columns: pillColumns, spacing: Spacing.sm) {
                ForEach(Array(FaceZone.allCases.enumerated()), id: \.element) { offset, zone in
                    pill(order: offset) {
                        Text(GuidanceCopy.zoneName(zone))
                        Spacer(minLength: Spacing.xs)
                        DeltaBadge(delta: later.zoneIndex(zone) - earlier.zoneIndex(zone))
                    }
                }
            }
        }
    }

    /// A resting white pill with the hard bottom edge.
    private func pill<Content: View>(order: Int, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0, content: content)
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: Metrics.pillHeight)
            .dsSurface(radius: Radius.medium)
            .accessibilityElement(children: .combine)
            .popIn(delay: MotionToken.stagger(order))
    }

    @ViewBuilder private var productChanges: some View {
        let started = Set(later.productIDs).subtracting(earlier.productIDs).compactMap(ProductCatalog.shared.product(id:))
        let stopped = Set(earlier.productIDs).subtracting(later.productIDs).compactMap(ProductCatalog.shared.product(id:))
        if !started.isEmpty || !stopped.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle("Routine changes in between")
                ForEach(started) { change(Text("Started \($0.name)"), symbol: "plus", filled: true) }
                ForEach(stopped) { change(Text("Stopped \($0.name)"), symbol: "minus", filled: false) }
                Text("Other things change too — think of this as a clue, not proof.")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    /// Started is an ink pill, stopped a white one; the words say which, not the colour.
    private func change(_ text: Text, symbol: String, filled: Bool) -> some View {
        Label { text } icon: { Image(systemName: symbol).fontWeight(.black) }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(filled ? Color.ds.canvas : Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(filled ? Color.ds.ink : Color.ds.surface))
            .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// A photo in a thick white frame with the hard bottom edge.
    func photoFrame() -> some View {
        clipShape(RoundedRectangle(cornerRadius: Radius.large - Spacing.xs, style: .continuous))
            .padding(Spacing.xs)
            .dsSurface(radius: Radius.large)
    }
}

/// Drag the handle to wipe between two photos. Supports VoiceOver adjust.
private struct WipeComparison: View {
    let before: UIImage
    let after: UIImage
    @Binding var split: CGFloat
    /// The handle nudges side to side until it is first touched, so it reads as something to drag.
    @State private var touched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let line: CGFloat = 6
        static let handle: CGFloat = 48
        static let step: CGFloat = 0.1
        static let nudge: CGFloat = 8
        static let nudgeSeconds: Double = 0.7
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Image(uiImage: after).resizable().scaledToFill()
                    .frame(width: width, height: proxy.size.height).clipped()
                Image(uiImage: before).resizable().scaledToFill()
                    .frame(width: width, height: proxy.size.height).clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: width * split) }
                Rectangle().fill(Color.ds.surface).frame(width: Metrics.line)
                    .overlay {
                        Image(systemName: "chevron.left.chevron.right")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.ds.ink)
                            .frame(width: Metrics.handle, height: Metrics.handle)
                            .background(Circle().fill(Color.ds.surface))
                            .phaseAnimator(touched || reduceMotion ? [0] : [0, Metrics.nudge, 0, -Metrics.nudge]) { handle, nudge in
                                handle.offset(x: nudge)
                            } animation: { _ in .easeInOut(duration: Metrics.nudgeSeconds / 2) }
                    }
                    .offset(x: width * split - Metrics.line / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                touched = true
                split = min(max(value.location.x / width, 0), 1)
            })
            .sensoryFeedback(Haptic.scrub, trigger: split > 0.5)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Before and after comparison")
        .accessibilityValue(Text("\(Int(split * 100)) percent earlier photo"))
        .accessibilityAdjustableAction { direction in
            touched = true
            switch direction {
            case .increment: split = min(split + Metrics.step, 1)
            case .decrement: split = max(split - Metrics.step, 0)
            @unknown default: break
            }
        }
    }
}
