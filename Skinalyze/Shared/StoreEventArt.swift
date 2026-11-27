#if DEBUG
import SwiftUI
import SkinalyzeKit

/// The App Store in-app event films: three seamless loops, each as the event card (16:9, 1920 × 1080) and the event
/// details page (9:16, 1080 × 1920), in the same "Pimpi's Place" world as the product page header (`StoreHero`).
/// Apple: no text or logos in event media (the badge, name and description are laid over the bottom with Apple's own
/// gradient), and loop seamlessly. So the key art sits in the top two-thirds, the near hill fills the bottom, and every
/// moving part is a function of the loop time `t` (0 ..< 1) that returns to where it started.
///
/// - Meet Pimpi (Major Update): Pimpi in a party hat waving hello in a shower of confetti, between two phones.
/// - Your Skin Wrapped (Special Event): a night of fireworks; a gift box opens and the year's stat cards fan out.
/// - 30 Days of Sunscreen (Challenge): Pimpi in sunglasses under a big sun, a 30-day card filling in, then a cheer.
///
/// `-storeEventsDump <out folder> -storeShotsSource <raw folder>` writes `<event>-<card|details>.png` stills and JPEG
/// frames for each video (`scripts/store-events.sh` encodes them). `-storeEventsOnly <event>` renders one event;
/// `-storeEventsStillsOnly YES` skips the frames. Debug builds only.
enum StoreEvents {
    static let fps = 30
    static let seconds = 10

    enum Event: String, CaseIterable {
        case meetPimpi = "meet-pimpi"
        case wrapped
        case sunscreen
        case morningEvening = "morning-evening"
        case handsOff = "hands-off"
        case summerSunscreen = "summer-sunscreen"
        case wrappedQ1 = "wrapped-q1"
        case wrappedQ2 = "wrapped-q2"
        case wrappedQ3 = "wrapped-q3"

        /// The frame used for the still: the moment that reads best on its own.
        var stillTime: Double {
            switch self {
            case .meetPimpi: 0.12
            case .wrapped, .wrappedQ1, .wrappedQ2, .wrappedQ3: 0.5
            case .sunscreen, .summerSunscreen, .handsOff: 0.8
            case .morningEvening: 0.6
            }
        }

        var wrappedLook: WrappedLook? {
            switch self {
            case .wrapped:
                WrappedLook(sky: .fireworks, outfit: .crown,
                            stats: [("flame.fill", Palette.signal, "42"), ("sun.max.fill", Palette.sun, "30"),
                                    ("sparkles", Palette.outfitGold, "128")])
            case .wrappedQ1:
                WrappedLook(sky: .petals, outfit: .flower,
                            stats: [("flame.fill", Palette.signal, "18"), ("graduationcap.fill", Palette.positive, "9"),
                                    ("star.fill", Palette.outfitGold, "24")])
            case .wrappedQ2:
                WrappedLook(sky: .sunshine, outfit: .sunglasses,
                            stats: [("sun.max.fill", Palette.sun, "61"), ("star.fill", Palette.outfitGold, "33"),
                                    ("sparkles", Palette.outfitGold, "410")])
            case .wrappedQ3:
                WrappedLook(sky: .leaves, outfit: .beanie,
                            stats: [("flame.fill", Palette.signal, "27"), ("graduationcap.fill", Palette.positive, "12"),
                                    ("sparkles", Palette.outfitGold, "356")])
            default: nil
            }
        }

        var challengeLook: ChallengeLook? {
            switch self {
            case .sunscreen: ChallengeLook(outfit: .sunglasses, prop: .tube, sky: .sun, confetti: false)
            case .summerSunscreen: ChallengeLook(outfit: .flower, prop: .tube, sky: .sun, confetti: true)
            case .morningEvening: ChallengeLook(outfit: .scarf, prop: .jar, sky: .sunAndMoon, confetti: false)
            case .handsOff: ChallengeLook(outfit: .bow, prop: .hand, sky: .sun, confetti: false)
            default: nil
            }
        }
    }

    static let formats: [(name: String, size: CGSize)] = [
        ("card", CGSize(width: 1920, height: 1080)),
        ("details", CGSize(width: 1080, height: 1920)),
    ]

    @MainActor
    static func dump(into folder: String, source: String) async {
        let out = URL(fileURLWithPath: folder)
        var screens: [String: UIImage] = [:]
        for name in ["home", "scan", "streaks"] {
            screens[name] = UIImage(contentsOfFile: "\(source)/iphone/light/\(name).png")
        }
        let defaults = UserDefaults.standard
        let only = defaults.string(forKey: "storeEventsOnly")
        let stillsOnly = defaults.bool(forKey: "storeEventsStillsOnly")
        let frames = fps * seconds
        for event in Event.allCases where only == nil || only == event.rawValue {
            for format in formats {
                let scene = EventScene(event: event, size: format.size, screens: screens)
                let base = "\(event.rawValue)-\(format.name)"
                write(scene.at(event.stillTime), to: out.appendingPathComponent("\(base).png"))
                if stillsOnly { continue }
                let dir = out.appendingPathComponent("\(base)-frames")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for frame in 0..<frames {
                    write(scene.at(Double(frame) / Double(frames)),
                          to: dir.appendingPathComponent(String(format: "f%04d.jpg", frame)))
                    await Task.yield()
                }
            }
        }
        try? Data("done".utf8).write(to: out.appendingPathComponent("done.txt"))
    }

    @MainActor
    private static func write(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return }
        let data = url.pathExtension == "png" ? image.pngData() : image.jpegData(compressionQuality: 0.93)
        try? data?.write(to: url)
    }
}

// MARK: - The scene

struct EventScene {
    let event: StoreEvents.Event
    let size: CGSize
    let screens: [String: UIImage]

    var wide: Bool { size.width > size.height }
    /// The short side: pieces are sized from it, so the two formats keep the same proportions.
    var u: CGFloat { min(size.width, size.height) }
    var w: CGFloat { size.width }
    var h: CGFloat { size.height }

    /// The near hill: where its edge meets the sides, and its crest in the middle (where Pimpi stands).
    var groundEdge: CGFloat { wide ? h * 0.97 : h * 0.8 }
    var groundCrest: CGFloat { wide ? h * 0.79 : h * 0.66 }

    /// The near hill's top at `x` (the quadratic `HeroGround` draws).
    func groundY(at x: CGFloat) -> CGFloat {
        let s = x / w
        let control = groundCrest * 2 - groundEdge
        let k = 2 * s * (1 - s)
        return groundEdge * (1 - k) + control * k
    }

    func at(_ t: Double) -> some View {
        ZStack(alignment: .topLeading) {
            if let look = event.wrappedLook {
                wrapped(t, look: look)
            } else if let look = event.challengeLook {
                challenge(t, look: look)
            } else {
                meetPimpi(t)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipped()
    }

    func world(_ t: Double, sun: CGPoint, sunRadius: CGFloat, night: Bool = false, clouds: Bool = true) -> some View {
        HeroWorld(t: t, size: size, sun: sun, sunRadius: sunRadius,
                  farCrest: wide ? h * 0.57 : h * 0.5, midCrest: wide ? h * 0.66 : h * 0.57,
                  groundEdge: groundEdge, groundCrest: groundCrest, trailEdge: groundEdge, trailCrest: groundCrest,
                  night: night, clouds: clouds)
    }

    func pimpi(_ t: Double, hops: Int, size side: CGFloat, x: CGFloat, outfit: PimpiOutfit, pose: PimpiPose,
               mood: Pimpi.Mood, sway: Double = 0) -> some View {
        HeroPimpi(t: t, hops: hops, size: side, ground: CGPoint(x: x, y: groundY(at: x) + side * 0.03), pose: pose,
                  mood: mood, sway: sway)
            .environment(\.pimpiOutfit, outfit)
    }

    /// A gentle side-to-side rock, a whole number of times per loop.
    static func sway(_ t: Double, rocks: Int = 4) -> Double { 4 * sin(2 * .pi * Double(rocks) * t) }

    func sticker(_ screen: String, width: CGFloat, at center: CGPoint, tilt: Double, t: Double, offset: Double)
        -> some View {
        let wave = sin(2 * .pi * (t + offset))
        return Group {
            if let image = screens[screen], let moment = StoreHero.moments.first(where: { $0.screen == screen }) {
                HeroSticker(image: image, crop: moment.crop, width: width)
                    .rotationEffect(.degrees(tilt + 2 * wave))
                    .position(x: center.x, y: center.y + u * 0.012 * wave)
            }
        }
    }

    func phone(_ screen: String, width: CGFloat, at center: CGPoint, tilt: Double) -> some View {
        Group {
            if let image = screens[screen] {
                HeroPhone(screen: image, kind: .island)
                    .frame(width: width, height: width * image.size.height / image.size.width + width * 0.09)
                    .rotationEffect(.degrees(tilt))
                    .position(center)
            }
        }
    }
}

// MARK: - Meet Pimpi

extension EventScene {
    func meetPimpi(_ t: Double) -> some View {
        let side = u * (wide ? 0.46 : 0.42)
        return ZStack(alignment: .topLeading) {
            world(t, sun: wide ? CGPoint(x: w * 0.87, y: h * 0.17) : CGPoint(x: w * 0.82, y: h * 0.09),
                  sunRadius: u * 0.075, clouds: false)
            if wide {
                phone("home", width: w * 0.165, at: CGPoint(x: w * 0.17, y: h * 0.56), tilt: -8)
                phone("scan", width: w * 0.165, at: CGPoint(x: w * 0.83, y: h * 0.6), tilt: 7)
            } else {
                phone("home", width: w * 0.3, at: CGPoint(x: w * 0.16, y: h * 0.47), tilt: -9)
                phone("scan", width: w * 0.3, at: CGPoint(x: w * 0.84, y: h * 0.49), tilt: 8)
            }
            HeroGround(size: size, edge: groundEdge, crest: groundCrest)
            EventConfetti(t: t, size: size, count: wide ? 64 : 56)
            if wide {
                sticker("streaks", width: w * 0.2, at: CGPoint(x: w * 0.33, y: h * 0.27), tilt: -6, t: t, offset: 0)
            } else {
                sticker("streaks", width: w * 0.56, at: CGPoint(x: w * 0.42, y: h * 0.15), tilt: -5, t: t, offset: 0)
            }
            HeroBubble(text: "hi!", size: u * 0.07)
                .position(x: w * 0.5 + side * 0.52, y: groundCrest - side * 1.02 + u * 0.01 * sin(2 * .pi * t))
            pimpi(t, hops: 2, size: side, x: w * 0.5, outfit: .partyHat, pose: .wave, mood: .happy)
        }
    }
}

// MARK: - Your Skin Wrapped

/// What changes between the Wrapped events: what fills the season's sky, Pimpi's outfit, and the stat cards.
struct WrappedLook {
    enum Sky { case fireworks, petals, sunshine, leaves }

    let sky: Sky
    let outfit: PimpiOutfit
    let stats: [(String, ColorToken, String)]

    /// The year's Wrapped is a New Year's night; the quarters are daytime.
    var night: Bool { sky == .fireworks }
}

extension EventScene {
    /// The lid's opening: up early, held while the cards are out, back down before the loop ends.
    static func lidOpen(_ t: Double) -> Double {
        let up = HeroEase.inOut(min(max((t - 0.05) / 0.12, 0), 1))
        let down = HeroEase.inOut(min(max((t - 0.84) / 0.1, 0), 1))
        return up * (1 - down)
    }

    /// How far card `index` is out of the box (0 inside, 1 fanned out).
    static func cardOut(_ t: Double, index: Int) -> Double {
        let start = 0.15 + 0.05 * Double(index)
        let out = HeroEase.outBack(min(max((t - start) / 0.16, 0), 1))
        let back = HeroEase.inOut(min(max((t - (0.74 - 0.03 * Double(index))) / 0.1, 0), 1))
        return out * (1 - back)
    }

    func wrapped(_ t: Double, look: WrappedLook) -> some View {
        let side = u * (wide ? 0.4 : 0.42)
        let pimpiX = wide ? w * 0.3 : w * 0.28
        let boxWidth = wide ? w * 0.15 : w * 0.34
        let boxX = wide ? w * 0.6 : w * 0.7
        let boxBottom = groundY(at: boxX) + boxWidth * 0.04
        let boxTop = boxBottom - boxWidth * 0.72
        let cardWidth = wide ? w * 0.13 : w * 0.27
        // Where each card ends up: a fan over the box (wide), or a row across the sky (tall).
        let targets: [(CGPoint, Double)] = wide
            ? [(CGPoint(x: w * 0.44, y: h * 0.33), -10), (CGPoint(x: w * 0.6, y: h * 0.25), 0),
               (CGPoint(x: w * 0.76, y: h * 0.33), 10)]
            : [(CGPoint(x: w * 0.2, y: h * 0.3), -9), (CGPoint(x: w * 0.5, y: h * 0.24), 0),
               (CGPoint(x: w * 0.8, y: h * 0.3), 9)]
        let stats = look.stats
        let hop = min(max((t - 0.15) / 0.3, 0), 1)
        return ZStack(alignment: .topLeading) {
            wrappedSky(t, look: look)
            HeroGround(size: size, edge: groundEdge, crest: groundCrest, night: look.night)
            // Petals and leaves fall behind the cards, so they never cover a number.
            if look.sky == .petals || look.sky == .leaves {
                EventConfetti(t: t, size: size, count: wide ? 46 : 40, colors: look.sky == .petals
                    ? [Palette.pimpiBody, Palette.surface, Palette.pimpiCheek, Palette.pimpiBody]
                    : [Palette.outfitGold, Palette.signal, Palette.outfitRed, Palette.caution],
                    piece: look.sky == .petals ? .petal : .leaf)
            }
            ForEach(0..<3, id: \.self) { index in
                let out = Self.cardOut(t, index: index)
                let (target, tilt) = targets[index]
                let from = CGPoint(x: boxX, y: boxTop + boxWidth * 0.1)
                EventStatCard(symbol: stats[index].0, tint: stats[index].1, value: stats[index].2, width: cardWidth)
                    .scaleEffect(0.3 + 0.7 * out)
                    .rotationEffect(.degrees(tilt * out + 2 * sin(2 * .pi * (t + Double(index) * 0.3)) * out))
                    .opacity(min(out * 3, 1))
                    .position(x: from.x + (target.x - from.x) * out, y: from.y + (target.y - from.y) * out)
            }
            EventGiftBox(width: boxWidth, open: Self.lidOpen(t))
                .position(x: boxX, y: boxBottom - boxWidth * 0.36)
            pimpi(hop, hops: 2, size: side, x: pimpiX, outfit: look.outfit, pose: .point,
                  mood: hop > 0 && hop < 1 ? .excited : .happy, sway: Self.sway(t))
        }
    }
}

extension EventScene {
    @ViewBuilder func wrappedSky(_ t: Double, look: WrappedLook) -> some View {
        let corner = wide ? CGPoint(x: w * 0.1, y: h * 0.14) : CGPoint(x: w * 0.14, y: h * 0.07)
        switch look.sky {
        case .fireworks:
            world(t, sun: corner, sunRadius: u * 0.05, night: true, clouds: false)
            EventStars(t: t, size: size, count: wide ? 60 : 54, band: wide ? 0.55 : 0.48)
            EventFireworks(t: t, size: size, bursts: wide
                ? [(CGPoint(x: w * 0.2, y: h * 0.24), 0.02), (CGPoint(x: w * 0.88, y: h * 0.2), 0.34),
                   (CGPoint(x: w * 0.5, y: h * 0.14), 0.66)]
                : [(CGPoint(x: w * 0.78, y: h * 0.1), 0.02), (CGPoint(x: w * 0.24, y: h * 0.1), 0.34),
                   (CGPoint(x: w * 0.55, y: h * 0.42), 0.66)])
        case .sunshine:
            world(t, sun: CGPoint(x: -w, y: -h), sunRadius: 0)
            EventBigSun(t: t, radius: u * (wide ? 0.1 : 0.09)).position(wide ? CGPoint(x: w * 0.14, y: h * 0.22) : CGPoint(x: w * 0.2, y: h * 0.1))
        case .petals, .leaves:
            world(t, sun: corner, sunRadius: u * 0.06)
        }
    }
}

// MARK: - 30-day challenges

/// What changes between the challenge events: Pimpi's outfit, the prop beside it, and the sky.
struct ChallengeLook {
    enum Prop { case tube, jar, hand }
    /// `sunAndMoon` turns the day to night and back once a loop: one step in the morning, one in the evening.
    enum Sky { case sun, sunAndMoon }

    let outfit: PimpiOutfit
    let prop: Prop
    let sky: Sky
    /// A light shower of confetti (the summer edition).
    let confetti: Bool
}

extension EventScene {
    /// Days ticked so far: one every few frames until all thirty are in, then held for the cheer.
    static func daysDone(_ t: Double) -> Double { min(t / 0.7, 1) * Double(ChallengeEngine.goalDays) }

    func challenge(_ t: Double, look: ChallengeLook) -> some View {
        let side = u * (wide ? 0.4 : 0.38)
        let sunCenter = wide ? CGPoint(x: w * 0.2, y: h * 0.24) : CGPoint(x: w * 0.5, y: h * 0.1)
        let sunRadius = u * (wide ? 0.12 : 0.11)
        let cardCenter = wide ? CGPoint(x: w * 0.74, y: h * 0.42) : CGPoint(x: w * 0.5, y: h * 0.34)
        let cardWidth = wide ? w * 0.3 : w * 0.66
        let pimpiX = wide ? w * 0.45 : w * 0.64
        let tubeX = wide ? w * 0.3 : w * 0.3
        let cheer = min(max((t - 0.72) / 0.18, 0), 1)
        // The ticks clear in the last tenth, so the loop starts on an empty card again.
        let clear = min(max((t - 0.9) / 0.08, 0), 1)
        // Morning and evening: night falls by mid-loop and lifts again by the end.
        let night = look.sky == .sunAndMoon ? (1 - cos(2 * .pi * t)) / 2 : 0
        let propWidth = u * (wide ? 0.11 : 0.12)
        return ZStack(alignment: .topLeading) {
            world(t, sun: CGPoint(x: -w, y: -h), sunRadius: 0)
            if night > 0 {
                world(t, sun: CGPoint(x: -w, y: -h), sunRadius: 0, night: true, clouds: false).opacity(night)
                EventStars(t: t, size: size, count: wide ? 44 : 40, band: wide ? 0.5 : 0.4).opacity(night)
                EventMoon(radius: sunRadius * 0.8).position(sunCenter).opacity(night)
            }
            EventBigSun(t: t, radius: sunRadius).position(sunCenter).opacity(1 - night)
            HeroGround(size: size, edge: groundEdge, crest: groundCrest)
            if night > 0 {
                HeroGround(size: size, edge: groundEdge, crest: groundCrest, night: true).opacity(night)
            }
            if look.confetti {
                EventConfetti(t: t, size: size, count: wide ? 30 : 26)
            }
            EventDayCard(done: Self.daysDone(t), cheer: cheer, clear: clear, width: cardWidth)
                .rotationEffect(.degrees(wide ? 3 : 2))
                .position(cardCenter)
            prop(look.prop, width: propWidth)
                .rotationEffect(.degrees(-10 + 3 * sin(2 * .pi * t)))
                .position(x: tubeX, y: groundY(at: tubeX) - propWidth * 1.02)
            pimpi(cheer, hops: 2, size: side, x: pimpiX, outfit: look.outfit, pose: .wave,
                  mood: cheer > 0 && cheer < 1 ? .excited : .happy, sway: Self.sway(t))
        }
    }
}

extension EventScene {
    /// Each prop is drawn in a box 1 × 2.1 of its width, standing on its base.
    @ViewBuilder func prop(_ prop: ChallengeLook.Prop, width: CGFloat) -> some View {
        switch prop {
        case .tube: EventSunscreenTube(width: width)
        case .jar: EventJar(width: width)
        case .hand: EventHandBadge(width: width)
        }
    }
}

// MARK: - Pieces

/// Deterministic noise: the same piece lands in the same place on every frame.
enum EventNoise {
    static func value(_ index: Int, _ salt: Int) -> Double {
        let v = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - v.rounded(.down)
    }
}

/// Confetti falling a whole number of times per loop, each piece fluttering as it spins.
struct EventConfetti: View {
    enum Piece { case strip, petal, leaf }

    let t: Double
    let size: CGSize
    let count: Int
    var colors: [ColorToken] = [Palette.outfitRed, Palette.outfitGreen, Palette.outfitGold,
                                Palette.signal, Palette.sun, Palette.pimpiCheek]
    var piece: Piece = .strip

    var body: some View {
        let u = min(size.width, size.height)
        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                let falls = Double(1 + index % 2)
                let spins = Double(1 + index % 3)
                let phase = EventNoise.value(index, 3)
                let fall = (EventNoise.value(index, 2) + t * falls).truncatingRemainder(dividingBy: 1)
                let x = EventNoise.value(index, 1) * size.width + u * 0.025 * sin(2 * .pi * (t * falls + phase))
                let y = fall * size.height * 1.1 - size.height * 0.05
                pieceView(colors[index % colors.count].light.heroColor, u: u)
                    .scaleEffect(x: cos(2 * .pi * (t * spins + phase)), y: 1)
                    .rotationEffect(.degrees(360 * (phase + t * spins)))
                    .position(x: x, y: y)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder private func pieceView(_ color: Color, u: CGFloat) -> some View {
        switch piece {
        case .strip:
            RoundedRectangle(cornerRadius: u * 0.003).fill(color).frame(width: u * 0.011, height: u * 0.022)
        case .petal:
            Ellipse().fill(color).frame(width: u * 0.036, height: u * 0.02)
        case .leaf:
            Image(systemName: "leaf.fill").font(.system(size: u * 0.032, weight: .bold)).foregroundStyle(color)
        }
    }
}

/// Twinkling stars across the top of a night sky.
struct EventStars: View {
    let t: Double
    let size: CGSize
    let count: Int
    /// How far down the sky the stars reach, as a fraction of the height.
    let band: Double

    var body: some View {
        let u = min(size.width, size.height)
        let star = Palette.sun.light.heroColor
        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                let twinkle = 0.35 + 0.65 * abs(sin(.pi * (Double(1 + index % 3) * t + EventNoise.value(index, 5))))
                let big = index % 7 == 0
                Group {
                    if big {
                        Image(systemName: "sparkle").font(.system(size: u * 0.03, weight: .bold))
                            .foregroundStyle(star)
                            .scaleEffect(0.7 + 0.3 * twinkle)
                    } else {
                        Circle().fill(star).frame(width: u * 0.007, height: u * 0.007)
                    }
                }
                .opacity(twinkle)
                .position(x: EventNoise.value(index, 3) * size.width, y: EventNoise.value(index, 4) * size.height * band)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Fireworks: each burst blooms from its centre and falls away inside its own slice of the loop.
struct EventFireworks: View {
    let t: Double
    let size: CGSize
    /// Centre and start time (0 ..< 1) of each burst.
    let bursts: [(CGPoint, Double)]

    private static let duration = 0.3
    private static let sparks = 18
    private static let colors: [ColorToken] = [Palette.sun, Palette.pimpiBody, Palette.outfitGreen, Palette.pimpiCheek]

    var body: some View {
        let u = min(size.width, size.height)
        ZStack(alignment: .topLeading) {
            ForEach(0..<bursts.count, id: \.self) { burst in
                let (center, start) = bursts[burst]
                let p = (t - start + 1).truncatingRemainder(dividingBy: 1) / Self.duration
                if p < 1 {
                    burstView(burst, center: center, p: p, u: u)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// A white flash, then streaks flying out, stretching and falling as they fade.
    private func burstView(_ burst: Int, center: CGPoint, p: Double, u: CGFloat) -> some View {
        let color = Self.colors[burst % Self.colors.count].light.heroColor
        let accent = Palette.sun.light.heroColor
        let radius = u * 0.2 * (1 - pow(1 - p, 3))
        let drop = u * 0.06 * p * p
        let streak = u * 0.012 + u * 0.05 * (1 - p) * min(p * 6, 1)
        return ZStack(alignment: .topLeading) {
            if p < 0.2 {
                Circle().fill(Palette.surface.light.heroColor.opacity(0.9 * (1 - p / 0.2)))
                    .frame(width: u * 0.05 * (1 + p * 4), height: u * 0.05 * (1 + p * 4))
                    .position(center)
            }
            ForEach(0..<Self.sparks, id: \.self) { spark in
                let angle = 2 * .pi * Double(spark) / Double(Self.sparks)
                Capsule().fill(spark % 3 == 0 ? accent : color)
                    .frame(width: u * 0.011, height: streak)
                    .rotationEffect(.radians(angle - .pi / 2))
                    .opacity(pow(1 - p, 1.2))
                    .position(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle) + drop)
            }
        }
    }
}

/// One of the Wrapped stats, in the app's card style: white with a hard bottom edge.
struct EventStatCard: View {
    let symbol: String
    let tint: ColorToken
    let value: String
    let width: CGFloat

    var body: some View {
        let radius = width * 0.14
        VStack(spacing: width * 0.06) {
            Image(systemName: symbol).font(.system(size: width * 0.26, weight: .bold))
                .foregroundStyle(tint.light.heroColor)
            Text(value).font(.system(size: width * 0.3, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink.light.heroColor)
                .fixedSize()
            Capsule().fill(Palette.hairline.light.heroColor).frame(width: width * 0.5, height: width * 0.05)
        }
        .frame(width: width, height: width * 1.12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.edge.light.heroColor)
                    .offset(y: width * 0.04)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.surface.light.heroColor)
            }
        }
    }
}

/// A present with a ribbon and bow; `open` lifts and tips the lid.
struct EventGiftBox: View {
    let width: CGFloat
    let open: Double

    var body: some View {
        let boxColor = Palette.signal.light.heroColor
        let ribbon = Palette.sun.light.heroColor
        let height = width * 0.72
        let lidHeight = width * 0.22
        ZStack(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.06, style: .continuous).fill(boxColor)
                Rectangle().fill(ribbon).frame(width: width * 0.16)
            }
            .frame(width: width, height: height)
            .offset(y: lidHeight * 0.6)
            ZStack(alignment: .bottom) {
                HStack(spacing: width * 0.02) {
                    Ellipse().fill(ribbon).frame(width: width * 0.24, height: width * 0.16).rotationEffect(.degrees(-20))
                    Ellipse().fill(ribbon).frame(width: width * 0.24, height: width * 0.16).rotationEffect(.degrees(20))
                }
                .offset(y: -lidHeight * 0.85)
                ZStack {
                    RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                        .fill(Palette.pimpiBodyDeep.light.heroColor)
                    Rectangle().fill(ribbon).frame(width: width * 0.16)
                }
                .frame(width: width * 1.1, height: lidHeight)
            }
            .rotationEffect(.degrees(-14 * open), anchor: .bottomLeading)
            .offset(y: -height * 0.55 * open)
        }
        .frame(width: width * 1.1, height: height + lidHeight * 0.6)
    }
}

/// A big friendly sun whose rays turn one ray-gap per loop.
struct EventBigSun: View {
    let t: Double
    let radius: CGFloat

    private static let rays = 12

    var body: some View {
        let sun = Palette.sun.light.heroColor
        let glow = 1 + 0.05 * sin(2 * .pi * t * 2)
        ZStack {
            Circle().fill(sun.opacity(0.25)).frame(width: radius * 3.4 * glow, height: radius * 3.4 * glow)
            ForEach(0..<Self.rays, id: \.self) { ray in
                Capsule().fill(sun)
                    .frame(width: radius * 0.2, height: radius * 0.42)
                    .offset(y: -radius * 1.36)
                    .rotationEffect(.degrees(360 / Double(Self.rays) * (Double(ray) + t)))
            }
            Circle().fill(sun).frame(width: radius * 2, height: radius * 2)
        }
        .frame(width: radius * 3.6, height: radius * 3.6)
    }
}

/// The challenge's thirty days as a card of dots: ticked ones turn sunny with a check, the newest pops in, the
/// whole card does a wave when all thirty are in, and `clear` fades the ticks back out.
struct EventDayCard: View {
    let done: Double
    let cheer: Double
    let clear: Double
    let width: CGFloat

    private static let columns = 6
    private static let rows = 5

    var body: some View {
        let padding = width * 0.08
        let gap = width * 0.035
        let dot = (width - padding * 2 - gap * CGFloat(Self.columns - 1)) / CGFloat(Self.columns)
        let height = padding * 2 + dot * CGFloat(Self.rows) + gap * CGFloat(Self.rows - 1)
        let radius = width * 0.07
        VStack(spacing: gap) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        dayDot(row * Self.columns + column, size: dot)
                    }
                }
            }
        }
        .padding(padding)
        .frame(width: width, height: height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.edge.light.heroColor)
                    .offset(y: width * 0.022)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Palette.surface.light.heroColor)
            }
        }
    }

    private func dayDot(_ index: Int, size: CGFloat) -> some View {
        // 0 before this day is ticked, rising past 1 (overshoot) as it pops in.
        let pop = HeroEase.outBack(min(max(done - Double(index), 0), 1))
        let wave = sin(.pi * min(max(cheer * 1.6 - Double(index) / 30 * 0.6, 0), 1))
        let ticked = pop * (1 - clear)
        return ZStack {
            Circle().stroke(Palette.hairline.light.heroColor, lineWidth: size * 0.09)
            Circle().fill(Palette.sun.light.heroColor).scaleEffect(ticked)
            Image(systemName: "checkmark").font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(Palette.ink.light.heroColor)
                .scaleEffect(ticked)
        }
        .frame(width: size, height: size)
        .offset(y: -size * 0.25 * wave)
    }
}

/// A sunscreen tube standing on its cap: white, with a sunny label.
struct EventSunscreenTube: View {
    let width: CGFloat

    var body: some View {
        let height = width * 2.1
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: width * 0.12, bottomLeadingRadius: width * 0.4,
                                   bottomTrailingRadius: width * 0.4, topTrailingRadius: width * 0.12,
                                   style: .continuous)
                .fill(Palette.surface.light.heroColor)
                .frame(width: width, height: height * 0.82)
                .overlay {
                    ZStack {
                        Capsule().fill(Palette.sun.light.heroColor).frame(width: width * 0.8, height: width * 0.62)
                        Image(systemName: "sun.max.fill").font(.system(size: width * 0.36, weight: .bold))
                            .foregroundStyle(Palette.signal.light.heroColor)
                    }
                    .offset(y: -height * 0.04)
                }
                .offset(y: -height * 0.16)
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .fill(Palette.signal.light.heroColor)
                .frame(width: width * 0.7, height: height * 0.2)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.12), radius: width * 0.08, y: width * 0.05)
    }
}
#endif

#if DEBUG
/// A crescent moon for the evening half of the morning-and-evening film.
struct EventMoon: View {
    let radius: CGFloat

    var body: some View {
        let moon = Palette.sun.dark.heroColor
        ZStack {
            Circle().fill(moon.opacity(0.22)).frame(width: radius * 3.2, height: radius * 3.2)
            Circle().fill(moon).frame(width: radius * 2, height: radius * 2)
                .mask {
                    ZStack {
                        Rectangle()
                        Circle().frame(width: radius * 1.7, height: radius * 1.7)
                            .offset(x: radius * 0.6, y: -radius * 0.35)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
        }
        .frame(width: radius * 3.4, height: radius * 3.4)
    }
}

/// A moisturiser jar: a round lid on a squat pot with a little drop on its label.
struct EventJar: View {
    let width: CGFloat

    var body: some View {
        let height = width * 2.1
        VStack(spacing: -width * 0.04) {
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .fill(Palette.outfitGreen.light.heroColor)
                .frame(width: width * 1.08, height: width * 0.34)
            RoundedRectangle(cornerRadius: width * 0.2, style: .continuous)
                .fill(Palette.surface.light.heroColor)
                .frame(width: width, height: width * 0.86)
                .overlay {
                    Image(systemName: "drop.fill").font(.system(size: width * 0.34, weight: .bold))
                        .foregroundStyle(Palette.pimpiCheek.light.heroColor)
                }
        }
        .frame(width: width * 1.1, height: height, alignment: .bottom)
        .shadow(color: .black.opacity(0.12), radius: width * 0.08, y: width * 0.05)
    }
}

/// A raised hand on a round sign: hands off your face.
struct EventHandBadge: View {
    let width: CGFloat

    var body: some View {
        let height = width * 2.1
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Palette.surface.light.heroColor)
                Circle().stroke(Palette.signal.light.heroColor, lineWidth: width * 0.09)
                Image(systemName: "hand.raised.fill").font(.system(size: width * 0.5, weight: .bold))
                    .foregroundStyle(Palette.signal.light.heroColor)
            }
            .frame(width: width * 1.1, height: width * 1.1)
            Capsule().fill(Palette.ink.light.heroColor).frame(width: width * 0.12, height: width * 0.95)
        }
        .frame(width: width * 1.1, height: height, alignment: .bottom)
        .shadow(color: .black.opacity(0.12), radius: width * 0.08, y: width * 0.05)
    }
}
#endif
