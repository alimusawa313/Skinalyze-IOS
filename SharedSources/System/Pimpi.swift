import SwiftUI
import SkinalyzeKit

/// Pimpi — Skinalyze's mascot. The original pink blob with the little bump on its head, navy eyes and cream cheeks,
/// redrawn as a vector character with depth (no outlines) and moods: it blinks, breathes, and its bump wobbles.
/// Decorative: hidden from VoiceOver (pair it with real text). Reduce Motion: still.
struct Pimpi: View {
    /// The moods are defined with the rule that picks them (`PimpiMoodEngine` in SkinalyzeKit).
    typealias Mood = MascotMood

    var mood: Mood = .happy

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The outfit won from a chest, set once at the app's root.
    @Environment(\.pimpiOutfit) private var outfit

    var body: some View {
        // Self-contained vector art: every part is placed relative to the mascot's own square (GeometryReader is the
        // right tool for a drawing that must scale as one piece).
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height)
            ZStack {
                shadow(unit)
                feet(unit)
                arms(unit)
                bodyShape(unit)
                bump(unit)
                face(unit)
                extras(unit)
                if let outfit { PimpiOutfitLayer(outfit: outfit, unit: unit) }
            }
            .frame(width: unit, height: unit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: Parts (unit = side of the mascot's square)

    private func shadow(_ u: CGFloat) -> some View {
        Ellipse().fill(.black.opacity(0.16))
            .frame(width: u * 0.56, height: u * 0.07)
            .blur(radius: u * 0.02)
            .position(x: u * 0.5, y: u * 0.93)
    }

    private func bodyShape(_ u: CGFloat) -> some View {
        PimpiBody()
            .fill(LinearGradient(colors: [Color.ds.pimpiHighlight, Color.ds.pimpiBody, Color.ds.pimpiBodyDeep],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .topLeading) {
                // Soft gloss instead of an outline.
                Ellipse().fill(.white.opacity(0.28))
                    .frame(width: u * 0.26, height: u * 0.13)
                    .rotationEffect(.degrees(-24))
                    .blur(radius: u * 0.02)
                    .offset(x: u * 0.2, y: u * 0.3)
            }
            .frame(width: u, height: u)
            .phaseAnimator(reduceMotion ? [1.0] : [1.0, 1.025]) { content, breath in
                content.scaleEffect(x: 2 - breath, y: breath, anchor: .bottom)
            } animation: { _ in .easeInOut(duration: mood == .sleepy ? 2.4 : 1.6) }
    }

    /// The signature bump on the head — it wobbles, droops when sad.
    private func bump(_ u: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color.ds.pimpiHighlight, Color.ds.pimpiBody], center: .init(x: 0.35, y: 0.3),
                                 startRadius: 0, endRadius: u * 0.09))
            .overlay(alignment: .topLeading) {
                Circle().fill(.white.opacity(0.7)).frame(width: u * 0.035, height: u * 0.035).offset(x: u * 0.03, y: u * 0.025)
            }
            .frame(width: u * 0.15, height: u * 0.15)
            .position(x: u * 0.43, y: u * (mood == .sad ? 0.235 : 0.2))
            .phaseAnimator(reduceMotion ? [0.0] : [-5.0, 5.0]) { content, tilt in
                content.rotationEffect(.degrees(tilt), anchor: .bottom)
            } animation: { _ in .easeInOut(duration: mood == .excited ? 0.45 : 1.3) }
    }

    private func feet(_ u: CGFloat) -> some View {
        ForEach([0.36, 0.64], id: \.self) { x in
            Capsule().fill(Color.ds.pimpiBodyDeep)
                .frame(width: u * 0.13, height: u * 0.09)
                .position(x: u * x, y: u * 0.885)
        }
    }

    private func arms(_ u: CGFloat) -> some View {
        let raised = mood == .excited
        // Left arm pivots at its inner (trailing) end: positive angles lift the hand, negative lower it.
        let leftAngle: Double = raised ? 55 : (mood == .sad || mood == .sleepy ? -28 : 8)
        let rightAngle: Double = raised ? 55 : (mood == .curious ? 62 : (mood == .sad || mood == .sleepy ? -28 : -8))
        let lift: CGFloat = raised ? 0.4 : 0.56
        return Group {
            Capsule().fill(Color.ds.pimpiBody)
                .frame(width: u * 0.2, height: u * 0.1)
                .rotationEffect(.degrees(leftAngle), anchor: .trailing)
                .position(x: u * 0.1, y: u * lift)
            Capsule().fill(Color.ds.pimpiBody)
                .frame(width: u * 0.2, height: u * 0.1)
                .rotationEffect(.degrees(-rightAngle), anchor: .leading)
                .position(x: u * 0.9, y: u * (mood == .curious ? 0.5 : lift))
        }
        .animation(.spring(duration: 0.5, bounce: 0.5), value: mood)
    }

    private func face(_ u: CGFloat) -> some View {
        ZStack {
            // Cheeks: the old cream circles, softened into a glow.
            ForEach([0.235, 0.765], id: \.self) { x in
                Circle().fill(Color.ds.pimpiCheek.opacity(0.92))
                    .frame(width: u * 0.14, height: u * 0.14)
                    .blur(radius: u * 0.008)
                    .position(x: u * x, y: u * 0.635)
            }
            eye(u, x: 0.36)
            eye(u, x: 0.64)
            if mood == .worried || mood == .sad {
                // Inner ends up = worried / sad (inner ends down would read as angry).
                brow(u, x: 0.36, tilt: mood == .worried ? -12 : -22)
                brow(u, x: 0.64, tilt: mood == .worried ? 12 : 22)
            }
            PimpiMouth(mood: mood)
                .stroke(Color.ds.pimpiEye, style: StrokeStyle(lineWidth: u * 0.022, lineCap: .round, lineJoin: .round))
                .background {
                    if mood == .excited { PimpiMouth(mood: mood).fill(Color.ds.pimpiEye) }
                }
                .frame(width: u * 0.2, height: u * 0.12)
                .position(x: u * 0.5, y: u * 0.675)
        }
        .animation(.spring(duration: 0.45, bounce: 0.4), value: mood)
    }

    @ViewBuilder private func eye(_ u: CGFloat, x: CGFloat) -> some View {
        if mood == .sleepy {
            // Closed, content arcs.
            PimpiArc(smiling: true)
                .stroke(Color.ds.pimpiEye, style: StrokeStyle(lineWidth: u * 0.024, lineCap: .round))
                .frame(width: u * 0.13, height: u * 0.05)
                .position(x: u * x, y: u * 0.52)
        } else {
            let big = mood == .excited || (mood == .curious && x > 0.5)
            let width = u * (big ? 0.175 : 0.15), height = u * (big ? 0.19 : 0.165)
            ZStack {
                Ellipse().fill(Color.ds.pimpiEye)
                Circle().fill(.white).frame(width: width * 0.3).offset(x: width * 0.14, y: -height * 0.17)
                Circle().fill(.white.opacity(0.85)).frame(width: width * 0.13).offset(x: -width * 0.16, y: height * 0.2)
                if mood == .sad { // glossy, welling eyes
                    Ellipse().fill(.white.opacity(0.35)).frame(width: width * 0.7, height: height * 0.22).offset(y: height * 0.3)
                }
            }
            .frame(width: width, height: height)
            .phaseAnimator(reduceMotion ? [0] : [0, 1, 2]) { content, phase in
                content.scaleEffect(y: phase == 1 ? 0.08 : 1)
            } animation: { phase in
                phase == 1 ? .easeIn(duration: 0.08).delay(2.6) : .easeOut(duration: 0.1)
            }
            .position(x: u * x, y: u * 0.5)
        }
    }

    private func brow(_ u: CGFloat, x: CGFloat, tilt: Double) -> some View {
        Capsule().fill(Color.ds.pimpiEye)
            .frame(width: u * 0.11, height: u * 0.022)
            .rotationEffect(.degrees(tilt))
            .position(x: u * x, y: u * 0.385)
    }

    @ViewBuilder private func extras(_ u: CGFloat) -> some View {
        switch mood {
        case .curious:
            // The magnifying glass from the original scan mascot, now held up to one (bigger) eye.
            ZStack {
                Capsule().fill(Color.ds.pimpiEye)
                    .frame(width: u * 0.045, height: u * 0.24)
                    .rotationEffect(.degrees(-35))
                    .offset(x: u * 0.13, y: u * 0.17)
                Circle().fill(.white.opacity(0.28))
                    .overlay { Circle().strokeBorder(Color.ds.pimpiEye, lineWidth: u * 0.035) }
                    .overlay(alignment: .topLeading) {
                        Capsule().fill(.white.opacity(0.8)).frame(width: u * 0.07, height: u * 0.022)
                            .rotationEffect(.degrees(-40)).offset(x: u * 0.06, y: u * 0.075)
                    }
                    .frame(width: u * 0.3, height: u * 0.3)
            }
            .position(x: u * 0.66, y: u * 0.47)
        case .sleepy:
            ForEach(0..<3, id: \.self) { index in
                // A drawn "z", not text: it is part of the mascot and scales with Pimpi, not with the text size.
                let side = u * (0.05 + 0.022 * CGFloat(index))
                SleepZ()
                    .stroke(Color.ds.inkSecondary, style: StrokeStyle(lineWidth: side * 0.24, lineCap: .round, lineJoin: .round))
                    .frame(width: side, height: side)
                    .position(x: u * (0.74 + 0.07 * CGFloat(index)), y: u * (0.26 - 0.08 * CGFloat(index)))
            }
        case .excited:
            ForEach(Array([(0.12, 0.2, 0.09), (0.88, 0.17, 0.11), (0.8, 0.36, 0.06)].enumerated()), id: \.offset) { _, spark in
                Image(systemName: "sparkle")
                    .font(.system(size: u * spark.2, weight: .bold))
                    .foregroundStyle(Color.ds.caution)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
                    .position(x: u * spark.0, y: u * spark.1)
            }
        case .worried:
            // A sweat drop.
            Image(systemName: "drop.fill")
                .font(.system(size: u * 0.09))
                .foregroundStyle(Color.ds.band(.calm))
                .position(x: u * 0.83, y: u * 0.36)
        case .happy, .sad:
            EmptyView()
        }
    }
}

/// The blob: wider than tall, flat-bottomed, soft everywhere.
private struct PimpiBody: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var path = Path()
        path.move(to: point(0.5, 0.24))
        path.addCurve(to: point(0.89, 0.58), control1: point(0.74, 0.24), control2: point(0.89, 0.39))
        path.addCurve(to: point(0.68, 0.87), control1: point(0.89, 0.75), control2: point(0.82, 0.87))
        path.addLine(to: point(0.32, 0.87))
        path.addCurve(to: point(0.11, 0.58), control1: point(0.18, 0.87), control2: point(0.11, 0.75))
        path.addCurve(to: point(0.5, 0.24), control1: point(0.11, 0.39), control2: point(0.26, 0.24))
        path.closeSubpath()
        return path
    }
}

extension EnvironmentValues {
    /// What Pimpi wears everywhere it appears (nil: nothing).
    @Entry var pimpiOutfit: PimpiOutfit? = nil
}

/// Pimpi's accessories, in the same no-outline vector style. Placed on the mascot's own square.
struct PimpiOutfitLayer: View {
    let outfit: PimpiOutfit
    let unit: CGFloat

    var body: some View {
        let u = unit
        switch outfit {
        case .partyHat:
            ZStack {
                PimpiTriangle()
                    .fill(LinearGradient(colors: [Color.ds.signal, Color.ds.pimpiBodyDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: u * 0.2, height: u * 0.24)
                ForEach([0.35, 0.6, 0.82], id: \.self) { y in
                    Circle().fill(Color.ds.pimpiCheek).frame(width: u * 0.028, height: u * 0.028)
                        .offset(x: u * (y - 0.6) * 0.08, y: u * (y - 0.5) * 0.24)
                }
                Circle().fill(Color.ds.pimpiCheek).frame(width: u * 0.06, height: u * 0.06).offset(y: -u * 0.12)
            }
            .rotationEffect(.degrees(18))
            .position(x: u * 0.62, y: u * 0.17)
        case .beanie:
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: u * 0.3, bottomLeadingRadius: u * 0.02,
                                       bottomTrailingRadius: u * 0.02, topTrailingRadius: u * 0.3)
                    .fill(LinearGradient(colors: [Color.ds.positive.opacity(0.85), Color.ds.positive], startPoint: .top, endPoint: .bottom))
                    .frame(width: u * 0.6, height: u * 0.17)
                    .offset(y: -u * 0.02)
                Capsule().fill(Color.ds.positive)
                    .overlay { Capsule().fill(.black.opacity(0.12)) }
                    .frame(width: u * 0.66, height: u * 0.07)
                    .offset(y: u * 0.07)
                Circle().fill(Color.ds.pimpiCheek).frame(width: u * 0.09, height: u * 0.09).offset(y: -u * 0.12)
            }
            .position(x: u * 0.5, y: u * 0.27)
        case .flower:
            ZStack {
                ForEach(0..<5, id: \.self) { petal in
                    Circle().fill(Color.ds.pimpiCheek).frame(width: u * 0.075, height: u * 0.075)
                        .offset(y: -u * 0.045)
                        .rotationEffect(.degrees(Double(petal) * 72))
                }
                Circle().fill(Color.ds.caution).frame(width: u * 0.055, height: u * 0.055)
            }
            .position(x: u * 0.72, y: u * 0.3)
        case .bow:
            ZStack {
                Ellipse().fill(Color.ds.signal).frame(width: u * 0.12, height: u * 0.08).rotationEffect(.degrees(-22)).offset(x: -u * 0.06)
                Ellipse().fill(Color.ds.signal).frame(width: u * 0.12, height: u * 0.08).rotationEffect(.degrees(22)).offset(x: u * 0.06)
                Circle().fill(Color.ds.pimpiBodyDeep).frame(width: u * 0.05, height: u * 0.05)
            }
            .position(x: u * 0.68, y: u * 0.28)
        case .crown:
            ZStack {
                PimpiCrown()
                    .fill(LinearGradient(colors: [Color.ds.pimpiCheek, Color.ds.caution], startPoint: .top, endPoint: .bottom))
                    .frame(width: u * 0.32, height: u * 0.18)
                Circle().fill(Color.ds.signal).frame(width: u * 0.04, height: u * 0.04).offset(y: u * 0.04)
            }
            .position(x: u * 0.56, y: u * 0.16)
        case .sunglasses:
            ZStack {
                ForEach([-0.14, 0.14], id: \.self) { x in
                    RoundedRectangle(cornerRadius: u * 0.045, style: .continuous)
                        .fill(Color.ds.pimpiEye.opacity(0.94))
                        .overlay(alignment: .topLeading) {
                            Capsule().fill(.white.opacity(0.55)).frame(width: u * 0.05, height: u * 0.018)
                                .offset(x: u * 0.03, y: u * 0.025)
                        }
                        .frame(width: u * 0.19, height: u * 0.12)
                        .offset(x: u * x)
                }
                Capsule().fill(Color.ds.pimpiEye).frame(width: u * 0.1, height: u * 0.022).offset(y: -u * 0.02)
            }
            .position(x: u * 0.5, y: u * 0.52)
        }
    }
}

private struct PimpiTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PimpiCrown: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y) }
        var path = Path()
        path.move(to: point(0, 1))
        path.addLine(to: point(0, 0.25))
        path.addLine(to: point(0.25, 0.6))
        path.addLine(to: point(0.5, 0))
        path.addLine(to: point(0.75, 0.6))
        path.addLine(to: point(1, 0.25))
        path.addLine(to: point(1, 1))
        path.closeSubpath()
        return path
    }
}

/// A single curved line: a smile, or (flipped) a closed sleepy eye.
private struct PimpiArc: Shape {
    let smiling: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = smiling ? rect.minY : rect.maxY, control = smiling ? rect.maxY + rect.height : rect.minY - rect.height
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: y), control: CGPoint(x: rect.midX, y: control))
        return path
    }
}

private struct PimpiMouth: Shape {
    let mood: Pimpi.Mood
    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch mood {
        case .happy, .curious:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.25))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.25),
                              control: CGPoint(x: rect.midX, y: rect.maxY))
        case .excited: // open, delighted
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.15))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.15),
                              control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.9))
            path.closeSubpath()
        case .sleepy:
            path.addEllipse(in: CGRect(x: rect.midX - rect.width * 0.09, y: rect.minY + rect.height * 0.2,
                                       width: rect.width * 0.18, height: rect.height * 0.4))
        case .worried: // wobbly
            let y = rect.minY + rect.height * 0.5, step = rect.width * 0.7 / 3
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: y))
            for index in 0..<3 {
                let start = rect.minX + rect.width * 0.15 + step * CGFloat(index)
                path.addQuadCurve(to: CGPoint(x: start + step, y: y),
                                  control: CGPoint(x: start + step / 2, y: y + (index.isMultiple(of: 2) ? -1 : 1) * rect.height * 0.35))
            }
        case .sad:
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.7))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.7),
                              control: CGPoint(x: rect.midX, y: rect.minY))
        }
        return path
    }
}

/// The letter z as three strokes.
private struct SleepZ: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#if DEBUG
/// `-pimpiGallery YES`: every mood on both canvases, for design review.
struct PimpiGallery: View {
    var body: some View {
        VStack(spacing: 0) {
            sheet.environment(\.colorScheme, .light)
            sheet.environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
    }

    private var sheet: some View {
        VStack(spacing: Spacing.xs) {
            Text("Pimpi").font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(Color.ds.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Spacing.sm) {
                ForEach(Pimpi.Mood.allCases, id: \.self) { mood in
                    VStack(spacing: 2) {
                        Pimpi(mood: mood).frame(height: 104)
                            .environment(\.pimpiOutfit, PimpiOutfit.allCases[Pimpi.Mood.allCases.firstIndex(of: mood) ?? 0])
                        Text(mood.rawValue).font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas)
    }
}
#endif
