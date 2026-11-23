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
/// a spot was marked.
struct AreaTimelineView: View {
    let follow: AreaFollow

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
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

    private static let tile: CGFloat = 220

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("The same patch of skin in each scan, lined up by your eyes. Rings show where a spot was marked.")
                        .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
                    if follow.angle != .front {
                        Label("Side photos line up less exactly than the front.", systemImage: "info.circle")
                            .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: Self.tile)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: Spacing.sm) {
                                ForEach(frames) { tile($0) }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .defaultScrollAnchor(.trailing)
                    }
                    Text("Detection is not perfect: a mark can be missed in one scan and found in the next. Use your own eyes.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkTertiary)
                }
                .padding(Spacing.lg)
            }
            .dsCanvas()
            .navigationTitle("This area over time")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .task { await load() }
    }

    private func tile(_ frame: Frame) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(uiImage: frame.image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.tile, height: Self.tile)
                .overlay {
                    GeometryReader { proxy in
                        ForEach(Array(frame.marks.enumerated()), id: \.offset) { _, mark in
                            Circle().strokeBorder(.white, lineWidth: 2)
                                .background(Circle().strokeBorder(Color.ds.signal, lineWidth: 4))
                                .frame(width: 30, height: 30)
                                .position(x: mark.x * proxy.size.width, y: mark.y * proxy.size.height)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .strokeBorder(frame.isTapped ? Color.ds.signal : .clear, lineWidth: 3)
                }
            Text(frame.date, format: .dateTime.day().month().year()).font(.ds.footnote.weight(.semibold))
            Text(frame.marks.isEmpty ? "Nothing marked here" : "\(frame.marks.count) marked here")
                .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
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

/// Spots marked per face zone, on the latest 3D head (or the front photo), scrubbable through every scan.
struct ZoneMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    /// A scan deleted while this is open (here, or on another device via iCloud) must never be read.
    private var scans: [ScanSession] { allScans.filter { !$0.isDeleted && $0.modelContext != nil } }
    @State private var position: Double = 0
    @State private var frontPhoto: UIImage?

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
                        scrubber
                        zoneList
                        Text("Shows how many spots were marked in each area, not what they are.")
                            .font(.ds.footnote).foregroundStyle(Color.ds.inkTertiary)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 700)
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
                .frame(height: 380)
                .accessibilityLabel(Text("Your 3D scan with the busier areas glowing"))
        } else if let frontPhoto {
            Image(uiImage: frontPhoto).resizable().scaledToFit()
                .overlay { FlatHeat(heat: heat) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .frame(maxHeight: 420)
                .frame(maxWidth: .infinity)
        }
    }

    private var scrubber: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if scans.indices.contains(selected) {
                Text(scans[selected].createdAt, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.ds.headline)
                    .contentTransition(.numericText())
            }
            if scans.count > 1 {
                Slider(value: $position, in: 0...Double(scans.count - 1), step: 1) {
                    Text("Scan date")
                } minimumValueLabel: {
                    Image(systemName: "clock.arrow.circlepath")
                } maximumValueLabel: {
                    Image(systemName: "clock")
                }
                .tint(Color.ds.signal)
                .accessibilityValue(scans.indices.contains(selected)
                                    ? Text(scans[selected].createdAt, format: .dateTime.day().month().year()) : Text(verbatim: ""))
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
    }

    private var zoneList: some View {
        let heat = levels.indices.contains(selected) ? levels[selected] : [:]
        return VStack(spacing: Spacing.sm) {
            ForEach(FaceZone.allCases, id: \.self) { zone in
                HStack {
                    Text(GuidanceCopy.zoneName(zone)).font(.ds.callout)
                    Spacer()
                    Capsule().fill(Color.ds.hairline)
                        .frame(width: 120, height: 8)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.ds.signal).frame(width: 120 * (heat[zone] ?? 0), height: 8)
                        }
                    Text(verbatim: scans.indices.contains(selected) ? "\(scans[selected].zoneIndex(zone))" : "0")
                        .font(.ds.callout.monospacedDigit()).frame(width: 32, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .dsCard()
        .animation(.smooth, value: selected)
    }

    private func loadFrontPhoto() async {
        guard headScan == nil, let latest = scans.last,
              let index = latest.sortedCaptures.firstIndex(where: { $0.angle == .front }),
              let photo = latest.uiImage(at: index) else { return }
        frontPhoto = await FaceAligner.shared.aligned(photo, key: "\(latest.id)-front")?.image ?? photo
    }
}

/// Glows at the zone anchors on a flat, eye-aligned front photo (no 3D head on this device, e.g. iPhone Duo).
private struct FlatHeat: View {
    let heat: [FaceZone: Double]

    /// The aligned frame's face box (`FaceAlignment.faceWidthRatio` wide, centred).
    private static let faceShare = 0.56

    var body: some View {
        GeometryReader { proxy in
            let faceWidth = proxy.size.width * Self.faceShare
            let faceHeight = faceWidth * 1.3
            let origin = CGPoint(x: (proxy.size.width - faceWidth) / 2, y: proxy.size.height * 0.5 - faceHeight / 2)
            ForEach(FaceZone.allCases, id: \.self) { zone in
                let level = heat[zone] ?? 0
                let anchor = ZoneHeat.anchor(zone)
                Circle()
                    .fill(RadialGradient(colors: [Color.ds.signal.opacity(0.8), .clear], center: .center,
                                         startRadius: 0, endRadius: 50))
                    .frame(width: 100, height: 100)
                    .scaleEffect(0.4 + level)
                    .opacity(level > 0 ? 0.3 + 0.7 * level : 0)
                    .position(x: origin.x + anchor.x * faceWidth, y: origin.y + anchor.y * faceHeight)
                    .blendMode(.plusLighter)
                    .animation(.smooth, value: level)
            }
        }
        .allowsHitTesting(false)
    }
}
