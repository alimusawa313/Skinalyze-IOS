import Foundation

/// A small 8-bit grayscale image (e.g. the luma plane of the face region, downsampled). Value type, Sendable.
public struct GrayImage: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "pixel count must equal width × height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    subscript(x: Int, y: Int) -> Int { Int(pixels[y * width + x]) }
}

/// Frame-quality measurements used by the capture gates.
public enum FrameAnalysis {
    static let clipLow: UInt8 = 5
    static let clipHigh: UInt8 = 250

    public static func meanLuma(_ image: GrayImage) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        return Double(image.pixels.reduce(0) { $0 + Int($1) }) / Double(image.pixels.count)
    }

    public static func clippedFraction(_ image: GrayImage) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        let clipped = image.pixels.lazy.filter { $0 <= clipLow || $0 >= clipHigh }.count
        return Double(clipped) / Double(image.pixels.count)
    }

    /// Variance of the 4-neighbour Laplacian over interior pixels — a standard focus/blur measure.
    public static func laplacianVariance(_ image: GrayImage) -> Double {
        guard image.width >= 3, image.height >= 3 else { return 0 }
        var sum = 0.0
        var sumSquares = 0.0
        var count = 0.0
        for y in 1..<(image.height - 1) {
            for x in 1..<(image.width - 1) {
                let laplacian = Double(4 * image[x, y] - image[x - 1, y] - image[x + 1, y] - image[x, y - 1] - image[x, y + 1])
                sum += laplacian
                sumSquares += laplacian * laplacian
                count += 1
            }
        }
        let mean = sum / count
        return max(sumSquares / count - mean * mean, 0)
    }

    /// Face-centre movement between two frames, in normalized units per second.
    public static func motion(from previous: ImageRect, to current: ImageRect, elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        let dx = (current.x + current.width / 2) - (previous.x + previous.width / 2)
        let dy = (current.y + current.height / 2) - (previous.y + previous.height / 2)
        return (dx * dx + dy * dy).squareRoot() / elapsed
    }
}
