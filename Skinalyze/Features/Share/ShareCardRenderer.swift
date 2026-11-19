import SwiftUI
import UIKit
import SkinalyzeKit

/// The flat shape used when the user hides their face: the sticker's outline filled with one colour.
/// It is built from the sticker's backing (already a plain shape) and keeps only its transparency.
enum ShareSilhouette {
    static let fill = UIColor.white

    static func make(from backing: UIImage) -> UIImage? {
        guard let shape = backing.cgImage else { return nil }
        let size = CGSize(width: shape.width, height: shape.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let frame = CGRect(origin: .zero, size: size)
            fill.setFill()
            context.fill(frame)
            // Keep the fill only where the shape is opaque; no colour is taken from the shape.
            UIImage(cgImage: shape).draw(in: frame, blendMode: .destinationIn, alpha: 1)
        }
    }
}

/// What stands in for the person on a skin card.
enum SharePortrait: @unchecked Sendable { // UIImage is immutable once made.
    case sticker(StickerArt)
    case silhouette(UIImage)
    case none

    /// With `hidesFace`, the sticker is dropped here — the card view never receives the photo.
    static func make(from art: StickerArt?, hidesFace: Bool) -> SharePortrait {
        guard let art else { return .none }
        guard hidesFace else { return .sticker(art) }
        return ShareSilhouette.make(from: art.backing).map(SharePortrait.silhouette) ?? .none
    }
}

/// One pipeline for every export: a card view → an image at the format's fixed pixel size → a file to hand to the
/// system share sheet. Nothing is uploaded by the app.
@MainActor
enum ShareCardRenderer {
    private static let folderName = "ShareCards"

    static func image(of content: ShareCardContent, format: ShareCardFormat, showsWatermark: Bool = true) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content, format: format, showsWatermark: showsWatermark))
        renderer.scale = ShareCardFormat.renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Writes the image where the share sheet can read it. Earlier exports with the same name are replaced.
    static func write(_ image: UIImage, name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        let url = folder.appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
