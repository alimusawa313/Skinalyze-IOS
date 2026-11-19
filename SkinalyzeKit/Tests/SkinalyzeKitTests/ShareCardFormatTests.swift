import Testing
@testable import SkinalyzeKit

/// The fixed export sizes for share cards and the single watermark switch.
@Suite("Share card formats")
struct ShareCardFormatTests {
    @Test("Each format exports at its fixed pixel size", arguments: [
        (ShareCardFormat.story, 1080, 1920),
        (ShareCardFormat.portrait, 1080, 1350),
        (ShareCardFormat.square, 1080, 1080),
    ])
    func pixelSizes(format: ShareCardFormat, width: Int, height: Int) {
        #expect(format.pixelWidth == width)
        #expect(format.pixelHeight == height)
    }

    @Test("The layout size times the render scale is exactly the pixel size", arguments: ShareCardFormat.allCases)
    func layoutMatchesPixels(format: ShareCardFormat) {
        #expect(format.pointSize.width * ShareCardFormat.renderScale == Double(format.pixelWidth))
        #expect(format.pointSize.height * ShareCardFormat.renderScale == Double(format.pixelHeight))
    }

    @Test("Story is the default format")
    func defaultFormat() {
        #expect(ShareCardFormat.allCases.first == .story)
    }

    @Test("Free exports carry the Skinalyze mark; full access shares without it")
    func watermark() {
        #expect(ShareCardPolicy.showsWatermark(isPro: false))
        #expect(!ShareCardPolicy.showsWatermark(isPro: true))
    }
}
