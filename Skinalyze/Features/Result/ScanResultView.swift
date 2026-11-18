import SwiftData
import SwiftUI
import SkinalyzeKit

/// One scan, explained. Shown right after scanning and from the timeline. Saved results are never re-analyzed.
struct ScanResultView: View {
    let session: ScanSession
    var isFreshScan = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var allScans: [ScanSession]
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @State private var angle: CaptureAngle = .front
    @State private var visibleTypes = Set(LesionType.allCases)
    @State private var expandedType: LesionType?
    @State private var showsSources = false

    private var previous: ScanSession? {
        allScans.first { $0.createdAt < session.createdAt }
    }

    var body: some View {
        AdaptivePanes {
            photoSection
        } secondary: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                scoreSection
                if session.hasZoneData { zoneSection }
                lesionSection
                guidanceSection
                productsSection
                disclaimer
            }
        }
        .dsCanvas()
        .navigationTitle(Text(session.createdAt, format: .dateTime.day().month().year()))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if isFreshScan {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showsSources) {
            SourcesView(skinType: SkinType(stored: skinTypeRaw))
        }
    }

    // MARK: Photo

    private var photoSection: some View {
        VStack(spacing: Spacing.sm) {
            Picker("Angle", selection: $angle) {
                ForEach(availableAngles, id: \.self) { Text(GuidanceCopy.title(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            if let image = session.uiImage(at: availableAngles.firstIndex(of: angle) ?? 0) {
                ScanPhotoView(image: image, detections: session.detections(for: angle, types: visibleTypes))
                    .id(angle)
                    .transition(.opacity)
            }
            if session.captureMode == .legacy {
                Label("Saved with an earlier version — counts are shown as recorded.", systemImage: "clock.arrow.circlepath")
                    .font(.ds.footnote)
                    .foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .dsAnimation(.smooth, value: angle)
    }

    private var availableAngles: [CaptureAngle] {
        let angles = session.sortedCaptures.map(\.angle)
        return angles.isEmpty ? [.front] : angles
    }

    // MARK: Score

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                Text(session.breakoutIndex, format: .number)
                    .font(.ds.numeral)
                    .contentTransition(.numericText(value: Double(session.breakoutIndex)))
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    BandPill(session.band)
                    Text("Breakout index").font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer()
                if let previous {
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        DeltaBadge(delta: session.breakoutIndex - previous.breakoutIndex)
                        Text("vs. last scan").font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                    }
                }
            }
            Text(BandCopy.summary(session.band)).font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
        }
        .dsCard()
    }

    // MARK: Zones

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("By zone")
            let maxIndex = max(FaceZone.allCases.map(session.zoneIndex).max() ?? 1, 1)
            ForEach(FaceZone.allCases, id: \.self) { zone in
                let value = session.zoneIndex(zone)
                HStack(spacing: Spacing.sm) {
                    Text(GuidanceCopy.zoneName(zone)).font(.ds.callout).frame(minWidth: 96, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule().fill(Color.ds.hairline)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.ds.band(BreakoutBand.classify(index: value)))
                                    .frame(width: proxy.size.width * CGFloat(value) / CGFloat(maxIndex))
                            }
                    }
                    .frame(height: 8)
                    Text(value, format: .number).font(.ds.callout.monospacedDigit()).frame(minWidth: 28, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .dsCard()
    }

    // MARK: Lesions

    private var lesionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle("What we noticed")
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(LesionType.allCases, id: \.self) { type in
                        Chip(LesionGlyph.displayName(for: type), systemImage: LesionGlyph.symbolName(for: type),
                             isSelected: visibleTypes.contains(type)) {
                            visibleTypes.formSymmetricDifference([type])
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            ForEach(LesionType.allCases.filter { session.counts[$0] > 0 }, id: \.self) { type in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedType == type },
                    set: { expandedType = $0 ? type : nil }
                )) {
                    Text(LesionGlyph.explanation(for: type))
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Image(systemName: LesionGlyph.symbolName(for: type)).foregroundStyle(Color.ds.signal)
                        Text(LesionGlyph.displayName(for: type)).font(.ds.headline)
                        Spacer()
                        Text(session.counts[type], format: .number).font(.ds.numeralSmall)
                    }
                }
                .tint(Color.ds.inkSecondary)
            }
            if session.counts.total == 0 {
                Text("Nothing stood out in this scan.").font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .dsCard()
    }

    // MARK: Guidance

    private var guidanceSection: some View {
        let skinType = SkinType(stored: skinTypeRaw)
        let guidance = SkinTypeGuidance.for(skinType)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("For \(skinType.title.lowercased()) skin").font(.ds.titleSmall).accessibilityAddTraits(.isHeader)
            Text("Look for").font(.ds.label).foregroundStyle(Color.ds.positive)
            ForEach(guidance.lookFor) { IngredientRow(note: $0) }
            Text("Go easy on").font(.ds.label).foregroundStyle(Color.ds.caution)
            ForEach(guidance.avoid) { IngredientRow(note: $0) }
            Button("Where this comes from") { showsSources = true }
                .font(.subheadline.weight(.semibold))
        }
        .dsCard()
    }

    // MARK: Products

    @ViewBuilder private var productsSection: some View {
        let products = session.productIDs.compactMap(ProductCatalog.shared.product(id:))
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle("Using at the time")
                ForEach(products) { product in
                    HStack {
                        Image(systemName: product.slot?.systemImage ?? "drop").foregroundStyle(Color.ds.inkSecondary)
                        VStack(alignment: .leading) {
                            Text(product.name).font(.ds.callout)
                            Text(product.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                }
            }
            .dsCard()
        }
    }

    private var disclaimer: some View {
        Text("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose. If something is painful or persistent, see a dermatologist.")
            .font(.ds.footnote)
            .foregroundStyle(Color.ds.inkTertiary)
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title).font(.ds.titleSmall).foregroundStyle(Color.ds.ink).accessibilityAddTraits(.isHeader)
    }
}

private struct IngredientRow: View {
    let note: IngredientNote

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.name).font(.ds.callout.weight(.semibold))
            Text(note.note).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SourcesView: View {
    let skinType: SkinType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ingredient suggestions are general information from these sources, not medical advice.")
                        .font(.ds.footnote)
                }
                Section("Sources") {
                    ForEach(SkinTypeGuidance.for(skinType).sources) { source in
                        if let url = URL(string: source.url) {
                            Link(source.title, destination: url)
                        }
                    }
                }
            }
            .navigationTitle("Sources")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
