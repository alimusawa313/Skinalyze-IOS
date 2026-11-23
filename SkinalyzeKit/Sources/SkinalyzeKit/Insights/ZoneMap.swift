import CoreGraphics
import Foundation

/// Zone activity over time for the heat map on the head. Levels share one scale across all scans, so a brighter zone
/// on one date really had more marked than a dimmer one on another. Describes what was marked, nothing more.
public enum ZoneHeat {
    /// Per scan (oldest first): each zone's share of the busiest zone-and-scan, 0…1.
    public static func levels(_ scans: [[FaceZone: Int]]) -> [[FaceZone: Double]] {
        let peak = scans.flatMap(\.values).max() ?? 0
        return scans.map { scan in
            Dictionary(uniqueKeysWithValues: FaceZone.allCases.map { zone in
                (zone, peak > 0 ? Double(scan[zone] ?? 0) / Double(peak) : 0)
            })
        }
    }

    /// Where each zone sits on a face seen from the front, as shares of the face's width and height (top-left origin).
    /// Right and left are the person's own sides, which appear on the viewer's left and right.
    public static func anchor(_ zone: FaceZone) -> CGPoint {
        switch zone {
        case .forehead: CGPoint(x: 0.5, y: 0.2)
        case .nose: CGPoint(x: 0.5, y: 0.47)
        case .rightCheek: CGPoint(x: 0.27, y: 0.52)
        case .leftCheek: CGPoint(x: 0.73, y: 0.52)
        case .rightJaw: CGPoint(x: 0.3, y: 0.74)
        case .leftJaw: CGPoint(x: 0.7, y: 0.74)
        case .chin: CGPoint(x: 0.5, y: 0.86)
        }
    }
}

/// "This area over time": the same patch cut from each scan's eye-aligned photo.
public enum AreaCrop {
    /// Side of the square crop, as a share of the aligned frame's width (about a cheek's worth of skin).
    public static let sideShare: CGFloat = 0.34

    public static func rect(around point: CGPoint, in frame: CGSize) -> CGRect {
        let side = frame.width * sideShare
        let x = min(max(point.x - side / 2, 0), frame.width - side)
        let y = min(max(point.y - side / 2, 0), frame.height - side)
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// Spots inside the crop, as shares of the crop (for drawing rings on it).
    public static func marks(_ points: [CGPoint], in crop: CGRect) -> [CGPoint] {
        points.filter(crop.contains).map {
            CGPoint(x: ($0.x - crop.minX) / crop.width, y: ($0.y - crop.minY) / crop.height)
        }
    }
}
