#if DEBUG
import SwiftUI
import SkinalyzeKit

/// The demo scans' "photo": an illustrated person in a spa headband (clearly a drawing, never a real face), with
/// small marks drawn where the demo detections sit, so pins land on something. Debug builds only; used by `DemoData`
/// and so by the Simulator screens and the App Store set.
struct DemoPortrait: View {
    /// A mark to draw: its kind and centre, in the photo's own top-down unit space.
    struct Mark {
        let type: LesionType
        let center: CGPoint
    }

    let angle: CaptureAngle
    let tone: Double
    let marks: [Mark]

    static let size = CGSize(width: 900, height: 1200)

    private enum Palette {
        static let wallTop = Color(red: 0.98, green: 0.92, blue: 0.86)
        static let wallBottom = Color(red: 0.96, green: 0.84, blue: 0.80)
        static let robe = Color(red: 1, green: 0.99, blue: 0.97)
        static let robeShade = Color(red: 0.93, green: 0.89, blue: 0.86)
        static let hair = Color(red: 0.24, green: 0.15, blue: 0.13)
        static let band = Color(red: 1, green: 0.50, blue: 0.54)
        static let bandDeep = Color(red: 0.93, green: 0.35, blue: 0.45)
        static let line = Color(red: 0.30, green: 0.18, blue: 0.17)
        static let blush = Color(red: 1, green: 0.55, blue: 0.55)
    }

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var skin: Color { Color(red: 0.95 * tone + 0.05, green: 0.80 * tone, blue: 0.70 * tone) }
    private var skinShade: Color { Color(red: 0.86 * tone, green: 0.68 * tone, blue: 0.58 * tone) }

    /// Turned to one side: the face and its features slide that way.
    private var turn: CGFloat {
        switch angle {
        case .front: 0
        case .right: 70
        case .left: -70
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let full = CGRect(origin: .zero, size: size)
        context.fill(Path(full), with: .linearGradient(Gradient(colors: [Palette.wallTop, Palette.wallBottom]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        context.fill(Path(ellipseIn: CGRect(x: -200, y: -260, width: 800, height: 700)),
                     with: .color(.white.opacity(0.35)))

        let face = CGRect(x: 180 + turn, y: 150, width: 540, height: 760)
        // Hair behind the head, neck, then the robe over the shoulders.
        context.fill(Path(ellipseIn: face.insetBy(dx: -46, dy: -40).offsetBy(dx: -turn * 0.3, dy: -18)), with: .color(Palette.hair))
        context.fill(Path(roundedRect: CGRect(x: w / 2 - 120 + turn * 0.4, y: 820, width: 240, height: 260), cornerRadius: 60),
                     with: .color(skinShade))
        var robe = Path()
        robe.move(to: CGPoint(x: -40, y: h))
        robe.addCurve(to: CGPoint(x: w / 2, y: 1010), control1: CGPoint(x: 0, y: 1010), control2: CGPoint(x: 200, y: 990))
        robe.addCurve(to: CGPoint(x: w + 40, y: h), control1: CGPoint(x: 700, y: 990), control2: CGPoint(x: w, y: 1010))
        robe.closeSubpath()
        context.fill(robe, with: .color(Palette.robe))
        var collar = Path()
        collar.move(to: CGPoint(x: w / 2 - 170, y: 1010))
        collar.addLine(to: CGPoint(x: w / 2, y: h + 10))
        collar.addLine(to: CGPoint(x: w / 2 + 170, y: 1010))
        context.stroke(collar, with: .color(Palette.robeShade), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))

        // Ears, the face with a soft highlight, blush.
        let earY = face.minY + face.height * 0.42
        for side in [-1.0, 1.0] where !(side < 0 && turn > 0) && !(side > 0 && turn < 0) {
            let x = side < 0 ? face.minX - 28 : face.maxX - 44
            context.fill(Path(ellipseIn: CGRect(x: x, y: earY, width: 72, height: 120)), with: .color(skinShade))
        }
        context.fill(Path(ellipseIn: face), with: .radialGradient(Gradient(colors: [skin, skinShade]),
                                                                    center: CGPoint(x: face.midX - 60 + turn * 0.4, y: face.minY + 260),
                                                                    startRadius: 60, endRadius: 520))
        let featureX = face.midX + turn * 0.35
        for x in [featureX - 150, featureX + 150] {
            context.fill(Path(ellipseIn: CGRect(x: x - 70, y: face.minY + 430, width: 140, height: 80)),
                         with: .color(Palette.blush.opacity(0.28)))
        }

        // Hair line and the spa headband.
        var fringe = Path()
        fringe.move(to: CGPoint(x: face.minX + 10, y: face.minY + 150))
        fringe.addQuadCurve(to: CGPoint(x: face.maxX - 10, y: face.minY + 150), control: CGPoint(x: face.midX, y: face.minY - 70))
        fringe.closeSubpath()
        context.fill(fringe, with: .color(Palette.hair))
        let band = CGRect(x: face.minX - 30, y: face.minY + 70, width: face.width + 60, height: 96)
        var bandPath = Path()
        bandPath.move(to: CGPoint(x: band.minX, y: band.maxY))
        bandPath.addQuadCurve(to: CGPoint(x: band.maxX, y: band.maxY), control: CGPoint(x: band.midX, y: band.minY - 40))
        bandPath.addLine(to: CGPoint(x: band.maxX, y: band.maxY - 70))
        bandPath.addQuadCurve(to: CGPoint(x: band.minX, y: band.maxY - 70), control: CGPoint(x: band.midX, y: band.minY - 110))
        bandPath.closeSubpath()
        context.fill(bandPath, with: .color(Palette.band))
        // The bow on top.
        let bow = CGPoint(x: face.midX + 120 + turn * 0.2, y: face.minY + 40)
        for side in [-1.0, 1.0] {
            context.fill(Path(ellipseIn: CGRect(x: bow.x + side * 50 - 45, y: bow.y - 34, width: 90, height: 68)), with: .color(Palette.band))
        }
        context.fill(Path(ellipseIn: CGRect(x: bow.x - 24, y: bow.y - 24, width: 48, height: 48)), with: .color(Palette.bandDeep))

        // Brows, closed relaxed eyes, nose and a small smile.
        let ink = GraphicsContext.Shading.color(Palette.line)
        let eyeY = face.minY + face.height * 0.42
        for x in [featureX - 115, featureX + 115] {
            var brow = Path()
            brow.move(to: CGPoint(x: x - 60, y: eyeY - 60))
            brow.addQuadCurve(to: CGPoint(x: x + 60, y: eyeY - 62), control: CGPoint(x: x, y: eyeY - 92))
            context.stroke(brow, with: ink, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            var lid = Path()
            lid.move(to: CGPoint(x: x - 50, y: eyeY))
            lid.addQuadCurve(to: CGPoint(x: x + 50, y: eyeY), control: CGPoint(x: x, y: eyeY + 36))
            context.stroke(lid, with: ink, style: StrokeStyle(lineWidth: 11, lineCap: .round))
            for step in [-30.0, 0, 30] {
                var lash = Path()
                lash.move(to: CGPoint(x: x + step, y: eyeY + 17))
                lash.addLine(to: CGPoint(x: x + step * 1.2, y: eyeY + 34))
                context.stroke(lash, with: ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        var nose = Path()
        nose.move(to: CGPoint(x: featureX - 6, y: eyeY + 70))
        nose.addQuadCurve(to: CGPoint(x: featureX - 30, y: eyeY + 150), control: CGPoint(x: featureX + 10, y: eyeY + 120))
        nose.addQuadCurve(to: CGPoint(x: featureX + 26, y: eyeY + 152), control: CGPoint(x: featureX, y: eyeY + 170))
        context.stroke(nose, with: .color(skinShade.opacity(0.9)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        let mouthY = face.minY + face.height * 0.71
        var smile = Path()
        smile.move(to: CGPoint(x: featureX - 70, y: mouthY))
        smile.addQuadCurve(to: CGPoint(x: featureX + 70, y: mouthY), control: CGPoint(x: featureX, y: mouthY + 50))
        context.stroke(smile, with: .color(Palette.bandDeep), style: StrokeStyle(lineWidth: 14, lineCap: .round))

        for mark in marks { draw(mark, in: &context, size: size) }
    }

    private func draw(_ mark: Mark, in context: inout GraphicsContext, size: CGSize) {
        let c = CGPoint(x: mark.center.x * size.width, y: mark.center.y * size.height)
        func dot(_ radius: CGFloat, _ color: Color, dx: CGFloat = 0, dy: CGFloat = 0) {
            context.fill(Path(ellipseIn: CGRect(x: c.x + dx - radius, y: c.y + dy - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color))
        }
        let pink = Color(red: 0.88, green: 0.42, blue: 0.42)
        switch mark.type {
        case .papule, .nodule:
            dot(15, pink.opacity(0.45)); dot(9, pink)
        case .pustule:
            dot(15, pink.opacity(0.45)); dot(9, pink); dot(4, Color(red: 1, green: 0.96, blue: 0.85))
        case .whitehead:
            dot(11, pink.opacity(0.35)); dot(6, Color(red: 1, green: 0.97, blue: 0.9))
        case .blackhead:
            for (dx, dy) in [(-10.0, 0.0), (6, -6), (8, 9)] { dot(3.5, Palette.line, dx: dx, dy: dy) }
        case .darkSpot:
            dot(20, skinShade.opacity(0.9)); dot(13, Color(red: 0.62 * tone, green: 0.45 * tone, blue: 0.36 * tone).opacity(0.7))
        }
    }

    /// The JPEG the demo scan stores.
    @MainActor
    static func jpeg(angle: CaptureAngle, seed: Int, marks: [Mark]) -> Data? {
        let renderer = ImageRenderer(content: DemoPortrait(angle: angle, tone: 1 - Double(seed % 3) * 0.04, marks: marks))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage?.jpegData(compressionQuality: 0.85)
    }
}
#endif
