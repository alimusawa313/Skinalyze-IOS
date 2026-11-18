import CoreImage
import UIKit
import Vision
import SkinalyzeKit

/// Cuts the face itself out of the front photo for the 3D scan — jaw line from Vision's face contour, forehead as an
/// arc above the brows — with a soft (feathered) edge. Hair, headphones, ears, neck and shoulders fall outside: a
/// front-only depth scan can't texture them, so they'd only smear.
enum FaceMaskMaker {
    /// Texture size cap (pixels, long side).
    private static let textureMaxSide: CGFloat = 1600
    /// Mask grid handed to the mesh builder.
    private static let maskWidth = 256
    /// Forehead height above the brows, as a fraction of brow-to-chin.
    private static let foreheadRatio: CGFloat = 0.45
    /// The cut is pulled in to this fraction of the face width so its edge sits on solid cheek depth (the outer cheek
    /// next to ears/hair often has none, which showed as notches).
    private static let widthRatio: CGFloat = 0.9
    /// Feather width, as a fraction of the image width.
    private static let featherRatio: CGFloat = 0.012

    /// The feathered mask (photo-aligned) and the photo texture with that alpha (PNG), or nil if no face landmarks.
    static func make(from image: UIImage) -> (mask: FaceMask, texture: Data)? {
        guard let upright = upright(image), let outline = faceOutline(upright) else { return nil }
        let size = CGSize(width: upright.width, height: upright.height)
        guard let hardMask = fill(outline, size: size) else { return nil }
        let feathered = CIImage(cgImage: hardMask)
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": size.width * featherRatio])
            .cropped(to: CGRect(origin: .zero, size: size))
        let context = CIContext()
        let photo = CIImage(cgImage: upright)
        let cutout = photo.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: feathered,
        ])
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let texture = context.pngRepresentation(of: cutout, format: .RGBA8, colorSpace: colorSpace),
              let featheredCG = context.createCGImage(feathered, from: feathered.extent),
              let mask = downsampledMask(featheredCG, aspect: size.height / size.width) else { return nil }
        return (mask, texture)
    }

    // MARK: - Steps

    /// Face outline in top-left pixel coordinates: jaw contour plus a forehead arc.
    private static func faceOutline(_ image: CGImage) -> [CGPoint]? {
        let request = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let landmarks = face.landmarks else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        func points(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            (region?.pointsInImage(imageSize: size) ?? []).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        }
        var contour = points(landmarks.faceContour)
        let brows = points(landmarks.leftEyebrow) + points(landmarks.rightEyebrow)
        guard contour.count >= 5, let browY = brows.map(\.y).min(), let chinY = contour.map(\.y).max(),
              let first = contour.first, let last = contour.last else { return nil }
        if first.x > last.x { contour.reverse() }
        guard let left = contour.first, let right = contour.last else { return nil }

        // Forehead: half-ellipse from the right end of the jaw contour over the brows to the left end.
        let foreheadTop = browY - (chinY - browY) * foreheadRatio
        let centre = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let radiusX = (right.x - left.x) / 2
        let radiusY = max(centre.y - foreheadTop, 1)
        let arc = (1..<24).map { step -> CGPoint in
            let angle = CGFloat(step) / 24 * .pi
            return CGPoint(x: centre.x + radiusX * cos(angle), y: centre.y - radiusY * sin(angle))
        }
        let outline = contour + arc
        let centreX = outline.map(\.x).reduce(0, +) / CGFloat(outline.count)
        return outline.map { CGPoint(x: centreX + ($0.x - centreX) * widthRatio, y: $0.y) }
    }

    /// The outline filled white on black, top-left origin.
    private static func fill(_ outline: [CGPoint], size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let path = UIBezierPath()
            path.move(to: outline[0])
            outline.dropFirst().forEach(path.addLine(to:))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }.cgImage
    }

    /// Small 8-bit grid of the feathered mask for the mesh builder (row 0 = top).
    private static func downsampledMask(_ image: CGImage, aspect: CGFloat) -> FaceMask? {
        let width = maskWidth, height = max(1, Int(CGFloat(maskWidth) * aspect))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        return FaceMask(width: width, height: height, alpha: Array(UnsafeBufferPointer(start: bytes, count: width * height)))
    }

    private static func upright(_ image: UIImage) -> CGImage? {
        let scale = min(1, textureMaxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
