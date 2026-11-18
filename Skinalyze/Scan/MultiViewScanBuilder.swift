import UIKit
import Vision
import SkinalyzeKit

/// Turns the three captures (photo + TrueDepth depth each) into one fused head mesh with real sides
/// (`MultiViewFusion`). Vision supplies the face box and feature landmarks that anchor how the head turned between
/// shots. Returns nil when the views can't be registered — the caller then keeps the front-only scan.
enum MultiViewScanBuilder {
    /// Photos are sampled at this size for landmarks and texture (long side, pixels).
    private static let photoMaxSide: CGFloat = 2048
    private static let textureQuality: CGFloat = 0.9

    struct Capture {
        let image: UIImage
        let depth: DepthMap
    }

    /// Runs off the main actor (Vision + fusion take a few hundred milliseconds).
    static func build(front: Capture, sides: [Capture]) -> (mesh: FaceMeshDraft, sideYawDegrees: [Float])? {
        guard let frontView = scanView(front) else { return nil }
        let sideViews = sides.compactMap(scanView)
        guard !sideViews.isEmpty, let result = MultiViewFusion.fuse(front: frontView, sides: sideViews),
              let texture = jpeg(result.texture) else { return nil }
        let mesh = FaceMeshDraft(vertices: result.vertices, indices: result.indices,
                                 textureCoordinates: result.textureCoordinates, projected: result.projected,
                                 texture: texture, mirroredProjection: false, projectedIsPhotoSpace: true)
        return (mesh, result.sideYawDegrees)
    }

    // MARK: - Per-view input

    private static func scanView(_ capture: Capture) -> ScanView? {
        guard let upright = upright(capture.image) else { return nil }
        let request = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: upright).perform([request])
        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let landmarks = face.landmarks else { return nil }
        // Feature regions only (the face contour follows the silhouette, which is a different physical line in every
        // view). Vision returns the same number of points per region in every photo, so indices line up across views.
        let regions = [landmarks.leftEye, landmarks.rightEye, landmarks.leftEyebrow, landmarks.rightEyebrow,
                       landmarks.nose, landmarks.noseCrest, landmarks.medianLine, landmarks.outerLips,
                       landmarks.innerLips, landmarks.leftPupil, landmarks.rightPupil]
        let unit = CGSize(width: 1, height: 1)
        let points = regions.flatMap { region in
            (region?.pointsInImage(imageSize: unit) ?? []).map { SIMD2(Float($0.x), Float(1 - $0.y)) } // top-left origin
        }
        guard points.count >= 20, let photo = pixels(upright) else { return nil }
        let box = face.boundingBox
        return ScanView(depth: capture.depth,
                        faceBox: ImageRect(x: box.minX, y: box.minY, width: box.width, height: box.height),
                        landmarks: points, photo: photo)
    }

    private static func upright(_ image: UIImage) -> CGImage? {
        let scale = min(1, photoMaxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private static func pixels(_ image: CGImage) -> PhotoPixels? {
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? PhotoPixels(width: width, height: height, rgba: rgba) : nil
    }

    private static func jpeg(_ texture: PhotoPixels) -> Data? {
        var rgba = texture.rgba
        let image: CGImage? = rgba.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: texture.width, height: texture.height, bitsPerComponent: 8,
                      bytesPerRow: texture.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage()
        }
        return image.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: textureQuality) }
    }
}
