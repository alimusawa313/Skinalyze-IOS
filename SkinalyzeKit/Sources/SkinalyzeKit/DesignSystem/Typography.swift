import SwiftUI

/// Type scale (PLAN.md §6.4): New York serif for display + numerals, SF Pro for UI. Dynamic Type only — no fixed sizes.
public extension Font {
    enum ds {
        public static let display = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        public static let title = Font.system(.title2, design: .rounded).weight(.bold)
        public static let titleSmall = Font.system(.title3, design: .rounded).weight(.bold)
        public static let headline = Font.headline
        public static let body = Font.body
        public static let callout = Font.callout
        public static let footnote = Font.footnote
        public static let caption = Font.caption
        /// Big serif number (scores, counts) with tabular digits.
        public static let numeral = Font.system(size: 72, weight: .heavy, design: .rounded).monospacedDigit()
        public static let numeralSmall = Font.system(.title3, design: .rounded).weight(.bold).monospacedDigit()
        public static let label = Font.caption.weight(.semibold)
    }
}

/// 4-pt spacing grid.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

/// The only corner radii in the app.
public enum Radius {
    public static let small: CGFloat = 10
    public static let medium: CGFloat = 22
    public static let large: CGFloat = 36
}
