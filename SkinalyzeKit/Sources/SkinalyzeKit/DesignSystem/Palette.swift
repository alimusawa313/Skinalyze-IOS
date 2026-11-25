import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// An sRGB colour with WCAG helpers. Tokens are defined as hex so contrast is unit-tested (DesignSystemTests).
public struct RGB: Sendable, Hashable {
    public let red: Int
    public let green: Int
    public let blue: Int

    public init(hex: Int) {
        red = (hex >> 16) & 0xFF
        green = (hex >> 8) & 0xFF
        blue = hex & 0xFF
    }

    /// WCAG 2.x relative luminance.
    public var relativeLuminance: Double {
        func channel(_ value: Int) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public func contrastRatio(with other: RGB) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    var components: (Double, Double, Double) { (Double(red) / 255, Double(green) / 255, Double(blue) / 255) }
}

/// A semantic colour with light and dark values.
public struct ColorToken: Sendable, Hashable, CustomStringConvertible {
    public let name: String
    public let light: RGB
    public let dark: RGB

    init(_ name: String, light: Int, dark: Int) {
        self.name = name
        self.light = RGB(hex: light)
        self.dark = RGB(hex: dark)
    }

    public var description: String { name }

    /// Dynamic SwiftUI colour that follows the system appearance.
    public var color: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            let (r, g, b) = rgb.components
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
        #else
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let (r, g, b) = (isDark ? dark : light).components
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        })
        #endif
    }
}

/// "Pimpi's Place" palette: a cream sky over a pink hill by day, a dusk sky over a violet hill by night. Navy ink,
/// white pressable surfaces with a hard bottom edge. Views use `Color.ds.*`; never raw hex.
public enum Palette {
    /// The sky.
    public static let canvas = ColorToken("canvas", light: 0xFFF3E4, dark: 0x1E1D45)
    public static let surface = ColorToken("surface", light: 0xFFFFFF, dark: 0x2E2D63)
    public static let surfaceRaised = ColorToken("surfaceRaised", light: 0xFFE1D8, dark: 0x3B3A78)
    public static let ink = ColorToken("ink", light: 0x23224F, dark: 0xFFF3E4)
    public static let inkSecondary = ColorToken("inkSecondary", light: 0x6A4E5C, dark: 0xD6CFE6)
    public static let inkTertiary = ColorToken("inkTertiary", light: 0x8C7480, dark: 0x9A93B5)
    public static let hairline = ColorToken("hairline", light: 0xF1D9C6, dark: 0x45447F)
    public static let signal = ColorToken("signal", light: 0xE0496A, dark: 0xFF8A94)
    public static let positive = ColorToken("positive", light: 0x1F8A5B, dark: 0x4CD49A)
    public static let caution = ColorToken("caution", light: 0xB06A00, dark: 0xF2A93B)

    /// The hill Pimpi stands on, and the one behind it.
    public static let hill = ColorToken("hill", light: 0xFFC9C4, dark: 0x4A3B7A)
    public static let hillFar = ColorToken("hillFar", light: 0xFFE1D8, dark: 0x352C63)
    /// The sun by day, the moon by night.
    public static let sun = ColorToken("sun", light: 0xFFD95A, dark: 0xFFF3E4)
    /// Hard bottom edges: under a surface on the sky, under a surface on the hill, under a filled (ink) button.
    public static let edge = ColorToken("edge", light: 0xF1D9C6, dark: 0x131232)
    public static let edgeOnHill = ColorToken("edgeOnHill", light: 0xEDA6A6, dark: 0x241D4A)
    public static let inkEdge = ColorToken("inkEdge", light: 0x0F0E2E, dark: 0xD9C4A8)

    /// Pimpi, the mascot (the original character's pink, navy eyes and cream cheeks, with depth instead of outlines).
    public static let pimpiBody = ColorToken("pimpiBody", light: 0xFF7F8A, dark: 0xFF8A94)
    public static let pimpiBodyDeep = ColorToken("pimpiBodyDeep", light: 0xEC5A72, dark: 0xF0627A)
    public static let pimpiHighlight = ColorToken("pimpiHighlight", light: 0xFFB4BA, dark: 0xFFBFC4)
    public static let pimpiEye = ColorToken("pimpiEye", light: 0x23224F, dark: 0x23224F)
    public static let pimpiCheek = ColorToken("pimpiCheek", light: 0xFFF3E4, dark: 0xFFF3E4)
    /// The hard edge under a Pimpi-pink button (the scan button).
    public static let pimpiEdge = ColorToken("pimpiEdge", light: 0xC2405A, dark: 0xB8445C)

    /// Calm → mild → active → flared. Always paired with a label + shape, never colour alone.
    public static let bandRamp: [ColorToken] = [
        ColorToken("calm", light: 0xBFEFE2, dark: 0x3FBFA0),
        ColorToken("mild", light: 0xFFD3A6, dark: 0xF2A65A),
        ColorToken("active", light: 0xFF9473, dark: 0xFF7A59),
        ColorToken("flared", light: 0xD9386A, dark: 0xF0508A),
    ]
}

public extension Color {
    /// Design-system colours: `Color.ds.ink`, `Color.ds.signal`, …
    enum ds {
        public static var canvas: Color { Palette.canvas.color }
        public static var surface: Color { Palette.surface.color }
        public static var surfaceRaised: Color { Palette.surfaceRaised.color }
        public static var ink: Color { Palette.ink.color }
        public static var inkSecondary: Color { Palette.inkSecondary.color }
        public static var inkTertiary: Color { Palette.inkTertiary.color }
        public static var hairline: Color { Palette.hairline.color }
        public static var signal: Color { Palette.signal.color }
        public static var signalSoft: Color { Palette.signal.color.opacity(0.14) }
        public static var positive: Color { Palette.positive.color }
        public static var caution: Color { Palette.caution.color }

        public static var hill: Color { Palette.hill.color }
        public static var hillFar: Color { Palette.hillFar.color }
        public static var sun: Color { Palette.sun.color }
        public static var edge: Color { Palette.edge.color }
        public static var edgeOnHill: Color { Palette.edgeOnHill.color }
        public static var inkEdge: Color { Palette.inkEdge.color }

        public static var pimpiBody: Color { Palette.pimpiBody.color }
        public static var pimpiBodyDeep: Color { Palette.pimpiBodyDeep.color }
        public static var pimpiHighlight: Color { Palette.pimpiHighlight.color }
        public static var pimpiEye: Color { Palette.pimpiEye.color }
        public static var pimpiCheek: Color { Palette.pimpiCheek.color }
        public static var pimpiEdge: Color { Palette.pimpiEdge.color }

        public static func band(_ band: BreakoutBand) -> Color {
            Palette.bandRamp[BreakoutBand.allCases.firstIndex(of: band) ?? 0].color
        }
    }
}
