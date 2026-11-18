import SwiftUI
import SkinalyzeKit

/// The app's environment: a slow, drifting mesh gradient tinted by skin mood (calm mint → flared magenta),
/// like a sky that changes with you. Static under Reduce Motion.
struct LivingBackground: View {
    var band: BreakoutBand = .calm

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: [Color] {
        switch band {
        case .calm: [Color(hex: 0xBFEFE2), Color(hex: 0xCFE3FF), Color(hex: 0xE9F7F1)]
        case .mild: [Color(hex: 0xFFD3A6), Color(hex: 0xFFC2D1), Color(hex: 0xFFF1E3)]
        case .active: [Color(hex: 0xFF9473), Color(hex: 0xFFC27A), Color(hex: 0xFFE3D6)]
        case .flared: [Color(hex: 0xD9386A), Color(hex: 0x8E5CF6), Color(hex: 0xF7D6E3)]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : Float(context.date.timeIntervalSinceReferenceDate * 0.18)
            let (a, b, c) = (palette[0], palette[1], palette[2])
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + 0.08 * sin(t), 0], [1, 0],
                    [0, 0.5 + 0.1 * cos(t * 0.8)], [0.5 + 0.12 * cos(t * 0.7), 0.45 + 0.1 * sin(t * 0.9)], [1, 0.5 + 0.1 * sin(t * 1.1)],
                    [0, 1], [0.5 + 0.08 * cos(t * 1.2), 1], [1, 1],
                ],
                colors: [a, c, b, c, a, c, b, c, a]
            )
            .opacity(colorScheme == .dark ? 0.32 : 0.75)
        }
        .background(Color.ds.canvas)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: band)
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: Int) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
