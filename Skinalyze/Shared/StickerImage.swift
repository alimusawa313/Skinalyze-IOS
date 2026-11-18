import CoreImage
import CoreMotion
import SwiftUI
import UIKit
import Vision

/// A die-cut sticker made from a photo: the lifted subject plus a white backing a little larger than it (the outline).
/// Both images share one canvas so they stack pixel-perfectly.
struct StickerArt: @unchecked Sendable { // UIImage is immutable once made; safe to hand across actors.
    let subject: UIImage
    let backing: UIImage
    /// The original photo on the same canvas (full-frame art only) — so the lift starts pixel-aligned with the photo.
    var photo: UIImage?
}

/// Lifts the subject out of a photo on-device (Vision) and cuts it like a sticker. Cached per scan.
/// When no subject can be found (e.g. Simulator) the whole photo becomes a rounded sticker instead.
actor PortraitCutout {
    static let shared = PortraitCutout()
    /// Working size: plenty for a card, fast for Vision + Core Image.
    private static let maxSide: CGFloat = 1024
    /// Outline thickness relative to the shorter side.
    private static let outlineRatio: CGFloat = 0.03

    private final class Box {
        let art: StickerArt?
        init(_ art: StickerArt?) { self.art = art }
    }

    private let cache = NSCache<NSString, Box>()
    private let context = CIContext()

    /// Cropped to the sticker's edge — for cards.
    func art(for id: UUID, photo: Data?) -> StickerArt? {
        if let cached = cache.object(forKey: id.uuidString as NSString) { return cached.art }
        guard let photo, let source = UIImage(data: photo) else { return nil }
        let art = make(from: source)?.cropped
        cache.setObject(Box(art), forKey: id.uuidString as NSString)
        return art
    }

    /// Full photo frame (aligned with the photo, plus outline margin) and the cropped version — for the lift animation.
    func liftArt(from image: UIImage) -> (full: StickerArt, cropped: StickerArt)? {
        make(from: image)
    }

    // MARK: - Making

    private func make(from image: UIImage) -> (full: StickerArt, cropped: StickerArt)? {
        guard let upright = Self.upright(image, maxSide: Self.maxSide) else { return nil }
        let photo = CIImage(cgImage: upright)
        let radius = max(4, min(photo.extent.width, photo.extent.height) * Self.outlineRatio)
        let mask = subjectMask(upright) ?? roundedMask(photo.extent)
        let canvas = photo.extent.insetBy(dx: -radius, dy: -radius)

        let clear = CIImage.empty()
        let subject = photo.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: mask,
        ])
        let outlineMask = mask
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": radius])
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.2])
        let backing = CIImage(color: .white).cropped(to: canvas).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: outlineMask,
        ])
        guard let subjectCG = context.createCGImage(subject, from: canvas),
              let backingCG = context.createCGImage(backing, from: canvas) else { return nil }
        let photoOnCanvas = context.createCGImage(photo, from: canvas).map(UIImage.init(cgImage:))
        let full = StickerArt(subject: UIImage(cgImage: subjectCG), backing: UIImage(cgImage: backingCG), photo: photoOnCanvas)
        guard let bounds = Self.opaqueBounds(backingCG),
              let subjectCrop = subjectCG.cropping(to: bounds),
              let backingCrop = backingCG.cropping(to: bounds) else { return (full, full) }
        return (full, StickerArt(subject: UIImage(cgImage: subjectCrop), backing: UIImage(cgImage: backingCrop)))
    }

    private func subjectMask(_ image: CGImage) -> CIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
            return CIImage(cvPixelBuffer: buffer)
        } catch {
            return nil // Simulator / unsupported device: rounded-photo sticker instead.
        }
    }

    private func roundedMask(_ extent: CGRect) -> CIImage {
        let inset = extent.insetBy(dx: extent.width * 0.04, dy: extent.width * 0.04)
        return CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: inset),
            "inputRadius": extent.width * 0.08,
            "inputColor": CIColor.white,
        ])?.outputImage ?? CIImage(color: .white).cropped(to: inset)
    }

    /// Upright (EXIF applied), downscaled bitmap.
    private static func upright(_ image: UIImage, maxSide: CGFloat) -> CGImage? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// Bounding box (top-left pixel coords) of the non-transparent pixels, sampled at reduced resolution.
    private static func opaqueBounds(_ image: CGImage) -> CGRect? {
        let step = 4
        let width = image.width / step, height = image.height / step
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where data[y * width + x] > 16 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Bitmap row 0 is the top of the image for CGContext drawing of a CGImage.
        return CGRect(x: minX * step, y: minY * step, width: (maxX - minX + 1) * step, height: (maxY - minY + 1) * step)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
}

/// One shared device-tilt source for every sticker on screen (Daniel Korpai's "Sticker Wall" technique): pitch moves
/// the holo gradient, roll rotates it. Relative to the attitude when the first sticker appeared. Off under Reduce Motion.
@Observable
@MainActor
final class TiltMotion {
    static let shared = TiltMotion()
    private static let updateInterval = 1.0 / 30
    private(set) var pitch: Double = 0
    private(set) var roll: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
    @ObservationIgnored private var users = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { self?.receive(motion.attitude) }
        }
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        reference = nil
        pitch = 0
        roll = 0
    }

    private func receive(_ attitude: CMAttitude) {
        guard let reference else {
            reference = attitude.copy() as? CMAttitude
            return
        }
        guard let relative = attitude.copy() as? CMAttitude else { return }
        relative.multiply(byInverseOf: reference)
        pitch = relative.pitch
        roll = relative.roll
    }
}

/// The sticker's layers: white die-cut backing with a holo gradient that slides as you tilt (border only — your face
/// stays clean), the subject on top with a faint laminate sheen, the whole thing tilting a few degrees.
struct StickerLayers: View {
    let art: StickerArt
    var showsBacking = true
    var showsSubject = true
    var liftGlow = false
    var tilts = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let motion = TiltMotion.shared

    private static let holo: [Color] = [
        Color(red: 1.0, green: 0.72, blue: 0.86), Color(red: 1.0, green: 0.93, blue: 0.62),
        Color(red: 0.64, green: 0.98, blue: 0.82), Color(red: 0.6, green: 0.86, blue: 1.0),
        Color(red: 0.82, green: 0.72, blue: 1.0), Color(red: 1.0, green: 0.72, blue: 0.86),
    ]
    private static let maxTiltDegrees = 10.0

    var body: some View {
        let live = tilts && !reduceMotion
        let pitch = live ? motion.pitch : 0
        let roll = live ? motion.roll : 0
        ZStack {
            Image(uiImage: art.backing).resizable().scaledToFit()
                .overlay { holoLayer(pitch: pitch, roll: roll) }
                .opacity(showsBacking ? 1 : 0)
                .scaleEffect(showsBacking || reduceMotion ? 1 : 0.92)
            Image(uiImage: art.subject).resizable().scaledToFit()
                .overlay { sheen(roll: roll).mask(Image(uiImage: art.subject).resizable().scaledToFit()) }
                .opacity(showsSubject ? 1 : 0)
                .shadow(color: .white.opacity(liftGlow ? 0.95 : 0), radius: 16)
        }
        .rotation3DEffect(.degrees(clamp(roll) * Self.maxTiltDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .rotation3DEffect(.degrees(clamp(pitch) * -Self.maxTiltDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
        .onAppear { if live { motion.start() } }
        .onDisappear { if live { motion.stop() } }
        .accessibilityHidden(true)
    }

    /// Rainbow foil on the white edge: pitch slides it, roll turns it.
    private func holoLayer(pitch: Double, roll: Double) -> some View {
        GeometryReader { proxy in
            LinearGradient(colors: Self.holo, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: proxy.size.width * 3, height: proxy.size.height * 3)
                .rotationEffect(.radians(roll * 1.5))
                .offset(x: -proxy.size.width, y: -proxy.size.height + pitch * proxy.size.height * 1.2)
                .overlay { sheen(roll: roll) }
        }
        .blendMode(.multiply)
        .mask(Image(uiImage: art.backing).resizable().scaledToFit())
        .allowsHitTesting(false)
    }

    /// A soft specular band that glides across with the tilt.
    private func sheen(roll: Double) -> some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: proxy.size.height * 0.35)
                .rotationEffect(.degrees(-30))
                .offset(y: proxy.size.height * (0.35 + clamp(roll) * 0.6))
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private func clamp(_ value: Double) -> Double { min(max(value, -1), 1) }
}

/// A finished sticker on a card: layers + a contact shadow that shifts opposite the tilt (light from above).
struct StickerImage: View {
    let art: StickerArt
    var tilts = true
    var shadowRadius: CGFloat = 6

    var body: some View {
        StickerLayers(art: art, tilts: tilts)
            .shadow(color: .black.opacity(0.28), radius: shadowRadius, y: shadowRadius * 0.7)
    }
}
