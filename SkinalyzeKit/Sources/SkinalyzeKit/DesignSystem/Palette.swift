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

/// "Glow" palette: warm-white / deep-night bases with a living, mood-driven accent (calm mint → flared magenta).
/// Views use `Color.ds.*`; never raw hex.
public enum Palette {
    public static let canvas = ColorToken("canvas", light: 0xFBF7F4, dark: 0x0E0C14)
    public static let surface = ColorToken("surface", light: 0xFFFFFF, dark: 0x1A1722)
    public static let surfaceRaised = ColorToken("surfaceRaised", light: 0xF4EEEA, dark: 0x241F2E)
    public static let ink = ColorToken("ink", light: 0x17141F, dark: 0xF6F2FA)
    public static let inkSecondary = ColorToken("inkSecondary", light: 0x585266, dark: 0xB6AFC3)
    public static let inkTertiary = ColorToken("inkTertiary", light: 0x8C8696, dark: 0x7E788A)
    public static let hairline = ColorToken("hairline", light: 0xECE5E0, dark: 0x2E2938)
    public static let signal = ColorToken("signal", light: 0xE5484D, dark: 0xFF6B6F)
    public static let positive = ColorToken("positive", light: 0x1F8A5B, dark: 0x4CD49A)
    public static let caution = ColorToken("caution", light: 0xB06A00, dark: 0xF2A93B)

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

        public static func band(_ band: BreakoutBand) -> Color {
            Palette.bandRamp[BreakoutBand.allCases.firstIndex(of: band) ?? 0].color
        }
    }
}
