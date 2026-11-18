import SwiftUI
import SkinalyzeKit

/// Face ID–style enrollment ring: 72 ticks around the camera circle light up as you turn your head.
/// Top/bottom arcs fill with the front photo, the right arc as you turn right, the left arc as you turn left.
struct FaceRing: View {
    let frontProgress: Double
    let rightProgress: Double
    let leftProgress: Double
    static let tickCount = 72

    var litCount: Int {
        (0..<Self.tickCount).filter { isLit($0) }.count
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            ZStack {
                ForEach(0..<Self.tickCount, id: \.self) { index in
                    let lit = isLit(index)
                    Capsule()
                        .fill(lit ? Color.ds.positive : Color.ds.ink.opacity(0.28))
                        .frame(width: 3.5, height: lit ? 22 : 14)
                        .offset(y: -radius + 11)
                        .rotationEffect(.degrees(Double(index) / Double(Self.tickCount) * 360))
                        .animation(.spring(duration: 0.35, bounce: 0.4), value: lit)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    /// Tick angle 0° = top, clockwise. Right arc = 30°…150°, left arc = 210°…330°, front = the rest.
    private func isLit(_ index: Int) -> Bool {
        let angle = Double(index) / Double(Self.tickCount) * 360
        switch angle {
        case 30..<150: return rightProgress > 0 && abs(angle - 90) / 60 <= rightProgress
        case 210..<330: return leftProgress > 0 && abs(angle - 270) / 60 <= leftProgress
        default:
            let distance = angle < 30 ? angle : (angle < 210 ? abs(angle - 180) : 360 - angle)
            return frontProgress > 0 && distance / 30 <= frontProgress
        }
    }
}
