import SwiftUI
import SkinalyzeKit

/// The widget that looks like the skin card: the latest scan's mood colour, its index, and Pimpi where the sticker
/// would be. It carries no photo, so nothing personal shows on a home screen someone else can see.
struct SkinCardWidgetView: View {
    let snapshot: WidgetSnapshot
    let mood: MascotMood

    private static let numeral = Font.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit()
    private static let pimpiShare = 0.54

    static func band(of snapshot: WidgetSnapshot) -> BreakoutBand? {
        snapshot.bandRaw.flatMap(BreakoutBand.init(rawValue:))
    }

    /// The card's colour; the app's canvas before the first scan.
    static func background(for snapshot: WidgetSnapshot) -> some View {
        let colors = band(of: snapshot).map { [Color.ds.band($0), Color.ds.band($0).opacity(0.7)] }
            ?? [Color.ds.surfaceRaised, Color.ds.canvas]
        return ZStack {
            Color.ds.canvas
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .environment(\.colorScheme, .light)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                // Pimpi takes the top-right corner, sized from the widget itself.
                let side = min(proxy.size.width, proxy.size.height) * Self.pimpiShare
                Pimpi(mood: mood)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.breakoutIndex.map(String.init) ?? "–").font(Self.numeral).lineLimit(1)
                Text(caption).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(Color.ds.ink)
        // Always the card's own look: pastel colour with dark ink, in light and dark mode alike.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var caption: String {
        Self.band(of: snapshot).map(BandCopy.title) ?? String(localized: "Tap to scan")
    }

    private var accessibilityLabel: Text {
        guard let index = snapshot.breakoutIndex else { return Text("Tap to scan") }
        return Text("Breakout index · \(caption)") + Text(verbatim: ", \(index)")
    }
}
