import Foundation

/// The glow-up reel's timing: scans play oldest → newest, each crossfading into the next, then the newest holds.
/// Pure arithmetic, so the same plan drives the preview, the export and the tests.
public struct ReelPlan: Sendable, Equatable {
    public static let framesPerSecond = 30
    public static let minimumSeconds = 6.0
    public static let maximumSeconds = 12.0
    /// More scans than this are sampled evenly (oldest and newest always kept) so each stays readable.
    public static let maximumScans = 16

    private static let secondsPerScan = 1.2
    private static let outroSeconds = 1.6
    /// The last part of each scan's time is spent crossfading into the next.
    private static let crossfadeShare = 0.4

    public struct Frame: Sendable, Equatable {
        /// The scan on screen.
        public let current: Int
        /// The scan fading in, when there is one.
        public let next: Int?
        /// 0 = only `current`; approaches 1 as `next` takes over.
        public let blend: Double
        /// The closing hold on the newest scan.
        public let isOutro: Bool
    }

    public let scanCount: Int
    public let frameCount: Int
    private let framesPerScan: Double
    private let bodyFrames: Int

    public init?(scanCount: Int) {
        guard scanCount >= 2 else { return nil }
        let body = min(max(Double(scanCount) * Self.secondsPerScan, Self.minimumSeconds - Self.outroSeconds),
                       Self.maximumSeconds - Self.outroSeconds)
        self.scanCount = scanCount
        bodyFrames = Int((body * Double(Self.framesPerSecond)).rounded())
        framesPerScan = Double(bodyFrames) / Double(scanCount)
        frameCount = bodyFrames + Int((Self.outroSeconds * Double(Self.framesPerSecond)).rounded())
    }

    public func frame(at index: Int) -> Frame {
        let index = min(max(index, 0), frameCount - 1)
        guard index < bodyFrames else { return Frame(current: scanCount - 1, next: nil, blend: 0, isOutro: true) }
        let position = Double(index) / framesPerScan
        let current = min(Int(position), scanCount - 1)
        guard current < scanCount - 1 else { return Frame(current: current, next: nil, blend: 0, isOutro: false) }
        let within = position - Double(current)
        let fadeStart = 1 - Self.crossfadeShare
        let blend = within <= fadeStart ? 0 : (within - fadeStart) / Self.crossfadeShare
        return Frame(current: current, next: current + 1, blend: min(max(blend, 0), 0.999), isOutro: false)
    }

    /// The number shown while one scan's value turns into the next.
    public static func displayedValue(from: Int, to: Int?, blend: Double) -> Int {
        guard let to else { return from }
        return Int((Double(from) + Double(to - from) * blend).rounded())
    }

    /// Which of `count` scans (oldest first) go into the reel.
    public static func selection(count: Int) -> [Int] {
        guard count > maximumScans else { return Array(0..<max(count, 0)) }
        let step = Double(count - 1) / Double(maximumScans - 1)
        return (0..<maximumScans).map { Int((Double($0) * step).rounded()) }
    }
}
