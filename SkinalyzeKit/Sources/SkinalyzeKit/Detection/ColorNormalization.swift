import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// White-balance and exposure normalisation of the face crop before inference (ML-PLAN M1.4). Identical in the app
/// and the benchmark because both call this.
public enum ColorNormalization {
    public struct Gains: Sendable, Hashable {
        public let red: Double
        public let green: Double
        public let blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        static let identity = Gains(red: 1, green: 1, blue: 1)
    }

    /// How much of the gray-world white balance to apply. Full gray-world would turn skin gray (a new domain gap),
    /// so only half of it is applied by default.
    public static let defaultStrength = 0.5
    /// Mean brightness the crop is scaled to.
    public static let defaultTargetLuminance = 0.5
    public static let gainRange = 0.5...2.0

    /// Per-channel gains from the crop's mean colour (0…1 per channel).
    public static func gains(
        meanRed: Double,
        meanGreen: Double,
        meanBlue: Double,
        strength: Double = defaultStrength,
        targetLuminance: Double = defaultTargetLuminance
    ) -> Gains {
        let gray = (meanRed + meanGreen + meanBlue) / 3
        guard gray > 0 else { return .identity }
        let exposure = targetLuminance / gray
        func gain(_ channel: Double) -> Double {
            let balance = channel > 0 ? gray / channel : 1
            let blended = 1 + strength * (balance - 1)
            return min(max(blended * exposure, gainRange.lowerBound), gainRange.upperBound)
        }
        return Gains(red: gain(meanRed), green: gain(meanGreen), blue: gain(meanBlue))
    }

    /// Core Image work happens in the image's own encoded values (no colour management), so the result is the same
    /// on every device. `CIContext` is thread-safe (and `Sendable`).
    private static let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull(),
    ])

    /// The image with gains from its own mean colour applied, or `nil` if Core Image fails.
    public static func normalized(_ image: CGImage, strength: Double = defaultStrength) -> CGImage? {
        let input = CIImage(cgImage: image)
        let extent = input.extent
        let average = CIFilter.areaAverage()
        average.inputImage = input
        average.extent = extent
        guard let averageImage = average.outputImage else { return nil }

        var pixel = [Float](repeating: 0, count: 4)
        context.render(
            averageImage, toBitmap: &pixel, rowBytes: 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil
        )
        let gains = gains(
            meanRed: Double(pixel[0]), meanGreen: Double(pixel[1]), meanBlue: Double(pixel[2]), strength: strength
        )

        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = input
        matrix.rVector = CIVector(x: gains.red, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: gains.green, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: gains.blue, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let output = matrix.outputImage?.cropped(to: extent) else { return nil }
        return context.createCGImage(output, from: extent)
    }
}
