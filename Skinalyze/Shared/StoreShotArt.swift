#if DEBUG
import SwiftUI
import SkinalyzeKit

/// The App Store set: "a day in Pimpi's Place". One hill and one dotted path run through every shot, and the sun
/// crosses the sky from the first shot to the last, which is night (the app in dark mode, under the moon). Each shot
/// is a real screen (captured by `StoreShotsUITests`) in a chunky toy phone, with Pimpi stepping out of the frame
/// and, on some, a piece of the screen lifted off as a sticker (the scan's own signature moment).
///
/// `-storeShotsDump <out folder> -storeShotsSource <raw folder>`: renders every size whose raw screens exist
/// (`<raw>/<device>/<light|dark>/<screen>.png`) into `<out>/<size>/NN-<screen>.png`. Debug builds only.
struct StoreShotArt: View {
    let shot: StoreShot
    let index: Int
    let canvas: StoreCanvas
    let screen: UIImage

    var body: some View {
        let size = canvas.points
        let w = size.width
        let sky = StoreSky(time: shot.time)
        let layout = canvas.layout(screenAspect: screen.size.height / screen.size.width, in: size, pimpiIsLeft: shot.pimpi.isLeft)
        ZStack(alignment: .topLeading) {
            sky.top
            celestial(sky: sky, layout: layout, width: w)
            StoreHill(globalX: CGFloat(index) * w, width: w, crest: layout.hillCrest, amplitude: w * 0.035, phase: 0.6)
                .fill(sky.hillFar)
            StoreHill(globalX: CGFloat(index) * w, width: w, crest: layout.hillCrest + w * 0.07, amplitude: w * 0.03, phase: 0)
                .fill(sky.hill)
            StorePath(globalX: CGFloat(index) * w, width: w, crest: layout.hillCrest + w * 0.07 + w * 0.09, amplitude: w * 0.03)
                .stroke(sky.path, style: StrokeStyle(lineWidth: w * 0.012, lineCap: .round, dash: [w * 0.001, w * 0.035]))
            headline(sky: sky, layout: layout)
            if shot.pimpi.isBehindPhone { pimpi(layout: layout) }
            StorePhone(screen: screen, kind: canvas.phoneKind, sky: sky)
                .frame(width: layout.phone.width, height: layout.phone.height)
                .rotationEffect(.degrees(canvas == .duoInner ? shot.tilt * 0.3 : shot.tilt))
                .offset(x: layout.phone.minX, y: layout.phone.minY)
            if let sticker = shot.sticker, canvas.showsStickers { stickerView(sticker, layout: layout) }
            if !shot.pimpi.isBehindPhone { pimpi(layout: layout) }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .environment(\.colorScheme, shot.isNight ? .dark : .light)
    }

    // MARK: Pieces

    private func headline(sky: StoreSky, layout: StoreLayout) -> some View {
        VStack(spacing: layout.headlineSize * 0.12) {
            Text(shot.headline)
                .font(.system(size: layout.headlineSize, weight: .heavy, design: .rounded))
                .foregroundStyle(sky.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(-layout.headlineSize * 0.12)
                .minimumScaleFactor(0.6)
            Text(shot.line)
                .font(.custom(Handwriting.fontName, fixedSize: layout.headlineSize * 0.52))
                .foregroundStyle(sky.accent)
                .multilineTextAlignment(.center)
                .rotationEffect(.degrees(-2))
        }
        .frame(width: layout.headline.width, height: layout.headline.height)
        .offset(x: layout.headline.minX, y: layout.headline.minY)
    }

    @ViewBuilder
    private func celestial(sky: StoreSky, layout: StoreLayout, width w: CGFloat) -> some View {
        let radius = w * canvas.sunScale
        // Wide canvas: the sun keeps to the corners, clear of the headline in the middle.
        let x = canvas == .duoInner
            ? w * (shot.sunX < 0.5 ? 0.06 + 0.24 * shot.sunX : 0.82 + 0.24 * (shot.sunX - 0.5))
            : w * (0.12 + 0.76 * shot.sunX)
        let y = layout.sunY - radius * 1.6 * sin(.pi * shot.sunX)
        if shot.isNight {
            // Stars, then a crescent moon.
            ForEach(Array(StoreSky.stars.enumerated()), id: \.offset) { _, star in
                Circle().fill(sky.sun.opacity(0.8))
                    .frame(width: w * star.z, height: w * star.z)
                    .position(x: w * star.x, y: layout.hillCrest * star.y)
            }
            ZStack {
                Circle().fill(sky.sun)
                Circle().fill(sky.top).frame(width: radius * 1.7, height: radius * 1.7).offset(x: radius * 0.55, y: -radius * 0.35)
            }
            .frame(width: radius * 2, height: radius * 2)
            .clipShape(Circle())
            .position(x: x, y: y)
        } else {
            Circle().fill(sky.sun.opacity(0.35)).frame(width: radius * 2.8, height: radius * 2.8).position(x: x, y: y)
            Circle().fill(sky.sun).frame(width: radius * 2, height: radius * 2).position(x: x, y: y)
        }
    }

    private func pimpi(layout: StoreLayout) -> some View {
        let side = layout.pimpiSize * shot.pimpi.scale
        let w = layout.size.width
        let edge: CGFloat = canvas == .duoInner ? 0.1 : 0.2
        let x: CGFloat = shot.pimpi.isLeft ? w * edge : w * (1 - edge)
        let y = layout.size.height - side * 0.5 - w * 0.02 - layout.size.height * shot.pimpi.lift
        return Pimpi(mood: shot.mood)
            .environment(\.pimpiPose, shot.pose)
            .environment(\.pimpiOutfit, shot.outfit)
            .frame(width: side, height: side)
            .scaleEffect(x: shot.pimpi.flips ? -1 : 1, y: 1)
            .rotationEffect(.degrees(shot.pimpi.isLeft ? -5 : 5))
            .position(x: x, y: y)
    }

    private func stickerView(_ sticker: StoreShot.Sticker, layout: StoreLayout) -> some View {
        let crop = sticker.crop
        let cg = screen.cgImage?.cropping(to: CGRect(x: crop.minX * screen.size.width * screen.scale,
                                                      y: crop.minY * screen.size.height * screen.scale,
                                                      width: crop.width * screen.size.width * screen.scale,
                                                      height: crop.height * screen.size.height * screen.scale))
        let width = layout.size.width * sticker.width
        let height = width * (crop.height * screen.size.height) / (crop.width * screen.size.width)
        let border = layout.size.width * 0.014
        let center = CGPoint(x: layout.size.width * sticker.at.x, y: layout.phone.minY + layout.phone.height * sticker.at.y)
        return Group {
            if let cg {
                Image(decorative: cg, scale: 1)
                    .resizable()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: border * 2.2, style: .continuous))
                    .padding(border)
                    .background(.white, in: RoundedRectangle(cornerRadius: border * 3.2, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: border * 1.6, y: border * 1.2)
                    .rotationEffect(.degrees(sticker.tilt))
                    .position(center)
            }
        }
    }

    // MARK: Dump

    @MainActor
    static func dump(into folder: String, source: String) {
        let out = URL(fileURLWithPath: folder)
        for canvas in StoreCanvas.allCases {
            let set = StoreShot.set(for: canvas)
            for (index, shot) in set.enumerated() {
                let look = shot.isNight ? "dark" : "light"
                let path = "\(source)/\(canvas.device)/\(look)/\(shot.screen).png"
                guard let screen = UIImage(contentsOfFile: path) else { continue }
                let renderer = ImageRenderer(content: StoreShotArt(shot: shot, index: index, canvas: canvas, screen: screen))
                renderer.scale = canvas.pixels.width / canvas.points.width
                renderer.isOpaque = true
                let dir = out.appendingPathComponent(canvas.rawValue)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let name = String(format: "%02d-%@.png", index + 1, shot.screen)
                try? renderer.uiImage?.pngData()?.write(to: dir.appendingPathComponent(name))
            }
        }
    }
}

// MARK: - The set

struct StoreShot {
    struct Sticker {
        /// The part of the screen lifted off, in unit space.
        let crop: CGRect
        /// Width as a fraction of the canvas.
        let width: CGFloat
        /// Centre: x as a fraction of the canvas width, y as a fraction of the phone's height.
        let at: CGPoint
        let tilt: Double
    }

    struct PimpiSpot {
        var isLeft = true
        var scale: CGFloat = 1
        /// How far above the phone's bottom edge Pimpi stands, as a fraction of the canvas height.
        var lift: CGFloat = 0
        var flips = false
        var isBehindPhone = false
    }

    let screen: String
    let headline: String
    let line: String
    /// 0: sunrise … 1: night.
    let time: Double
    var mood: Pimpi.Mood = .happy
    var pose: PimpiPose?
    var outfit: PimpiOutfit?
    var pimpi = PimpiSpot()
    var sticker: Sticker?
    var tilt: Double = 0

    var isNight: Bool { time >= 1 }
    /// Where the sun sits across the sky.
    var sunX: Double { min(time / 0.9, 1) }

    /// Effort and fun, never skin results; no medical words (PLAN.md §15.1; `scripts/lint_copy.py` checks these).
    static func set(for canvas: StoreCanvas) -> [StoreShot] {
        var shots: [StoreShot] = [
            StoreShot(screen: "home", headline: "Meet Pimpi", line: "your tiny skin-care buddy", time: 0,
                      pose: .wave, pimpi: PimpiSpot(isLeft: false, scale: 1.1),
                      sticker: Sticker(crop: CGRect(x: 0.05, y: 0.082, width: 0.5, height: 0.062), width: 0.5,
                                       at: CGPoint(x: 0.64, y: 0.1), tilt: 6), tilt: -2.5),
            StoreShot(screen: "scan", headline: "One quick scan\na day", line: "three angles, a few seconds", time: 0.14,
                      mood: .excited, pimpi: PimpiSpot(isLeft: true), tilt: 2.5),
            StoreShot(screen: "result-3d", headline: "Every spot,\non the map", line: "tap a dot to see what it is",
                      time: 0.28, mood: .curious, pimpi: PimpiSpot(isLeft: false), tilt: -2.5),
            StoreShot(screen: "compare", headline: "See what\nchanged", line: "any two days, side by side", time: 0.42,
                      pose: .point, pimpi: PimpiSpot(isLeft: true),
                      sticker: Sticker(crop: CGRect(x: 0.04, y: 0.855, width: 0.69, height: 0.105), width: 0.56,
                                       at: CGPoint(x: 0.4, y: 0.6), tilt: -5), tilt: 2.5),
            StoreShot(screen: "product", headline: "Is it good\nfor me?", line: "ask about anything on your shelf",
                      time: 0.56, pose: .point, pimpi: PimpiSpot(isLeft: false, flips: true),
                      sticker: Sticker(crop: CGRect(x: 0.03, y: 0.388, width: 0.94, height: 0.175), width: 0.66,
                                       at: CGPoint(x: 0.42, y: 0.6), tilt: -4), tilt: -2.5),
            StoreShot(screen: "streaks", headline: "Show up,\nearn streaks", line: "points for effort, never for skin",
                      time: 0.7, mood: .excited, outfit: .partyHat, pimpi: PimpiSpot(isLeft: true),
                      sticker: Sticker(crop: CGRect(x: 0.05, y: 0.19, width: 0.88, height: 0.17), width: 0.62,
                                       at: CGPoint(x: 0.46, y: 0.66), tilt: -4), tilt: 2.5),
            StoreShot(screen: "school", headline: "Two-minute\nSkin School", line: "learn a little, earn a little",
                      time: 0.84, outfit: .beanie, pimpi: PimpiSpot(isLeft: false),
                      sticker: Sticker(crop: CGRect(x: 0.06, y: 0.432, width: 0.9, height: 0.09), width: 0.62,
                                       at: CGPoint(x: 0.42, y: 0.68), tilt: 4), tilt: -2.5),
            StoreShot(screen: "ob-promise", headline: "Private\nby default", line: "your photos stay yours", time: 1,
                      mood: .sleepy, pimpi: PimpiSpot(isLeft: false), tilt: -2.5),
        ]
        if canvas == .duoInner {
            // The inner display: the screens where its two panes matter most.
            shots = shots.filter { ["home", "result-3d", "compare", "streaks", "school", "ob-promise"].contains($0.screen) }
        }
        return shots
    }
}

// MARK: - Sizes

enum StoreCanvas: String, CaseIterable {
    /// iPhone, Dynamic Island medium (required) and large.
    case iphone1206 = "iphone-1206x2622", iphone1320 = "iphone-1320x2868"
    /// iPhone Duo: the outer display closed, upright; the inner display open, wide.
    case duoOuter = "duo-outer-1398x2034", duoInner = "duo-inner-2853x2007"

    var pixels: CGSize {
        switch self {
        case .iphone1206: CGSize(width: 1206, height: 2622)
        case .iphone1320: CGSize(width: 1320, height: 2868)
        case .duoOuter: CGSize(width: 1398, height: 2034)
        case .duoInner: CGSize(width: 2853, height: 2007)
        }
    }

    /// Laid out at the smaller iPhone's width, so both iPhone sizes are the same picture.
    var points: CGSize {
        switch self {
        case .iphone1320: CGSize(width: 1206, height: 1206 * pixels.height / pixels.width)
        default: pixels
        }
    }

    var device: String {
        switch self {
        case .iphone1206, .iphone1320: "iphone"
        case .duoOuter: "duo-outer"
        case .duoInner: "duo-inner"
        }
    }

    var phoneKind: StorePhone.Kind {
        switch self {
        case .iphone1206, .iphone1320: .island
        case .duoOuter: .plain
        case .duoInner: .unfolded
        }
    }

    var showsStickers: Bool { device == "iphone" }
    var sunScale: CGFloat { self == .duoInner ? 0.05 : 0.11 }

    func layout(screenAspect: CGFloat, in size: CGSize, pimpiIsLeft: Bool) -> StoreLayout {
        let w = size.width, h = size.height
        if self == .duoInner {
            let headline = CGRect(x: w * 0.1, y: h * 0.04, width: w * 0.8, height: h * 0.2)
            let phoneWidth = w * 0.74
            let phone = CGRect(x: (w - phoneWidth) / 2, y: h * 0.27, width: phoneWidth, height: phoneWidth * screenAspect + w * 0.02)
            return StoreLayout(size: size, headline: headline, headlineSize: h * 0.065, phone: phone,
                               hillCrest: h * 0.62, sunY: h * 0.16, pimpiSize: h * 0.26)
        }
        let headline = CGRect(x: w * 0.05, y: w * 0.07, width: w * 0.9, height: w * 0.34)
        let top = headline.maxY + w * 0.07
        let phoneWidth = min(w * 0.66, (h - top - w * 0.1) / screenAspect)
        let shift = w * 0.05 * (pimpiIsLeft ? 1 : -1)
        let phone = CGRect(x: (w - phoneWidth) / 2 + shift, y: top, width: phoneWidth,
                           height: phoneWidth * screenAspect + phoneWidth * 0.09)
        return StoreLayout(size: size, headline: headline, headlineSize: w * 0.098, phone: phone,
                           hillCrest: top + phone.height * 0.62, sunY: top + w * 0.1, pimpiSize: w * 0.36)
    }
}

struct StoreLayout {
    let size: CGSize
    let headline: CGRect
    let headlineSize: CGFloat
    let phone: CGRect
    let hillCrest: CGFloat
    let sunY: CGFloat
    let pimpiSize: CGFloat
}

// MARK: - Sky, hill, path, phone

/// The sky through the day: the app's own light palette at sunrise, warm at dusk, its dark palette at night.
struct StoreSky {
    let time: Double

    static let stars: [(x: CGFloat, y: CGFloat, z: CGFloat)] = [
        (0.08, 0.10, 0.008), (0.2, 0.32, 0.006), (0.86, 0.12, 0.009), (0.93, 0.4, 0.006), (0.7, 0.05, 0.005),
        (0.05, 0.55, 0.006), (0.95, 0.68, 0.007), (0.32, 0.06, 0.005),
    ]

    private var dusk: Double { min(max((time - 0.6) / 0.35, 0), 1) }
    private var night: Double { time >= 1 ? 1 : 0 }

    private func blend(_ day: RGB, _ evening: RGB, _ dark: RGB) -> Color {
        func mix(_ a: Int, _ b: Int, _ t: Double) -> Double { (Double(a) + (Double(b) - Double(a)) * t) / 255 }
        let (r1, g1, b1) = (mix(day.red, evening.red, dusk), mix(day.green, evening.green, dusk), mix(day.blue, evening.blue, dusk))
        let n = night
        return Color(red: r1 + (Double(dark.red) / 255 - r1) * n, green: g1 + (Double(dark.green) / 255 - g1) * n,
                     blue: b1 + (Double(dark.blue) / 255 - b1) * n)
    }

    var top: Color { blend(Palette.canvas.light, Palette.surfaceRaised.light, Palette.canvas.dark) }
    var hillFar: Color { blend(Palette.hillFar.light, Palette.hill.light, Palette.hillFar.dark) }
    var hill: Color { blend(Palette.hill.light, Palette.edgeOnHill.light, Palette.hill.dark) }
    var path: Color { blend(Palette.surface.light, Palette.surface.light, Palette.surfaceRaised.dark).opacity(0.85) }
    var sun: Color { blend(Palette.sun.light, Palette.outfitGold.light, Palette.sun.dark) }
    var ink: Color { night > 0 ? Palette.ink.dark.color : Palette.ink.light.color }
    var accent: Color { night > 0 ? Palette.pimpiHighlight.dark.color : Palette.pimpiEdge.light.color }
    /// Navy by day; at night the phone is violet, so it doesn't vanish into the sky.
    var bezel: Color { night > 0 ? Palette.hill.dark.color : Palette.ink.light.color }
    var bezelEdge: Color { night > 0 ? Palette.edge.dark.color : Palette.inkEdge.light.color }
}

private extension RGB {
    var color: Color { Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255) }
}

/// A gentle wave whose shape depends on the position across the whole set, so the hill runs on from shot to shot.
struct StoreHill: Shape {
    let globalX: CGFloat
    let width: CGFloat
    let crest: CGFloat
    let amplitude: CGFloat
    let phase: CGFloat

    func y(_ x: CGFloat) -> CGFloat {
        let t = (globalX + x) / (width * 1.3)
        return crest + amplitude * sin(t * 2 * .pi + phase) + amplitude * 0.5 * sin(t * 4.1 + phase * 2)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for step in 0...80 {
            let x = rect.width * CGFloat(step) / 80
            path.addLine(to: CGPoint(x: x, y: y(x)))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Pimpi's dotted trail along the hill, continuous across the set.
struct StorePath: Shape {
    let globalX: CGFloat
    let width: CGFloat
    let crest: CGFloat
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 0...80 {
            let x = rect.width * CGFloat(step) / 80
            let t = (globalX + x) / (width * 0.9)
            let point = CGPoint(x: x, y: crest + amplitude * sin(t * 2 * .pi + 1.2))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

/// A chunky toy phone: navy body with the hard bottom edge every pressable thing in the app has.
struct StorePhone: View {
    enum Kind { case island, plain, unfolded }

    let screen: UIImage
    let kind: Kind
    let sky: StoreSky

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let bezel = w * (kind == .unfolded ? 0.012 : 0.03)
            let edge = w * (kind == .unfolded ? 0.012 : 0.03)
            let radius = w * (kind == .unfolded ? 0.05 : 0.15)
            let screenSize = CGSize(width: w - bezel * 2, height: proxy.size.height - bezel * 2 - edge)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(sky.bezelEdge)
                    .offset(y: edge)
                    .frame(height: proxy.size.height - edge)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(sky.bezel)
                    .frame(height: proxy.size.height - edge)
                Image(uiImage: screen)
                    .resizable()
                    .frame(width: screenSize.width, height: screenSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: radius - bezel, style: .continuous))
                    .padding(.top, bezel)
                if kind == .island {
                    Capsule().fill(.black)
                        .frame(width: screenSize.width * 0.31, height: screenSize.width * 0.092)
                        .padding(.top, bezel + screenSize.width * 0.027)
                }
                if kind == .unfolded {
                    // The fold: a soft crease down the middle.
                    LinearGradient(colors: [.clear, .black.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.03, height: screenSize.height)
                        .padding(.top, bezel)
                }
            }
        }
    }
}
#endif
