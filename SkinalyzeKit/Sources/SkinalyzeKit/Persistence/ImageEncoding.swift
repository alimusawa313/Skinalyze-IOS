import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Platform-independent (ImageIO) image re-encoding used when migrating and saving scans.
public enum ImageEncoding {
    /// Quality for stored scan photos: visually lossless for skin detail, far smaller than the old quality-1.0 JPEGs.
    public static let storageQuality = 0.8

    /// Re-encodes image data as HEIC (falling back to JPEG) at `storageQuality`. Returns `nil` if the input isn't an image.
    public static func compressedData(fromImageData data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return encode(image, as: .heic) ?? encode(image, as: .jpeg)
    }

    /// Encodes a `CGImage` for storage (HEIC, falling back to JPEG).
    public static func compressedData(from image: CGImage) -> Data? {
        encode(image, as: .heic) ?? encode(image, as: .jpeg)
    }

    /// Pixel dimensions of encoded image data, or `nil` if unreadable.
    public static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: storageQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
