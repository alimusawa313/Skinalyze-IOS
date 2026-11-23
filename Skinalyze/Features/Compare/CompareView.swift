import SwiftUI
import SkinalyzeKit

/// Earlier ↔ later. Wipe slider when narrow; side by side when wide (iPhone Duo open: before | after across the fold,
/// so no draggable handle ever sits on the fold).
struct CompareView: View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("Angle", selection: $angle) {
                    ForEach(ScanFlow.sequence, id: \.self) { Text(GuidanceCopy.title(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                photos
                totals
                typeTable
                if earlier.hasZoneData && later.hasZoneData { zoneTable }
                productChanges
            }
            .padding(Spacing.md)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .dsCanvas()
        .onAppear { quests?.did(.lookBack, isPro: access?.policy.hasFullAccess ?? false) }
        .task(id: angle) { await alignPhotos() }
        .navigationTitle("Compare")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ShareCardButton {
                    guard let before = alignedEarlier?.image, let after = alignedLater?.image else { return nil }
                    return .compare(earlier: earlier, later: later, earlierPhoto: before, laterPhoto: after)
                }
                .disabled(alignedEarlier == nil || alignedLater == nil)
            }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
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

    @ViewBuilder private var photos: some View {
        if horizontalSizeClass == .regular {
            // Before | after as passive images; no draggable handle that could land on the iPhone Duo fold.
            HStack(alignment: .top, spacing: Spacing.xl) {
                labelled(earlier, title: "Earlier")
                labelled(later, title: "Later")
            }
        } else if let before = alignedEarlier?.image, let after = alignedLater?.image {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                WipeComparison(before: before, after: after, split: $split)
                    .overlay(alignment: .topLeading) { tag("Earlier", earlier) }
                    .overlay(alignment: .topTrailing) { tag("Later", later) }
                Label("Lined up by your eyes", systemImage: "eye")
                    .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
            }
        } else {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(Color.ds.surfaceRaised)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }

    private func labelled(_ scan: ScanSession, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.ds.label).foregroundStyle(Color.ds.inkSecondary)
            Text(scan.createdAt, format: .dateTime.day().month().year()).font(.ds.headline)
            if let aligned = scan == earlier ? alignedEarlier : alignedLater {
                ScanPhotoView(image: aligned.image, detections: scan.detections(for: angle, types: Set(LesionType.allCases)),
                              mapPoint: { aligned.map($0) })
            }
        }
    }

    private func tag(_ title: LocalizedStringKey, _ scan: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.ds.label)
            Text(scan.createdAt, format: .dateTime.day().month()).font(.ds.caption)
        }
        .padding(Spacing.xs)
        .glassEffect(in: RoundedRectangle(cornerRadius: Radius.small))
        .padding(Spacing.sm)
    }

    private var totals: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Breakout index").font(.ds.headline)
                Text("\(earlier.breakoutIndex) → \(later.breakoutIndex)").font(.ds.numeralSmall)
            }
            Spacer()
            DeltaBadge(delta: later.breakoutIndex - earlier.breakoutIndex)
        }
        .dsCard()
    }

    private var typeTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("By type")
            ForEach(LesionType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: LesionGlyph.symbolName(for: type)).foregroundStyle(Color.ds.inkSecondary)
                    Text(LesionGlyph.displayName(for: type)).font(.ds.callout)
                    Spacer()
                    Text("\(earlier.counts[type]) → \(later.counts[type])").font(.ds.callout.monospacedDigit())
                    DeltaBadge(delta: later.counts[type] - earlier.counts[type])
                }
                .accessibilityElement(children: .combine)
            }
        }
        .dsCard()
    }

    private var zoneTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("By zone")
            ForEach(FaceZone.allCases, id: \.self) { zone in
                HStack {
                    Text(GuidanceCopy.zoneName(zone)).font(.ds.callout)
                    Spacer()
                    DeltaBadge(delta: later.zoneIndex(zone) - earlier.zoneIndex(zone))
                }
            }
        }
        .dsCard()
    }

    @ViewBuilder private var productChanges: some View {
        let started = Set(later.productIDs).subtracting(earlier.productIDs).compactMap(ProductCatalog.shared.product(id:))
        let stopped = Set(earlier.productIDs).subtracting(later.productIDs).compactMap(ProductCatalog.shared.product(id:))
        if !started.isEmpty || !stopped.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle("Routine changes in between")
                ForEach(started) { Label("Started \($0.name)", systemImage: "plus.circle").font(.ds.callout) }
                ForEach(stopped) { Label("Stopped \($0.name)", systemImage: "minus.circle").font(.ds.callout) }
                Text("Other things change too — think of this as a clue, not proof.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            .dsCard()
        }
    }
}

/// Drag the handle to wipe between two photos. Supports VoiceOver adjust.
private struct WipeComparison: View {
    let before: UIImage
    let after: UIImage
    @Binding var split: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Image(uiImage: after).resizable().scaledToFill()
                    .frame(width: width, height: proxy.size.height).clipped()
                Image(uiImage: before).resizable().scaledToFill()
                    .frame(width: width, height: proxy.size.height).clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: width * split) }
                Capsule().fill(.white).frame(width: 3)
                    .overlay {
                        Image(systemName: "chevron.left.chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.ds.ink)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.white))
                    }
                    .offset(x: width * split - 1.5)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                split = min(max(value.location.x / width, 0), 1)
            })
            .sensoryFeedback(Haptic.scrub, trigger: split > 0.5)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Before and after comparison")
        .accessibilityValue(Text("\(Int(split * 100)) percent earlier photo"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: split = min(split + 0.1, 1)
            case .decrement: split = max(split - 0.1, 0)
            @unknown default: break
            }
        }
    }
}
