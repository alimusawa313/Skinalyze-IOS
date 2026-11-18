import UIKit
import SkinalyzeKit

/// Draws stored detections as boxes on a transparent overlay the size of the photo.
/// Replaces re-running the ML model just to redraw boxes (which made saved results change over time).
enum DetectionOverlayRenderer {
    private static let lineWidth: CGFloat = 4
    private static let alpha: CGFloat = 0.7

    // Same colors the app has always used, so saved scans look unchanged. Replaced by design tokens in Phase 2.
    private static func color(for type: LesionType) -> UIColor {
        switch type {
        case .blackhead: .cyan
        case .darkSpot: .blue
        case .nodule: .red
        case .papule: .orange
        case .pustule: .green
        case .whitehead: .gray
        }
    }

    static func overlay(size: CGSize, detections: [StoredDetection]) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setAlpha(alpha)
            cg.setLineWidth(lineWidth)
            for detection in detections {
                guard let type = detection.lesionType else { continue }
                cg.setStrokeColor(color(for: type).cgColor)
                cg.stroke(rect(for: detection.box, in: size))
            }
        }
    }

    /// Vision boxes are normalized with a bottom-left origin; UIKit drawing uses top-left.
    static func rect(for box: NormalizedRect, in size: CGSize) -> CGRect {
        CGRect(
            x: box.x * size.width,
            y: (1 - box.y - box.height) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}
