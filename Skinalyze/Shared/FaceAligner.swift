import SwiftUI
import UIKit
import Vision
import SkinalyzeKit

/// A photo re-rendered so the face sits in the canonical spot (eyes on fixed points), plus the transform used — so
/// detection pins can be moved with it.
struct AlignedPhoto: @unchecked Sendable { // UIImage is immutable once made.
    let image: UIImage
    /// Upright source pixels (top-left) → output pixels.
    let transform: CGAffineTransform
    let sourceSize: CGSize

    static let outputSize = CGSize(width: 900, height: 1200)

    /// Detection centre (Vision-normalized, bottom-left, in the source photo) → normalized top-left in the output.
    func map(_ visionPoint: CGPoint) -> CGPoint {
        let pixel = CGPoint(x: visionPoint.x * sourceSize.width, y: (1 - visionPoint.y) * sourceSize.height)
        let out = pixel.applying(transform)
        return CGPoint(x: out.x / Self.outputSize.width, y: out.y / Self.outputSize.height)
    }
}

/// Registers scan photos by the eyes (Vision landmarks; face box fallback) for Compare. Cached per scan + angle.
actor FaceAligner {
    static let shared = FaceAligner()
    private static let workingMaxSide: CGFloat = 1600

    private final class Box {
        let photo: AlignedPhoto?
        init(_ photo: AlignedPhoto?) { self.photo = photo }
    }

    private let cache = NSCache<NSString, Box>()

    func aligned(_ image: UIImage, key: String) -> AlignedPhoto? {
        if let cached = cache.object(forKey: key as NSString) { return cached.photo }
        let result = align(image)
        cache.setObject(Box(result), forKey: key as NSString)
        return result
    }

    private func align(_ image: UIImage) -> AlignedPhoto? {
        guard let upright = Self.upright(image) else { return nil }
        let size = CGSize(width: upright.width, height: upright.height)
        let output = AlignedPhoto.outputSize
        let transform: CGAffineTransform
        if let face = Self.largestFace(upright) {
            if let eyes = Self.eyes(face, imageSize: size) {
                transform = FaceAlignment.transform(eyes: eyes, output: output)
            } else {
                let box = face.boundingBox
                let rect = CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                                  width: box.width * size.width, height: box.height * size.height)
                transform = FaceAlignment.transform(faceBox: rect, output: output)
            }
        } else {
            // No face found: plain aspect-fill so the pair still lines up frame-to-frame.
            let scale = max(output.width / size.width, output.height / size.height)
            transform = CGAffineTransform(translationX: (output.width - size.width * scale) / 2,
                                          y: (output.height - size.height * scale) / 2).scaledBy(x: scale, y: scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: output, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: output))
            context.cgContext.concatenate(transform)
            UIImage(cgImage: upright).draw(at: .zero)
        }
        return AlignedPhoto(image: rendered, transform: transform, sourceSize: size)
    }

    private static func largestFace(_ image: CGImage) -> VNFaceObservation? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([request])
        return request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
    }

    /// Pupil (or eye-contour centre) positions in top-left pixel coordinates.
    private static func eyes(_ face: VNFaceObservation, imageSize: CGSize) -> (CGPoint, CGPoint)? {
        guard let landmarks = face.landmarks else { return nil }
        func centre(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let points = region?.pointsInImage(imageSize: imageSize), !points.isEmpty else { return nil }
            let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let mean = CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
            return CGPoint(x: mean.x, y: imageSize.height - mean.y) // Vision is bottom-left
        }
        guard let left = centre(landmarks.leftPupil) ?? centre(landmarks.leftEye),
              let right = centre(landmarks.rightPupil) ?? centre(landmarks.rightEye) else { return nil }
        return (left, right)
    }

    private static func upright(_ image: UIImage) -> CGImage? {
        let scale = min(1, workingMaxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
