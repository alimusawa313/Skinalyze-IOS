#if DEBUG
import SwiftUI
import SkinalyzeKit

/// The App Store's product page header (21:9) and search result (3:2), as stills and seamless loops, in the same
/// "Pimpi's Place" world as the screenshots (`StoreShotArt`). Apple: one clear idea, key art inside the safe area,
/// work silently, loop seamlessly. Every moving part is a function of the loop time `t` (0 ..< 1) that returns to
/// where it started: the far hills scroll whole wavelengths, clouds wrap off screen, Pimpi hops a whole number of times.
///
/// `-storeHeroDump <out folder> -storeShotsSource <raw folder>` writes `header.png`, `search.png` and JPEG frames for
/// the two videos (`scripts/store-hero.sh` encodes them). Debug builds only.
enum StoreHero {
    static let fps = 30
    static let headerSeconds = 8
    static let searchSeconds = 9

    /// Real screens, and the piece of each that lifts off as a sticker.
    struct Moment {
        let screen: String
        let crop: CGRect
    }

    static let moments: [Moment] = [
        Moment(screen: "home", crop: CGRect(x: 0.05, y: 0.082, width: 0.5, height: 0.062)),
        Moment(screen: "scan", crop: CGRect(x: 0.15, y: 0.21, width: 0.7, height: 0.42)),
        Moment(screen: "compare", crop: CGRect(x: 0.04, y: 0.855, width: 0.69, height: 0.105)),
        Moment(screen: "product", crop: CGRect(x: 0.03, y: 0.388, width: 0.62, height: 0.055)),
        Moment(screen: "streaks", crop: CGRect(x: 0.05, y: 0.19, width: 0.88, height: 0.17)),
        Moment(screen: "school", crop: CGRect(x: 0.06, y: 0.432, width: 0.9, height: 0.09)),
    ]

    @MainActor
    static func dump(into folder: String, source: String) async {
        let out = URL(fileURLWithPath: folder)
        func image(_ device: String, _ name: String) -> UIImage? {
            UIImage(contentsOfFile: "\(source)/\(device)/light/\(name).png")
        }
        var screens: [String: UIImage] = [:]
        for moment in moments { screens[moment.screen] = image("iphone", moment.screen) }
        let duo = image("duo-inner", "school")
        guard screens.count == moments.count else { return }

        let header = StoreHeader(screens: screens, duo: duo)
        let search = StoreSearch(screens: screens)
        for name in ["header-frames", "search-frames"] {
            try? FileManager.default.createDirectory(at: out.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        write(header.at(0), scale: 1, to: out.appendingPathComponent("header.png"))
        write(search.at(StoreSearch.stillTime), scale: 2, to: out.appendingPathComponent("search.png"))
        let headerFrames = fps * headerSeconds, searchFrames = fps * searchSeconds
        for frame in 0..<searchFrames {
            write(search.at(Double(frame) / Double(searchFrames)), scale: 1,
                  to: out.appendingPathComponent(String(format: "search-frames/f%04d.jpg", frame)))
            await Task.yield()
        }
        for frame in 0..<headerFrames {
            write(header.at(Double(frame) / Double(headerFrames)), scale: 1,
                  to: out.appendingPathComponent(String(format: "header-frames/f%04d.jpg", frame)))
            await Task.yield()
        }
        try? Data("done".utf8).write(to: out.appendingPathComponent("done.txt"))
    }

    @MainActor
    private static func write(_ view: some View, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return }
        let data = url.pathExtension == "png" ? image.pngData() : image.jpegData(compressionQuality: 0.93)
        try? data?.write(to: url)
    }
}

// MARK: - Header (21:9, 3840 × 1646; key art inside 1646 × 661 at 1097, 493)

struct StoreHeader {
    let screens: [String: UIImage]
    let duo: UIImage?

    static let size = CGSize(width: 3840, height: 1646)

    func at(_ t: Double) -> some View {
        let w = Self.size.width, h = Self.size.height
        return ZStack(alignment: .topLeading) {
            HeroWorld(t: t, size: Self.size, sun: CGPoint(x: 3020, y: 330), sunRadius: 150, farCrest: 1010,
                      midCrest: 1170, groundEdge: 1470, groundCrest: 1230, trailEdge: 1580, trailCrest: 1330)
            // Phones standing behind the near hill, either side of Pimpi.
            if let home = screens["home"] {
                HeroPhone(screen: home, kind: .island)
                    .frame(width: 560, height: 560 * home.size.height / home.size.width + 50)
                    .rotationEffect(.degrees(-7))
                    .position(x: 700, y: 860)
            }
            if let duo {
                HeroPhone(screen: duo, kind: .unfolded)
                    .frame(width: 1120, height: 1120 * duo.size.height / duo.size.width + 26)
                    .rotationEffect(.degrees(6))
                    .position(x: 3180, y: 900)
            }
            HeroGround(size: Self.size, edge: 1470, crest: 1230)
            // Stickers of real moments, floating in place around Pimpi.
            sticker("home", width: 470, at: CGPoint(x: 1390, y: 600), tilt: -8, t: t, offset: 0)
            sticker("compare", width: 430, at: CGPoint(x: 1360, y: 1010), tilt: 5, t: t, offset: 0.33)
            sticker("product", width: 470, at: CGPoint(x: 2470, y: 1000), tilt: -5, t: t, offset: 0.66)
            HeroBubble(text: "hi!", size: 92)
                .position(x: 2260, y: 560 + 10 * sin(2 * .pi * t))
            HeroPimpi(t: t, hops: 2, size: 640, ground: CGPoint(x: w / 2, y: 1215), pose: .wave, mood: .happy)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipped()
    }

    private func sticker(_ screen: String, width: CGFloat, at center: CGPoint, tilt: Double, t: Double, offset: Double)
        -> some View {
        let wave = sin(2 * .pi * (t + offset))
        return Group {
            if let image = screens[screen], let moment = StoreHero.moments.first(where: { $0.screen == screen }) {
                HeroSticker(image: image, crop: moment.crop, width: width)
                    .rotationEffect(.degrees(tilt + 2 * wave))
                    .position(x: center.x, y: center.y + 16 * wave)
            }
        }
    }
}

// MARK: - Search result (3:2; laid out at 1920 × 1280, key art inside 1084 × 515 at 418, 382)

struct StoreSearch {
    let screens: [String: UIImage]

    static let size = CGSize(width: 1920, height: 1280)
    /// The still: the scan (the second slot), its sticker fully out.
    static let stillTime = 1.3 / Double(StoreHero.moments.count)

    func at(_ t: Double) -> some View {
        let w = Self.size.width, h = Self.size.height
        let count = StoreHero.moments.count
        let position = t * Double(count)
        let index = Int(position) % count
        let local = position - Double(Int(position))
        let current = StoreHero.moments[index]
        let next = StoreHero.moments[(index + 1) % count]
        // The last fifth of each slot slides the next screen up.
        let slide = HeroEase.inOut(max(0, (local - 0.8) / 0.2))
        return ZStack(alignment: .topLeading) {
            HeroWorld(t: t, size: Self.size, sun: CGPoint(x: 230, y: 190), sunRadius: 85, farCrest: 760, midCrest: 880,
                      groundEdge: 1150, groundCrest: 930, trailEdge: 1230, trailCrest: 1010)
            if let now = screens[current.screen], let after = screens[next.screen] {
                let phoneWidth: CGFloat = 520
                HeroPhone(screen: now, kind: .island, next: after, slide: slide)
                    .frame(width: phoneWidth, height: phoneWidth * now.size.height / now.size.width + 46)
                    .rotationEffect(.degrees(4))
                    .position(x: 1230, y: 160 + (phoneWidth * now.size.height / now.size.width + 46) / 2)
            }
            HeroGround(size: Self.size, edge: 1150, crest: 930)
            Text("Your tiny\nskin-care buddy")
                .font(.system(size: 68, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink.light.heroColor)
                .lineSpacing(-8)
                .fixedSize()
                .position(x: 700, y: 470)
            stickerPop(current, local: local)
            HeroPimpi(t: local, hops: 1, size: 330, ground: CGPoint(x: 640, y: 905), pose: index == 0 ? .wave : .point,
                      mood: index == 1 ? .excited : .happy, hopWindow: 0.3)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipped()
    }

    /// Each screen's sticker pops out of the phone, then fades as the next screen arrives.
    private func stickerPop(_ moment: StoreHero.Moment, local: Double) -> some View {
        let appear = HeroEase.outBack(min(max((local - 0.05) / 0.18, 0), 1))
        let fade = 1 - min(max((local - 0.8) / 0.12, 0), 1)
        let width: CGFloat = moment.screen == "scan" ? 230 : 360
        return Group {
            if let image = screens[moment.screen] {
                HeroSticker(image: image, crop: moment.crop, width: width)
                    .scaleEffect(0.6 + 0.4 * appear)
                    .rotationEffect(.degrees(-7 + 3 * (1 - appear)))
                    .opacity(min(appear * 1.4, 1) * fade)
                    .position(x: moment.screen == "scan" ? 1020 : 1000, y: moment.screen == "scan" ? 770 : 700)
            }
        }
    }
}

// MARK: - Pieces

enum HeroEase {
    static func inOut(_ x: Double) -> Double { x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
    static func outBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

private extension RGB {
    var heroColor: Color { Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255) }
}

/// Sky, sun, drifting clouds, two scrolling far hills and a dotted trail on the near hill.
struct HeroWorld: View {
    let t: Double
    let size: CGSize
    let sun: CGPoint
    let sunRadius: CGFloat
    let farCrest: CGFloat
    let midCrest: CGFloat
    let groundEdge: CGFloat
    let groundCrest: CGFloat
    let trailEdge: CGFloat
    let trailCrest: CGFloat

    var body: some View {
        let w = size.width
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.canvas.light.heroColor, Palette.surfaceRaised.light.heroColor],
                           startPoint: .top, endPoint: .bottom)
            let glow = 1 + 0.06 * sin(2 * .pi * t * 2)
            Circle().fill(Palette.sun.light.heroColor.opacity(0.3))
                .frame(width: sunRadius * 3 * glow, height: sunRadius * 3 * glow).position(sun)
            Circle().fill(Palette.sun.light.heroColor).frame(width: sunRadius * 2, height: sunRadius * 2).position(sun)
            ForEach(0..<3) { index in cloud(index) }
            // One wavelength per loop each: the far hill (more, shorter waves) drifts slower than the near one.
            LoopHill(crest: farCrest, amplitude: w * 0.012, waves: Int(w / 640), shift: t, phase: 0.8)
                .fill(Palette.hillFar.light.heroColor)
            LoopHill(crest: midCrest, amplitude: w * 0.014, waves: Int(w / 960), shift: t, phase: 0)
                .fill(Palette.hill.light.heroColor)
        }
        .frame(width: size.width, height: size.height)
    }

    /// A puffy cloud bobbing gently in place.
    private func cloud(_ index: Int) -> some View {
        let w = size.width
        let cloudWidth = w * 0.11
        let drift = w * 0.012 * sin(2 * .pi * (t + Double(index) * 0.3))
        let x = [0.16, 0.5, 0.84][index] * w + drift
        let y = [0.14, 0.09, 0.2][index] * size.height
        return HeroCloud().fill(Palette.surface.light.heroColor.opacity(0.92))
            .frame(width: cloudWidth, height: cloudWidth * 0.42)
            .position(x: x, y: y)
    }
}

/// The near hill everything stands on, with Pimpi's dotted trail.
struct HeroGround: View {
    let size: CGSize
    let edge: CGFloat
    let crest: CGFloat

    var body: some View {
        let w = size.width
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: edge))
                path.addQuadCurve(to: CGPoint(x: w, y: edge), control: CGPoint(x: w / 2, y: crest * 2 - edge))
                path.addLine(to: CGPoint(x: w, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
            .fill(Palette.edgeOnHill.light.heroColor)
            Path { path in
                let drop = (size.height - crest) * 0.32
                path.move(to: CGPoint(x: -20, y: edge + drop))
                path.addQuadCurve(to: CGPoint(x: w + 20, y: edge + drop),
                                  control: CGPoint(x: w / 2, y: crest * 2 - edge + drop))
            }
            .stroke(Palette.surface.light.heroColor.opacity(0.85),
                    style: StrokeStyle(lineWidth: w * 0.006, lineCap: .round, dash: [1, w * 0.018]))
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// A hill whose waves fit the width exactly, so scrolling by whole wavelengths loops without a seam.
struct LoopHill: Shape {
    let crest: CGFloat
    let amplitude: CGFloat
    let waves: Int
    /// Whole numbers of wavelengths scrolled per loop (t × an integer).
    let shift: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        let steps = 160
        for step in 0...steps {
            let x = rect.width * CGFloat(step) / CGFloat(steps)
            let u = Double(waves) * Double(x / rect.width) + shift
            let y = crest + amplitude * CGFloat(sin(2 * .pi * u + phase) + 0.35 * sin(4 * .pi * u + 2 * phase))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct HeroCloud: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        for (x, y, r) in [(0.22, 0.62, 0.38), (0.45, 0.42, 0.5), (0.7, 0.58, 0.4), (0.85, 0.7, 0.28)] {
            path.addEllipse(in: CGRect(x: rect.width * x - h * r, y: h * y - h * r, width: h * r * 2, height: h * r * 2))
        }
        path.addRoundedRect(in: CGRect(x: rect.width * 0.12, y: h * 0.55, width: rect.width * 0.8, height: h * 0.45),
                            cornerSize: CGSize(width: h * 0.22, height: h * 0.22))
        return path
    }
}

/// Pimpi hopping in place: `hops` whole hops per loop (or one hop at the start of each slot, within `hopWindow`).
struct HeroPimpi: View {
    let t: Double
    let hops: Int
    let size: CGFloat
    let ground: CGPoint
    let pose: PimpiPose
    let mood: Pimpi.Mood
    var hopWindow: Double = 1

    var body: some View {
        let phase = min(t / hopWindow, 1)
        let arc = abs(sin(.pi * Double(hops) * phase))
        let lift = size * 0.12 * arc
        // A little squash right at the ground.
        let squash = 1 - 0.07 * pow(1 - arc, 8)
        Pimpi(mood: mood)
            .environment(\.pimpiPose, pose)
            .frame(width: size, height: size)
            .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
            .position(x: ground.x, y: ground.y - size / 2 - lift)
    }
}

struct HeroBubble: View {
    let text: String
    let size: CGFloat

    var body: some View {
        Text(text)
            .font(.custom(Handwriting.fontName, fixedSize: size))
            .foregroundStyle(Palette.ink.light.heroColor)
            .padding(.horizontal, size * 0.45)
            .padding(.vertical, size * 0.2)
            .background(Palette.surface.light.heroColor, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: size * 0.12, y: size * 0.06)
            .rotationEffect(.degrees(-4))
    }
}

/// A piece of a real screen with a white sticker edge.
struct HeroSticker: View {
    let image: UIImage
    let crop: CGRect
    let width: CGFloat

    var body: some View {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let height = width * (crop.height * pixels.height) / (crop.width * pixels.width)
        let border = width * 0.035
        if let cg = image.cgImage?.cropping(to: CGRect(x: crop.minX * pixels.width, y: crop.minY * pixels.height,
                                                        width: crop.width * pixels.width, height: crop.height * pixels.height)) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: border * 2.2, style: .continuous))
                .padding(border)
                .background(Palette.surface.light.heroColor, in: RoundedRectangle(cornerRadius: border * 3.2, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: border * 1.8, y: border * 1.2)
        }
    }
}

/// The chunky toy phone from the screenshots; optionally sliding the next screen up over this one.
struct HeroPhone: View {
    let screen: UIImage
    let kind: StorePhone.Kind
    var next: UIImage?
    var slide: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let unfolded = kind == .unfolded
            let bezel = w * (unfolded ? 0.012 : 0.03)
            let edge = w * (unfolded ? 0.012 : 0.03)
            let radius = w * (unfolded ? 0.05 : 0.15)
            let screenSize = CGSize(width: w - bezel * 2, height: proxy.size.height - bezel * 2 - edge)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.inkEdge.light.heroColor)
                    .offset(y: edge)
                    .frame(height: proxy.size.height - edge)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ink.light.heroColor)
                    .frame(height: proxy.size.height - edge)
                ZStack(alignment: .top) {
                    Image(uiImage: screen).resizable()
                        .frame(width: screenSize.width, height: screenSize.height)
                        .offset(y: -screenSize.height * 0.25 * slide)
                    if let next, slide > 0 {
                        Image(uiImage: next).resizable()
                            .frame(width: screenSize.width, height: screenSize.height)
                            .offset(y: screenSize.height * (1 - slide))
                    }
                }
                .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: radius - bezel, style: .continuous))
                .padding(.top, bezel)
                if kind == .island {
                    Capsule().fill(.black)
                        .frame(width: screenSize.width * 0.31, height: screenSize.width * 0.092)
                        .padding(.top, bezel + screenSize.width * 0.027)
                }
            }
        }
    }
}
#endif
