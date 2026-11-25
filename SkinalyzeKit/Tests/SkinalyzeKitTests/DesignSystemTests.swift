import Testing
@testable import SkinalyzeKit

@Suite("Design tokens")
struct DesignTokenTests {
    @Test("Hex parsing")
    func hex() {
        let color = RGB(hex: 0xE2553A)
        #expect(color.red == 0xE2 && color.green == 0x55 && color.blue == 0x3A)
    }

    @Test("WCAG contrast: black on white is 21:1, same colour is 1:1")
    func contrastFormula() {
        #expect(abs(RGB(hex: 0x000000).contrastRatio(with: RGB(hex: 0xFFFFFF)) - 21) < 0.01)
        #expect(abs(RGB(hex: 0x777777).contrastRatio(with: RGB(hex: 0x777777)) - 1) < 0.001)
    }

    @Test("Body text tokens meet WCAG AA (4.5:1) on every background, light and dark",
          arguments: [Palette.ink, Palette.inkSecondary])
    func textContrast(token: ColorToken) {
        for background in [Palette.canvas, Palette.surface, Palette.surfaceRaised] {
            #expect(token.light.contrastRatio(with: background.light) >= 4.5, "\(token.name) light on \(background.name)")
            #expect(token.dark.contrastRatio(with: background.dark) >= 4.5, "\(token.name) dark on \(background.name)")
        }
    }

    @Test("Text stays readable on the hill, light and dark", arguments: [Palette.ink, Palette.inkSecondary])
    func textContrastOnHill(token: ColorToken) {
        for hill in [Palette.hill, Palette.hillFar] {
            #expect(token.light.contrastRatio(with: hill.light) >= 4.5, "\(token.name) light on \(hill.name)")
            #expect(token.dark.contrastRatio(with: hill.dark) >= 4.5, "\(token.name) dark on \(hill.name)")
        }
    }

    @Test("The filled button's label reads on its fill, and the fill stands out from the canvas and the hill")
    func chunkyButtonContrast() {
        #expect(Palette.canvas.light.contrastRatio(with: Palette.ink.light) >= 4.5)
        #expect(Palette.canvas.dark.contrastRatio(with: Palette.ink.dark) >= 4.5)
        for ground in [Palette.canvas, Palette.hill] {
            #expect(Palette.ink.light.contrastRatio(with: ground.light) >= 3)
            #expect(Palette.ink.dark.contrastRatio(with: ground.dark) >= 3)
        }
    }

    @Test("A pressed-in edge is darker than the thing it sits under")
    func edgesAreDarker() {
        #expect(Palette.edge.light.relativeLuminance < Palette.surface.light.relativeLuminance)
        #expect(Palette.edgeOnHill.light.relativeLuminance < Palette.hill.light.relativeLuminance)
        #expect(Palette.inkEdge.light.relativeLuminance < Palette.ink.light.relativeLuminance)
        #expect(Palette.edge.dark.relativeLuminance < Palette.surface.dark.relativeLuminance)
    }

    @Test("Accent and status colours meet 3:1 for non-text UI on the canvas",
          arguments: [Palette.signal, Palette.positive, Palette.caution])
    func uiContrast(token: ColorToken) {
        #expect(token.light.contrastRatio(with: Palette.canvas.light) >= 3)
        #expect(token.dark.contrastRatio(with: Palette.canvas.dark) >= 3)
    }

    @Test("Severity ramp gets darker step by step in light mode (perceptually ordered)")
    func rampOrdered() {
        let luminance = Palette.bandRamp.map { $0.light.relativeLuminance }
        #expect(luminance == luminance.sorted(by: >))
        #expect(Palette.bandRamp.count == BreakoutBand.allCases.count)
    }

    @Test("Motion: reduced motion swaps every token for the opacity crossfade")
    func reducedMotion() {
        for token in MotionToken.allCases {
            #expect(token.resolved(reduceMotion: true) == .reduced)
            #expect(token.resolved(reduceMotion: false) == token)
        }
    }

    @Test("Every lesion type has a glyph and a plain-language name")
    func lesionGlyphs() {
        for type in LesionType.allCases {
            #expect(!LesionGlyph.symbolName(for: type).isEmpty)
            #expect(!LesionGlyph.displayName(for: type).isEmpty)
        }
        #expect(Set(LesionType.allCases.map(LesionGlyph.symbolName(for:))).count == LesionType.allCases.count)
    }
}
