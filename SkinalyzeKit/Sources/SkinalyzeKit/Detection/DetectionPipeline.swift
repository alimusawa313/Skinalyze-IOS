import CoreGraphics

/// Everything between "upright photo + face box" and "final detections", except the Core ML call itself
/// (ML-PLAN M0.1). The app (`AcneDetector`) and the benchmark (`Tools/DetectorBench`) both run this, so a number
/// the benchmark reports is the number the app would show.
///
/// Steps: square face crop → optional colour normalisation → one model run per planned tile → drop boxes cut by a
/// tile seam → map to full-image coordinates → optional skin mask → per-class threshold + cross-class NMS.
public struct DetectionPipeline: Sendable {
    public struct Configuration: Sendable, Hashable {
        public let tiling: Tiling
        public let thresholds: ClassThresholds
        public let iouThreshold: Double
        /// Callers compute a `SkinMask` from face landmarks and pass it to `detect` when this is on.
        public let masksLandmarks: Bool
        public let normalizesColor: Bool

        public init(
            tiling: Tiling = .none,
            thresholds: ClassThresholds = DetectionFilter.classThresholds,
            iouThreshold: Double = DetectionFilter.defaultIoUThreshold,
            masksLandmarks: Bool = false,
            normalizesColor: Bool = false
        ) {
            self.tiling = tiling
            self.thresholds = thresholds
            self.iouThreshold = iouThreshold
            self.masksLandmarks = masksLandmarks
            self.normalizesColor = normalizesColor
        }

        /// The pipeline as it was before ML-PLAN M1: one run on the face crop, one 0.4 threshold, NMS at 0.45.
        public static let baseline = Configuration()

        /// What the app ships. Changing it moves users' numbers: bump `DetectionPipeline.shippingVersion` with it.
        public static let shipping = baseline
    }

    /// Stored on every new scan (`ScanSession.pipelineVersion`). Scans saved before versioning count as this
    /// version too (see `CountingVersion`), because their pipeline was the baseline.
    public static let shippingVersion = "2d-1"

    /// Runs the detector on one image and returns boxes **normalised to that image** (Vision convention).
    public typealias ModelRunner = (CGImage) throws -> [RawDetection]

    public enum PipelineError: Error {
        case invalidImage
    }

    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    /// Crop and tile regions for an image. Every region is whole pixels and inside the crop.
    public func plan(imageSize: CGSize, face: ImageRect?) -> DetectionPlan {
        let fullImage = CGRect(origin: .zero, size: imageSize)
        let cropRect = face.map { FaceCrop.squarePixelRect(face: $0, imageSize: imageSize).integral } ?? fullImage
        let cropBounds = CGRect(origin: .zero, size: cropRect.size)
        let tiles = configuration.tiling.tiles(in: cropRect.size).map {
            Tile(rect: $0.rect.integral.intersection(cropBounds), interiorEdges: $0.interiorEdges)
        }
        return DetectionPlan(imageSize: imageSize, cropRect: cropRect, tiles: tiles)
    }

    /// Combines the model's output for each planned tile (same order as `plan.tiles`) into final detections in
    /// full-image coordinates.
    public func merge(_ outputs: [[RawDetection]], plan: DetectionPlan, mask: SkinMask?) -> [RawDetection] {
        let mapped = zip(plan.tiles, outputs).flatMap { tile, detections in
            let region = plan.region(of: tile)
            return detections
                .filter { !tile.cutsAtSeam($0.box) }
                .map {
                    RawDetection(
                        type: $0.type,
                        confidence: $0.confidence,
                        box: ImageSpace.toImage($0.box, region: region, imageSize: plan.imageSize)
                    )
                }
        }
        let onSkin = mask.map { mask in mapped.filter { mask.allows($0.box.center) } } ?? mapped
        return DetectionFilter.filter(
            onSkin, thresholds: configuration.thresholds, iouThreshold: configuration.iouThreshold
        )
    }

    /// Detects lesions in an upright image. `face` is the Vision face box (nil: the whole image is used); `mask` is
    /// applied only if given. Synchronous: callers run it off the main actor.
    public func detect(
        in image: CGImage,
        face: ImageRect?,
        mask: SkinMask?,
        runModel: ModelRunner
    ) throws -> [RawDetection] {
        let plan = plan(imageSize: CGSize(width: image.width, height: image.height), face: face)
        guard let rawCrop = image.cropping(to: plan.cropRect) else { throw PipelineError.invalidImage }
        let crop = configuration.normalizesColor ? (ColorNormalization.normalized(rawCrop) ?? rawCrop) : rawCrop
        let outputs = try plan.tiles.map { tile -> [RawDetection] in
            guard let tileImage = crop.cropping(to: tile.rect) else { throw PipelineError.invalidImage }
            return try runModel(tileImage)
        }
        return merge(outputs, plan: plan, mask: mask)
    }
}

public struct DetectionPlan: Sendable, Hashable {
    public let imageSize: CGSize
    /// Square face crop (or the whole image), whole pixels, top-left origin.
    public let cropRect: CGRect
    /// Crop-local tiles, in the order the model runs on them.
    public let tiles: [Tile]

    /// A tile's rectangle in full-image pixel coordinates.
    public func region(of tile: Tile) -> CGRect {
        tile.rect.offsetBy(dx: cropRect.minX, dy: cropRect.minY)
    }
}

/// How a scan's spots were counted: the model plus the pipeline around it (ML-PLAN M1.7). The trend chart and Compare
/// mark the first scan whose counting version differs from the one before ("counted differently from here").
public struct CountingVersion: Sendable, Hashable {
    public let modelVersion: String
    /// `nil` for scans saved before versioning; they were counted with the baseline pipeline.
    public let pipelineVersion: String?

    /// Version that scans without a stored pipeline version were counted with.
    public static let unversionedPipeline = "2d-1"

    public init(modelVersion: String, pipelineVersion: String?) {
        self.modelVersion = modelVersion
        self.pipelineVersion = pipelineVersion
    }

    private var effectivePipeline: String { pipelineVersion ?? Self.unversionedPipeline }

    public static func == (lhs: CountingVersion, rhs: CountingVersion) -> Bool {
        lhs.modelVersion == rhs.modelVersion && lhs.effectivePipeline == rhs.effectivePipeline
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelVersion)
        hasher.combine(effectivePipeline)
    }

    /// Indices (into chronologically ordered versions) of scans counted differently from the scan before them.
    public static func changePoints(_ versions: [CountingVersion]) -> [Int] {
        zip(versions.indices.dropFirst(), zip(versions, versions.dropFirst()))
            .filter { _, pair in pair.0 != pair.1 }
            .map(\.0)
    }
}
