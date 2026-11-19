import Foundation

/// The shapes a share card can be exported in. Every card is laid out on a fixed canvas and rendered at a fixed
/// scale, so an export looks the same on every phone, text size and display.
public enum ShareCardFormat: String, CaseIterable, Sendable, Identifiable {
    /// 9:16 — stories, Reels, TikTok.
    case story
    /// 4:5 — feed posts.
    case portrait
    /// 1:1.
    case square

    public static let renderScale: Double = 3
    private static let layoutWidth: Double = 360

    public var id: String { rawValue }

    /// Width : height.
    private var ratio: (width: Double, height: Double) {
        switch self {
        case .story: (9, 16)
        case .portrait: (4, 5)
        case .square: (1, 1)
        }
    }

    /// The canvas the card is laid out on, in points.
    public var pointSize: (width: Double, height: Double) {
        (Self.layoutWidth, Self.layoutWidth * ratio.height / ratio.width)
    }

    public var pixelWidth: Int { Int((pointSize.width * Self.renderScale).rounded()) }
    public var pixelHeight: Int { Int((pointSize.height * Self.renderScale).rounded()) }
}

/// The one place that decides whether an export carries the Skinalyze mark.
public enum ShareCardPolicy {
    /// Always on for now; Phase 5 (paywall) decides who may turn it off.
    public static func showsWatermark(isPro: Bool) -> Bool { true }
}
