import CoreGraphics

/// Conversions between a detector's region-normalised boxes and full-image normalised boxes.
///
/// Boxes (`ImageRect`) use the Vision convention: normalised 0…1, origin bottom-left. Regions (`CGRect`) are
/// **pixel** rectangles in the full image with a **top-left** origin, the way `CGImage.cropping(to:)` takes them.
public enum ImageSpace {
    /// Maps a box normalised to `region` to full-image normalised coordinates.
    public static func toImage(_ box: ImageRect, region: CGRect, imageSize: CGSize) -> ImageRect {
        let regionBottom = imageSize.height - region.maxY // region's bottom edge, measured from the image bottom
        return ImageRect(
            x: (region.minX + box.x * region.width) / imageSize.width,
            y: (regionBottom + box.y * region.height) / imageSize.height,
            width: box.width * region.width / imageSize.width,
            height: box.height * region.height / imageSize.height
        )
    }

    /// Inverse of `toImage`: a full-image normalised box expressed relative to `region`.
    public static func toRegion(_ box: ImageRect, region: CGRect, imageSize: CGSize) -> ImageRect {
        let regionBottom = imageSize.height - region.maxY
        return ImageRect(
            x: (box.x * imageSize.width - region.minX) / region.width,
            y: (box.y * imageSize.height - regionBottom) / region.height,
            width: box.width * imageSize.width / region.width,
            height: box.height * imageSize.height / region.height
        )
    }

    /// A top-left-origin pixel rectangle as a full-image normalised box.
    public static func normalized(_ pixelRect: CGRect, imageSize: CGSize) -> ImageRect {
        toImage(
            ImageRect(x: 0, y: 0, width: 1, height: 1),
            region: pixelRect,
            imageSize: imageSize
        )
    }
}

/// The rule for "these two boxes are the same spot" (ML-PLAN M0.3). Used by the benchmark to match predictions to
/// labels and by multi-frame agreement. IoU alone is too harsh for 3-pixel boxes, so a close centre also counts.
public enum DetectionMatching {
    /// A candidate is the same spot if its centre is within this share of the reference's larger side…
    public static let centerDistanceFactor = 0.5
    /// …or if the boxes overlap at least this much.
    public static let minIoU = 0.3

    public static func isSameSpot(_ candidate: ImageRect, as reference: ImageRect, imageSize: CGSize) -> Bool {
        if DetectionFilter.iou(candidate, reference) >= minIoU { return true }
        let dx = (candidate.center.x - reference.center.x) * imageSize.width
        let dy = (candidate.center.y - reference.center.y) * imageSize.height
        let largerSide = max(reference.width * imageSize.width, reference.height * imageSize.height)
        return (dx * dx + dy * dy).squareRoot() <= centerDistanceFactor * largerSide
    }
}
