import SwiftData
import SwiftUI
import SkinalyzeKit

// Phase 8: "this area over time" (P1) and the zone map on the head (P2). Both show what was marked — no claims that
// a spot appeared, healed or went away (the detector does not find every mark every time).

/// Which patch to follow: a spot tapped on one scan's photo.
struct AreaFollow: Identifiable {
    let id = UUID()
    let sessionID: UUID
    let angle: CaptureAngle
    /// Detection centre, Vision-normalized (bottom-left) in that scan's photo.
    let centre: CGPoint
}

/// The same patch of skin cut from every scan's eye-aligned photo of that angle, oldest to newest, with rings where
/// a spot was marked: a grid of white-edged tiles on the sky, the honest notes on the hill underneath.
struct AreaTimelineView: View {
    let follow: AreaFollow

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    private var scans: [ScanSession] { allScans.filter { !$0.isDeleted && $0.modelContext != nil } }
    @State private var frames: [Frame] = []
    @State private var isLoading = true

    struct Frame: Identifiable {
        let id: UUID
        let date: Date
        let image: UIImage
        let marks: [CGPoint]
        let isTapped: Bool
    }

    private enum Metrics {
        /// Tiles are at least this wide: two across on a phone, more on wider screens.
        static let tileMinimum: CGFloat = 140
        static let ring: CGFloat = 30
        static let ringLine: CGFloat = 4
        /// The white halo round each ring, so it reads on any skin tone.
        static let ringHalo: CGFloat = 7
        static let tappedLine: CGFloat = 4
        static let loadingHeight: CGFloat = 220
        static let lineGap: CGFloat = 2
        static let maxWidth: CGFloat = 900
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("The same patch of skin in each scan, lined up by your eyes. Rings show where a spot was marked.")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.ds.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: Metrics.loadingHeight)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.tileMinimum), spacing: Spacing.md)],
                                  alignment: .leading, spacing: Spacing.lg) {
                            ForEach(Array(frames.enumerated()), id: \.element.id) { offset, frame in
                                tile(frame).popIn(delay: MotionToken.stagger(offset))
                            }
                        }
                    }
                    notes
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scrollingHill()
                }
                .padding(Spacing.lg)
                .frame(maxWidth: Metrics.maxWidth)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .navigationTitle("This area over time")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .task { await load() }
    }

    /// What the tiles can and can't tell you, in the normal type.
    private var notes: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if follow.angle != .front {
                Label("Side photos line up less exactly than the front.", systemImage: "info.circle")
            }
            Text("Detection is not perfect: a mark can be missed in one scan and found in the next. Use your own eyes.")
        }
        .font(.ds.footnote.weight(.semibold))
        .foregroundStyle(Color.ds.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(_ frame: Frame) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(uiImage: frame.image).resizable().scaledToFill()
                }
                .overlay {
                    GeometryReader { proxy in
                        ForEach(Array(frame.marks.enumerated()), id: \.offset) { _, mark in
                            Circle().strokeBorder(Color.ds.ink, lineWidth: Metrics.ringLine)
                                .background(Circle().strokeBorder(Color.ds.surface, lineWidth: Metrics.ringHalo))
                                .frame(width: Metrics.ring, height: Metrics.ring)
                                .position(x: mark.x * proxy.size.width, y: mark.y * proxy.size.height)
                        }
                    }
                }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(frame.isTapped ? Color.ds.signal : .clear, lineWidth: Metrics.tappedLine)
                }
                .dsSurface(radius: Radius.medium)
            VStack(alignment: .leading, spacing: Metrics.lineGap) {
                Text(frame.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                Text(frame.marks.isEmpty ? "Nothing marked here" : "\(frame.marks.count) marked here")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        let output = AlignedPhoto.outputSize
        // Where the tapped spot sits in the aligned frame.
        guard let tappedScan = scans.first(where: { $0.id == follow.sessionID }),
              let tappedImage = image(of: tappedScan),
              let tappedAligned = await FaceAligner.shared.aligned(tappedImage, key: "\(tappedScan.id)-\(follow.angle.rawValue)")
        else {
            isLoading = false
            return
        }
        let normalized = tappedAligned.map(follow.centre)
        let crop = AreaCrop.rect(around: CGPoint(x: normalized.x * output.width, y: normalized.y * output.height), in: output)

        var loaded: [Frame] = []
        for scan in scans {
            guard let photo = image(of: scan),
                  let aligned = await FaceAligner.shared.aligned(photo, key: "\(scan.id)-\(follow.angle.rawValue)"),
                  let cropped = aligned.image.cgImage?.cropping(to: crop) else { continue }
            let points = scan.detections(for: follow.angle, types: Set(LesionType.allCases)).map { detection in
                let p = aligned.map(CGPoint(x: detection.box.center.x, y: detection.box.center.y))
                return CGPoint(x: p.x * output.width, y: p.y * output.height)
            }
            loaded.append(Frame(id: scan.id, date: scan.createdAt, image: UIImage(cgImage: cropped),
                                marks: AreaCrop.marks(points, in: crop), isTapped: scan.id == follow.sessionID))
        }
        frames = loaded
        isLoading = false
    }

    private func image(of scan: ScanSession) -> UIImage? {
        guard let index = scan.sortedCaptures.firstIndex(where: { $0.angle == follow.angle }) else { return nil }
        return scan.uiImage(at: index)
    }
}

/// Spots marked per face zone, on the latest 3D head (or the front photo), scrubbable through every scan: the face with
/// the busier areas glowing on the sky, the scan-date slider and the zone bars on the hill.
struct ZoneMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    /// A scan deleted while this is open (here, or on another device via iCloud) must never be read.
    private var scans: [ScanSession] { allScans.filter { !$0.isDeleted && $0.modelContext != nil } }
    @State private var position: Double = 0
    @State private var frontPhoto: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let stage: CGFloat = 380
        static let photoMaxHeight: CGFloat = 420
        /// The white sticker edge round the photo.
        static let photoBorder: CGFloat = 6
        static let maxWidth: CGFloat = 700
    }

    private var levels: [[FaceZone: Double]] {
        ZoneHeat.levels(scans.map { scan in
            Dictionary(uniqueKeysWithValues: FaceZone.allCases.map { ($0, scan.zoneIndex($0)) })
        })
    }

    private var selected: Int { min(max(Int(position.rounded()), 0), max(scans.count - 1, 0)) }
    private var headScan: ScanSession? { scans.last { $0.faceMesh != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if scans.isEmpty {
                        ContentUnavailableView("No scans yet", systemImage: "faceid")
                    } else {
                        stage
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            scrubber
                            zoneList
                            Text("Shows how many spots were marked in each area, not what they are.")
                                .font(.ds.footnote.weight(.semibold))
                                .foregroundStyle(Color.ds.ink)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .scrollingHill()
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: Metrics.maxWidth)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .navigationTitle("Zone map")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .onAppear {
            position = Double(max(scans.count - 1, 0))
            #if DEBUG
            if let start = UserDefaults.standard.string(forKey: "zoneMapStart").flatMap(Double.init) { position = start }
            #endif
        }
        .task { await loadFrontPhoto() }
    }

    @ViewBuilder private var stage: some View {
        let heat = levels.indices.contains(selected) ? levels[selected] : [:]
        if let mesh = headScan?.faceMesh {
            Face3DView(mesh: mesh, heat: heat, showsPins: false)
                .frame(height: Metrics.stage)
                .face3DStage()
                .accessibilityLabel(Text("Your 3D scan with the busier areas glowing"))
        } else if let frontPhoto {
            Image(uiImage: frontPhoto).resizable().scaledToFit()
                .overlay { FlatHeat(heat: heat) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .padding(Metrics.photoBorder)
                .dsSurface(radius: Radius.large)
                .frame(maxHeight: Metrics.photoMaxHeight)
                .frame(maxWidth: .infinity)
        }
    }

    private var scrubber: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if scans.indices.contains(selected) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        scanDateLabel
                        Spacer(minLength: Spacing.sm)
                        scanDate
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        scanDateLabel
                        scanDate
                    }
                }
                .accessibilityHidden(true) // the slider reads out the date
            }
            if scans.count > 1 {
                Slider(value: $position, in: 0...Double(scans.count - 1), step: 1) {
                    Text("Scan date")
                }
                .tint(Color.ds.ink)
                .accessibilityValue(scans.indices.contains(selected)
                                    ? Text(scans[selected].createdAt, format: .dateTime.day().month().year()) : Text(verbatim: ""))
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
    }

    private var scanDateLabel: some View {
        Text("Scan date")
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
    }

    private var scanDate: some View {
        Text(scans[selected].createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.ds.ink)
            .contentTransition(.numericText())
    }

    private var zoneList: some View {
        let heat = levels.indices.contains(selected) ? levels[selected] : [:]
        return VStack(spacing: Spacing.sm) {
            ForEach(FaceZone.allCases, id: \.self) { zone in
                ZoneBar(zone: zone, count: scans.indices.contains(selected) ? scans[selected].zoneIndex(zone) : 0,
                        fraction: heat[zone] ?? 0)
            }
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: selected)
    }

    private func loadFrontPhoto() async {
        guard headScan == nil, let latest = scans.last,
              let index = latest.sortedCaptures.firstIndex(where: { $0.angle == .front }),
              let photo = latest.uiImage(at: index) else { return }
        frontPhoto = await FaceAligner.shared.aligned(photo, key: "\(latest.id)-front")?.image ?? photo
    }
}

// MARK: - Zone bar

/// One face zone as a bar: its name, an ink bar as long as its share, and the count. The bar grows in once
/// (Reduce Motion: shown at once). At the largest text sizes the name sits above the bar.
struct ZoneBar: View {
    let zone: FaceZone
    let count: Int
    /// 0…1: how long the bar is.
    let fraction: Double
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var grown = false
    @ScaledMetric(relativeTo: .callout) private var nameWidth: CGFloat = 96
    @ScaledMetric(relativeTo: .callout) private var countWidth: CGFloat = 24

    private enum Metrics {
        static let barHeight: CGFloat = 14
        static let trackOpacity = 0.6
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    name
                    HStack(spacing: Spacing.sm) { bar; number }
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    name.frame(width: nameWidth, alignment: .leading)
                    bar
                    number
                }
            }
        }
        .foregroundStyle(Color.ds.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(GuidanceCopy.zoneName(zone)))
        .accessibilityValue(Text(count, format: .number))
        .onAppear {
            withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation.delay(reduceMotion ? 0 : delay)) {
                grown = true
            }
        }
    }

    private var name: some View {
        Text(GuidanceCopy.zoneName(zone))
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }

    private var number: some View {
        Text(count, format: .number)
            .font(.system(.headline, design: .rounded).weight(.heavy).monospacedDigit())
            .frame(minWidth: countWidth, alignment: .trailing)
    }

    private var bar: some View {
        Capsule()
            .fill(Color.ds.surface.opacity(Metrics.trackOpacity))
            .frame(height: Metrics.barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let share = min(max(fraction, 0), 1)
                    Capsule()
                        .fill(Color.ds.ink)
                        .frame(width: share > 0 ? max(proxy.size.width * share, Metrics.barHeight) : 0)
                        .scaleEffect(x: grown ? 1 : 0, anchor: .leading)
                }
            }
    }
}

/// Glows at the zone anchors on a flat, eye-aligned front photo (no 3D head on this device, e.g. iPhone Duo).
private struct FlatHeat: View {
    let heat: [FaceZone: Double]

    /// The aligned frame's face box (`FaceAlignment.faceWidthRatio` wide, centred).
    private static let faceShare = 0.56
    private static let faceAspect = 1.3
    private static let glow: CGFloat = 100
    private static let smallestGlow = 0.4
    private static let faintestGlow = 0.3

    var body: some View {
        GeometryReader { proxy in
            let faceWidth = proxy.size.width * Self.faceShare
            let faceHeight = faceWidth * Self.faceAspect
            let origin = CGPoint(x: (proxy.size.width - faceWidth) / 2, y: proxy.size.height * 0.5 - faceHeight / 2)
            ForEach(FaceZone.allCases, id: \.self) { zone in
                let level = heat[zone] ?? 0
                let anchor = ZoneHeat.anchor(zone)
                Circle()
                    .fill(RadialGradient(colors: [Color.ds.signal.opacity(0.8), .clear], center: .center,
                                         startRadius: 0, endRadius: Self.glow / 2))
                    .frame(width: Self.glow, height: Self.glow)
                    .scaleEffect(Self.smallestGlow + level)
                    .opacity(level > 0 ? Self.faintestGlow + (1 - Self.faintestGlow) * level : 0)
                    .position(x: origin.x + anchor.x * faceWidth, y: origin.y + anchor.y * faceHeight)
                    .blendMode(.plusLighter)
                    .animation(.smooth, value: level)
            }
        }
        .allowsHitTesting(false)
    }
}
