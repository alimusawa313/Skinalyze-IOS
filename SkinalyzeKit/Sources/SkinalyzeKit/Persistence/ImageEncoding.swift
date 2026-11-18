import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Platform-independent (ImageIO) image re-encoding used when migrating and saving scans.
public enum ImageEncoding {
    /// Quality for stored scan photos: visually lossless for skin detail, far smaller than the old quality-1.0 JPEGs.
    public static let storageQuality = 0.8

    /// Re-encodes image data as HEIC (falling back to JPEG) at `storageQuality`, **preserving metadata such as EXIF
    /// orientation** (legacy photos are stored rotated + tagged). Returns `nil` if the input isn't an image.
    public static func compressedData(fromImageData data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
        else { return nil }
        return reencode(source, as: .heic) ?? reencode(source, as: .jpeg)
    }

    /// EXIF orientation (1…8) of encoded image data, or `nil` when untagged/unreadable.
    public static func orientation(of data: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        return properties[kCGImagePropertyOrientation] as? Int
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

    /// Copies image 0 of `source` (pixels + metadata) into a new container of `type` at `storageQuality`.
    private static func reencode(_ source: CGImageSource, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: storageQuality] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, source, 0, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
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
