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

/// "Field Notes" palette (PLAN.md §6.3): bone paper, ink, and ONE vivid signal accent.
/// Views use `Color.ds.*`; never raw hex.
public enum Palette {
    public static let canvas = ColorToken("canvas", light: 0xF6F3EE, dark: 0x121110)
    public static let surface = ColorToken("surface", light: 0xFFFFFF, dark: 0x1C1A18)
    public static let surfaceRaised = ColorToken("surfaceRaised", light: 0xFBF9F6, dark: 0x252220)
    public static let ink = ColorToken("ink", light: 0x1A1817, dark: 0xF3EFEA)
    public static let inkSecondary = ColorToken("inkSecondary", light: 0x625C56, dark: 0xADA59E)
    public static let inkTertiary = ColorToken("inkTertiary", light: 0x8F8881, dark: 0x7C756F)
    public static let hairline = ColorToken("hairline", light: 0xE5DED5, dark: 0x34302C)
    public static let signal = ColorToken("signal", light: 0xD24A2F, dark: 0xFF6B4E)
    public static let positive = ColorToken("positive", light: 0x2F7D5B, dark: 0x5CC296)
    public static let caution = ColorToken("caution", light: 0xA86C12, dark: 0xE3A44A)

    /// Calm → mild → active → flared. Always paired with a label + shape, never colour alone.
    public static let bandRamp: [ColorToken] = [
        ColorToken("calm", light: 0xE4DED4, dark: 0x4A4540),
        ColorToken("mild", light: 0xE8C9A0, dark: 0x9C7B4E),
        ColorToken("active", light: 0xD98A55, dark: 0xD08A5C),
        ColorToken("flared", light: 0x9E3F35, dark: 0xE0705F),
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
