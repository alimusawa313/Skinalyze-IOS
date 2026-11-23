import SwiftUI
import SkinalyzeKit

/// A scan photo with its detections drawn as pins (never re-analyzed). Pins pop in with a stagger unless Reduce Motion,
/// and each pin is a button: tap it for what it is and where — a small pop-up, with a bounce.
struct ScanPhotoView: View {
    let image: UIImage
    let detections: [StoredDetection]
    /// Optional remap of a detection centre (Vision-normalized, bottom-left) to a normalized top-left point in the
    /// displayed image — used by Compare, where photos are re-aligned by the eyes.
    var mapPoint: ((CGPoint) -> CGPoint)?
    /// When set, a tapped spot's pop-up offers "See this area over time".
    var onFollow: ((StoredDetection) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var selectedID: UUID?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                        pin(detection, index: index)
                            .position(position(of: detection.box, in: proxy.size))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .onAppear { revealed = true }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilitySummary)
    }

    private func pin(_ detection: StoredDetection, index: Int) -> some View {
        let isSelected = selectedID == detection.id
        return Button {
            selectedID = detection.id
        } label: {
            Pin(type: detection.lesionType, isSelected: isSelected)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.bouncy(0.8))
        .scaleEffect(revealed ? 1 : 0.2)
        .opacity(revealed ? 1 : 0)
        .animation(MotionToken.expressive.resolved(reduceMotion: reduceMotion).animation
            .delay(reduceMotion ? 0 : MotionToken.stagger(index)), value: revealed)
        .popover(isPresented: Binding(get: { isSelected }, set: { if !$0 { selectedID = nil } })) {
            SpotDetail(type: detection.lesionType, zone: detection.zone, follow: onFollow.map { follow in
                {
                    selectedID = nil
                    follow(detection)
                }
            })
            .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(SpotDetail.label(type: detection.lesionType, zone: detection.zone))
        .accessibilityHint("Shows what this spot is")
        .accessibilityIdentifier("spotPin")
    }

    private func position(of box: ImageRect, in size: CGSize) -> CGPoint {
        let centre = CGPoint(x: box.center.x, y: box.center.y)
        // Vision boxes are bottom-left normalized; SwiftUI is top-left.
        let point = mapPoint?(centre) ?? CGPoint(x: centre.x, y: 1 - centre.y)
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private var accessibilitySummary: Text {
        detections.isEmpty
            ? Text("Scan photo. No spots marked.")
            : Text("Scan photo with \(detections.count) spots marked.")
    }

    private struct Pin: View {
        let type: LesionType?
        let isSelected: Bool

        var body: some View {
            ZStack {
                Circle().fill(.white).frame(width: 16, height: 16)
                Circle().fill(type?.isMark == true ? Color.ds.caution : Color.ds.signal).frame(width: 10, height: 10)
            }
            .scaleEffect(isSelected ? 1.6 : 1)
            .shadow(color: .black.opacity(0.3), radius: isSelected ? 4 : 1.5, y: 0.5)
            .animation(.spring(duration: 0.35, bounce: 0.5), value: isSelected)
        }
    }
}

/// What a tapped spot is: glyph, name, face zone and a plain-language note (tracking language — no diagnosis).
struct SpotDetail: View {
    let type: LesionType?
    let zone: FaceZone?
    var follow: (() -> Void)?

    static func label(type: LesionType?, zone: FaceZone?) -> String {
        let name = type.map(LesionGlyph.displayName(for:)) ?? String(localized: "Spot")
        guard let zone else { return name }
        return String(localized: "\(name) on \(GuidanceCopy.zoneName(zone).lowercased())")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: type.map(LesionGlyph.symbolName(for:)) ?? "circle.fill")
                    .foregroundStyle(type?.isMark == true ? Color.ds.caution : Color.ds.signal)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text(type.map(LesionGlyph.displayName(for:)) ?? String(localized: "Spot"))
                    .font(.system(.headline, design: .rounded).weight(.heavy))
            }
            if let zone {
                Label(GuidanceCopy.zoneName(zone), systemImage: "face.smiling")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let type {
                Text(LesionGlyph.explanation(for: type))
                    .font(.ds.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let follow {
                Button(action: follow) {
                    Label("See this area over time", systemImage: "clock.arrow.circlepath")
                        .font(.ds.footnote.weight(.semibold))
                }
                .accessibilityIdentifier("followArea")
            }
        }
        .padding(Spacing.md)
        .frame(width: 260, alignment: .leading)
    }
}
