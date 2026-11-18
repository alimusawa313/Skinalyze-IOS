import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Fixtures {
    static let imageWidth = 8
    static let imageHeight = 6

    /// A real JPEG generated with CoreGraphics, base64-encoded the same way the legacy app stored images.
    static let tinyJPEGBase64: String = makeJPEG().base64EncodedString()

    private static func makeJPEG() -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: imageWidth, height: imageHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { preconditionFailure("fixture: CGContext") }
        context.setFillColor(CGColor(red: 0.8, green: 0.6, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard let image = context.makeImage() else { preconditionFailure("fixture: makeImage") }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { preconditionFailure("fixture: destination") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { preconditionFailure("fixture: finalize") }
        return data as Data
    }
}
