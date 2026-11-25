#if DEBUG
import SwiftUI
import SkinalyzeKit

/// The app icon, drawn from the real Pimpi so the two always match (`-appIconDump <folder>` writes the three
/// 1024 px PNGs the asset catalog uses). Pimpi stands on its hill under the sun; dark is the dusk sky with the moon;
/// tinted is a grayscale Pimpi on black for the system to tint. Debug builds only.
struct AppIconArt: View {
    enum Variant: String, CaseIterable {
        case light, dark, tinted
    }

    let variant: Variant

    private enum Metrics {
        static let side: CGFloat = 1024
        static let pimpi: CGFloat = 700
        static let sun: CGFloat = 300
        static let hillCrest: CGFloat = 0.74
        static let hillRise: CGFloat = 70
    }

    var body: some View {
        ZStack {
            if variant == .tinted {
                Color.black
            } else {
                Color.ds.canvas
                Circle().fill(Color.ds.sun)
                    .frame(width: Metrics.sun, height: Metrics.sun)
                    .position(x: Metrics.side * 0.2, y: Metrics.side * 0.72)
                HillShape(crest: 0, rise: Metrics.hillRise)
                    .fill(Color.ds.hill)
                    .frame(height: Metrics.side * (1 - Metrics.hillCrest) + Metrics.hillRise)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            Pimpi(mood: .happy)
                .frame(width: Metrics.pimpi, height: Metrics.pimpi)
                .position(x: Metrics.side / 2, y: Metrics.side * 0.5)
                .grayscale(variant == .tinted ? 1 : 0)
                .brightness(variant == .tinted ? 0.15 : 0)
        }
        .frame(width: Metrics.side, height: Metrics.side)
        .environment(\.colorScheme, variant == .dark ? .dark : .light)
    }

    @MainActor
    static func dump(into folder: String) {
        for variant in Variant.allCases {
            let renderer = ImageRenderer(content: AppIconArt(variant: variant))
            renderer.scale = 1
            renderer.isOpaque = true
            let url = URL(fileURLWithPath: folder).appendingPathComponent("AppIcon-\(variant.rawValue).png")
            try? renderer.uiImage?.pngData()?.write(to: url)
        }
    }
}
#endif
