import Testing
import UIKit
@testable import Skinalyze

/// "Hide my face" must never leak the photo: the silhouette keeps only the sticker's outline shape.
@Suite("Share silhouette")
struct ShareSilhouetteTests {
    private static let side = 64

    /// A stand-in for a sticker: a disc full of varied, non-white colours on a clear canvas.
    private func colourfulDisc() -> UIImage {
        let size = CGSize(width: Self.side, height: Self.side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.addEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8))
            context.cgContext.clip()
            for row in 0..<Self.side {
                UIColor(hue: CGFloat(row) / CGFloat(Self.side), saturation: 0.9, brightness: 0.6, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: row, width: Self.side, height: 1))
            }
        }
    }

    private func pixels(_ image: UIImage) -> [UInt8] {
        let width = Self.side, height = Self.side
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    @Test("Every visible pixel is the flat fill colour — nothing from the photo survives")
    func containsNoPhotoPixels() throws {
        let silhouette = try #require(ShareSilhouette.make(from: colourfulDisc()))
        let data = pixels(silhouette)
        var visible = 0
        for index in stride(from: 0, to: data.count, by: 4) where data[index + 3] > 0 {
            visible += 1
            // Premultiplied white: red, green and blue all equal alpha.
            #expect(data[index] == data[index + 3] && data[index + 1] == data[index + 3] && data[index + 2] == data[index + 3])
        }
        #expect(visible > 0)
    }

    @Test("The shape is kept: solid in the middle, clear in the corners")
    func keepsTheShape() throws {
        let silhouette = try #require(ShareSilhouette.make(from: colourfulDisc()))
        let data = pixels(silhouette)
        let centre = (Self.side / 2 * Self.side + Self.side / 2) * 4
        #expect(data[centre + 3] == 255)
        #expect(data[3] == 0)
    }

    @Test("Hiding the face swaps the sticker for the silhouette, so the card never receives the photo")
    func hidingReplacesTheSticker() {
        let art = StickerArt(subject: colourfulDisc(), backing: colourfulDisc())
        guard case .silhouette = SharePortrait.make(from: art, hidesFace: true) else {
            Issue.record("Expected a silhouette")
            return
        }
        guard case .sticker = SharePortrait.make(from: art, hidesFace: false) else {
            Issue.record("Expected the sticker")
            return
        }
    }
}
