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

    private enum Metrics {
        static let pinTarget: CGFloat = 44
        static let pinPressedScale: CGFloat = 0.8
        static let hiddenPinScale: CGFloat = 0.2
    }

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
                .frame(width: Metrics.pinTarget, height: Metrics.pinTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.bouncy(Metrics.pinPressedScale))
        .scaleEffect(revealed ? 1 : Metrics.hiddenPinScale)
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

    /// A white dot with the spot's colour inside and a navy rim, so it reads on any skin tone without a shadow.
    private struct Pin: View {
        let type: LesionType?
        let isSelected: Bool

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private enum Metrics {
            static let outer: CGFloat = 18
            static let rim: CGFloat = 1.5
            static let inner: CGFloat = 10
            static let selectedScale: CGFloat = 1.6
        }

        var body: some View {
            ZStack {
                Circle().fill(Color.ds.surface).frame(width: Metrics.outer, height: Metrics.outer)
                Circle().strokeBorder(Color.ds.ink, lineWidth: Metrics.rim).frame(width: Metrics.outer, height: Metrics.outer)
                Circle().fill(type?.isMark == true ? Color.ds.caution : Color.ds.signal)
                    .frame(width: Metrics.inner, height: Metrics.inner)
            }
            .scaleEffect(isSelected ? Metrics.selectedScale : 1)
            .animation(MotionToken.expressive.resolved(reduceMotion: reduceMotion).animation, value: isSelected)
        }
    }
}

/// What a tapped spot is: glyph, name, face zone and a plain-language note (tracking language — no diagnosis).
struct SpotDetail: View {
    let type: LesionType?
    let zone: FaceZone?
    var follow: (() -> Void)?

    private enum Metrics {
        static let width: CGFloat = 260
    }

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
                    .foregroundStyle(Color.ds.ink)
            }
            if let zone {
                Label(GuidanceCopy.zoneName(zone), systemImage: "face.smiling")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            if let type {
                Text(LesionGlyph.explanation(for: type))
                    .font(.ds.footnote)
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let follow {
                Button(action: follow) {
                    Label("See this area over time", systemImage: "clock.arrow.circlepath")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                }
                .buttonStyle(.chunky(.plain, fullWidth: false))
                .padding(.top, Spacing.xxs)
                .accessibilityIdentifier("followArea")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: Metrics.width, alignment: .leading)
    }
}
