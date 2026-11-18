import SwiftUI
import SkinalyzeKit

/// A scan photo with its detections drawn as pins (never re-analyzed). Pins pop in with a stagger unless Reduce Motion.
struct ScanPhotoView: View {
    let image: UIImage
    let detections: [StoredDetection]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                        Pin(type: detection.lesionType)
                            .position(position(of: detection.box, in: proxy.size))
                            .scaleEffect(revealed ? 1 : 0.2)
                            .opacity(revealed ? 1 : 0)
                            .animation(
                                MotionToken.expressive.resolved(reduceMotion: reduceMotion).animation
                                    .delay(reduceMotion ? 0 : MotionToken.stagger(index)),
                                value: revealed
                            )
                    }
                }
                .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .onAppear { revealed = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
    }

    /// Vision boxes are bottom-left normalized; SwiftUI is top-left.
    private func position(of box: ImageRect, in size: CGSize) -> CGPoint {
        CGPoint(x: box.center.x * size.width, y: (1 - box.center.y) * size.height)
    }

    private var accessibilitySummary: Text {
        detections.isEmpty
            ? Text("Scan photo. No spots marked.")
            : Text("Scan photo with \(detections.count) spots marked.")
    }

    private struct Pin: View {
        let type: LesionType?

        var body: some View {
            ZStack {
                Circle().fill(.white).frame(width: 14, height: 14)
                Circle().fill(type?.isMark == true ? Color.ds.caution : Color.ds.signal).frame(width: 9, height: 9)
            }
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
        }
    }
}
