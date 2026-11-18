import CoreImage
import UIKit
import Vision
import SkinalyzeKit

/// Decides which parts of the front photo belong in the 3D scan: the person (Vision's foreground mask — head, ears,
/// hair, whatever they wear) minus everything below the jaw line (neck, shoulders). It only ever *removes* samples —
/// the wall behind and shoulder flaps — and never alters or fades the face. Verified on real scans.
enum FaceMaskMaker {
    private static let workingMaxSide: CGFloat = 1024
    /// Mask grid handed to the mesh builder.
    private static let maskWidth = 256
    /// The jaw line is widened by this (about the face centre) and lowered a little, so cheeks and jaw stay whole.
    private static let jawWiden: CGFloat = 1.2
    private static let jawDropRatio: CGFloat = 0.06

    /// nil when neither a person nor a face can be found (the scan is then built untrimmed).
    static func trimMask(from image: UIImage) -> FaceMask? {
        guard let upright = upright(image) else { return nil }
        let size = CGSize(width: upright.width, height: upright.height)
        let handler = VNImageRequestHandler(cgImage: upright)
        let personRequest = VNGenerateForegroundInstanceMaskRequest()
        let faceRequest = VNDetectFaceLandmarksRequest()
        try? handler.perform([personRequest, faceRequest])

        var person: CGImage?
        if let observation = personRequest.results?.first,
           let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler) {
            person = CIContext().createCGImage(CIImage(cvPixelBuffer: buffer), from: CGRect(origin: .zero, size: size))
        }
        let jaw = jawLine(faceRequest.results, size: size)
        guard person != nil || jaw != nil else { return nil }

        let width = maskWidth, height = max(1, Int(CGFloat(maskWidth) * size.height / size.width))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data else { return nil }
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        if let person {
            context.draw(person, in: frame)
        } else {
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(frame)
        }
        if let jaw {
            // Top-left coordinates, scaled to the grid: black out everything below the jaw curve.
            let scale = CGFloat(width) / size.width
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            context.setFillColor(gray: 0, alpha: 1)
            context.move(to: CGPoint(x: 0, y: jaw[0].y))
            jaw.forEach { context.addLine(to: $0) }
            context.addLine(to: CGPoint(x: size.width, y: jaw[jaw.count - 1].y))
            context.addLine(to: CGPoint(x: size.width, y: size.height))
            context.addLine(to: CGPoint(x: 0, y: size.height))
            context.closePath()
            context.fillPath()
        }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        return FaceMask(width: width, height: height, alpha: Array(UnsafeBufferPointer(start: bytes, count: width * height)))
    }

    /// Vision's jaw contour (top-left pixels, left→right), widened and lowered slightly.
    private static func jawLine(_ faces: [VNFaceObservation]?, size: CGSize) -> [CGPoint]? {
        guard let face = faces?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let region = face.landmarks?.faceContour else { return nil }
        var contour = region.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        guard contour.count >= 5, let first = contour.first, let last = contour.last,
              let chinY = contour.map(\.y).max(), let topY = contour.map(\.y).min() else { return nil }
        if first.x > last.x { contour.reverse() }
        let centreX = contour.map(\.x).reduce(0, +) / CGFloat(contour.count)
        let drop = (chinY - topY) * jawDropRatio
        return contour.map { CGPoint(x: centreX + ($0.x - centreX) * jawWiden, y: $0.y + drop) }
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
