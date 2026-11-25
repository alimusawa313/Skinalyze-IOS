import CoreGraphics
import Foundation
import Testing
@testable import SkinalyzeKit

// ML-PLAN.md M0.1 and M1: pure pieces of the detection pipeline, shared by the app and Tools/DetectorBench.

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> ImageRect {
    ImageRect(x: x, y: y, width: w, height: h)
}

private func isClose(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }

private func isClose(_ a: ImageRect, _ b: ImageRect, tolerance: Double = 1e-9) -> Bool {
    isClose(a.x, b.x, tolerance: tolerance) && isClose(a.y, b.y, tolerance: tolerance)
        && isClose(a.width, b.width, tolerance: tolerance) && isClose(a.height, b.height, tolerance: tolerance)
}

@Suite("Image space mapping")
struct ImageSpaceTests {
    @Test("A box normalised to a region maps to the full image and back")
    func roundTrip() {
        let imageSize = CGSize(width: 1000, height: 2000)
        let region = CGRect(x: 200, y: 500, width: 400, height: 400) // top-left origin pixels
        let box = rect(0.25, 0.5, 0.1, 0.05)
        let inImage = ImageSpace.toImage(box, region: region, imageSize: imageSize)
        // x: (200 + 0.25*400)/1000 = 0.3; region bottom from image bottom = 2000-900 = 1100 → y = (1100 + 200)/2000
        #expect(isClose(inImage, rect(0.3, 0.65, 0.04, 0.01)))
        #expect(isClose(ImageSpace.toRegion(inImage, region: region, imageSize: imageSize), box))
    }

    @Test("The whole image as the region is the identity")
    func identity() {
        let size = CGSize(width: 640, height: 480)
        let box = rect(0.1, 0.2, 0.3, 0.4)
        #expect(isClose(ImageSpace.toImage(box, region: CGRect(origin: .zero, size: size), imageSize: size), box))
    }
}

@Suite("Same-spot matching rule")
struct DetectionMatchingTests {
    private let size = CGSize(width: 1000, height: 1000)

    @Test("Tiny boxes a few pixels apart are the same spot even with low IoU")
    func tinyBoxes() {
        let truth = rect(0.500, 0.500, 0.004, 0.004)     // 4 px
        let nearby = rect(0.5015, 0.500, 0.004, 0.004)   // centre 1.5 px away
        let shifted = rect(0.5022, 0.5, 0.002, 0.002)    // centre ≈ 1.6 px away, IoU ≈ 0.22
        #expect(DetectionMatching.isSameSpot(nearby, as: truth, imageSize: size))
        #expect(DetectionFilter.iou(shifted, truth) < 0.3)
        #expect(DetectionMatching.isSameSpot(shifted, as: truth, imageSize: size))
    }

    @Test("A box further than half the reference's larger side with low IoU is a different spot")
    func farApart() {
        let truth = rect(0.5, 0.5, 0.01, 0.01)
        #expect(!DetectionMatching.isSameSpot(rect(0.52, 0.5, 0.01, 0.01), as: truth, imageSize: size))
    }

    @Test("High IoU matches regardless of centre distance")
    func iouMatch() {
        let truth = rect(0.1, 0.1, 0.2, 0.2)
        #expect(DetectionMatching.isSameSpot(rect(0.12, 0.1, 0.2, 0.2), as: truth, imageSize: size))
    }

    @Test("Distance is measured in pixels, so non-square images are not skewed")
    func anisotropic() {
        let wide = CGSize(width: 2000, height: 500)
        let truth = rect(0.5, 0.5, 0.005, 0.02)  // 10 × 10 px
        // centre 0.004 to the right = 8 px: further than 5 px → different
        #expect(!DetectionMatching.isSameSpot(rect(0.50645, 0.50995, 0.0001, 0.0001), as: truth, imageSize: wide))
        // centre 0.008 higher = 4 px: within 5 px → same
        #expect(DetectionMatching.isSameSpot(rect(0.50245, 0.51795, 0.0001, 0.0001), as: truth, imageSize: wide))
    }
}

@Suite("Tiling")
struct TilingTests {
    @Test("No tiling is one run over the whole crop with no seams")
    func none() {
        let tiles = Tiling.none.tiles(in: CGSize(width: 900, height: 900))
        #expect(tiles == [Tile(rect: CGRect(x: 0, y: 0, width: 900, height: 900), interiorEdges: [])])
        #expect(Tiling.none.runsPerImage == 1)
    }

    @Test("2×2 with 20% overlap covers the crop exactly and overlaps neighbours by 20% of a tile")
    func twoByTwo() throws {
        let size = CGSize(width: 900, height: 900)
        let tiling = Tiling(grid: 2, overlap: 0.2, includesWholeCrop: false)
        let tiles = tiling.tiles(in: size)
        #expect(tiles.count == 4)
        let side = 900 / 1.8
        #expect(tiles.allSatisfy { isClose($0.rect.width, side) && isClose($0.rect.height, side) })
        let union = tiles.map(\.rect).reduce(CGRect.null) { $0.union($1) }
        #expect(union.minX == 0 && union.minY == 0)
        #expect(isClose(union.maxX, 900, tolerance: 1e-6) && isClose(union.maxY, 900, tolerance: 1e-6))
        let topLeft = try #require(tiles.first { $0.rect.minX == 0 && $0.rect.minY == 0 })
        let topRight = try #require(tiles.first { $0.rect.minX > 0 && $0.rect.minY == 0 })
        #expect(isClose(topLeft.rect.intersection(topRight.rect).width, side * 0.2, tolerance: 1e-6))
        #expect(topLeft.interiorEdges == [.right, .bottom])
        #expect(topRight.interiorEdges == [.left, .bottom])
    }

    @Test("The whole-crop pass is added last, without seams, for large lesions")
    func wholeCrop() {
        let tiling = Tiling.twoByTwoWithWhole
        let tiles = tiling.tiles(in: CGSize(width: 500, height: 500))
        #expect(tiles.count == 5)
        #expect(tiling.runsPerImage == 5)
        #expect(tiles.last == Tile(rect: CGRect(x: 0, y: 0, width: 500, height: 500), interiorEdges: []))
    }

    @Test("Invalid values are clamped")
    func clamped() {
        #expect(Tiling(grid: 0, overlap: -1, includesWholeCrop: true) == .none)
        #expect(Tiling(grid: 3, overlap: 5, includesWholeCrop: false).overlap <= 0.5)
    }

    @Test("Seam rule: a box touching an interior edge is dropped; touching the crop's outer edge is kept")
    func seams() {
        let tile = Tile(rect: CGRect(x: 0, y: 0, width: 500, height: 500), interiorEdges: [.right, .bottom])
        #expect(tile.cutsAtSeam(rect(0.97, 0.5, 0.03, 0.02)))          // touches right (interior)
        #expect(tile.cutsAtSeam(rect(0.5, 0.0, 0.02, 0.02)))           // Vision bottom = tile bottom (interior)
        #expect(!tile.cutsAtSeam(rect(0.0, 0.5, 0.02, 0.02)))          // left is the crop's edge
        #expect(!tile.cutsAtSeam(rect(0.5, 0.97, 0.02, 0.03)))         // top is the crop's edge
        #expect(!tile.cutsAtSeam(rect(0.4, 0.4, 0.05, 0.05)))
    }
}

@Suite("Per-class confidence thresholds")
struct ClassThresholdTests {
    @Test("The table has a row for every class")
    func everyClass() {
        #expect(LesionType.allCases.allSatisfy { DetectionFilter.classThresholdTable[$0] != nil })
        #expect(Set(DetectionFilter.classThresholdTable.keys) == Set(LesionType.allCases))
    }

    @Test("Until the benchmark tunes them, every class uses the old single threshold (no number changes)")
    func baselineUnchanged() {
        #expect(LesionType.allCases.allSatisfy {
            DetectionFilter.classThresholds[$0] == DetectionFilter.defaultMinConfidence
        })
    }

    @Test("Each class is filtered with its own threshold")
    func perClass() {
        let thresholds = ClassThresholds([.nodule: 0.8, .blackhead: 0.2])
        let kept = DetectionFilter.filter([
            RawDetection(type: .nodule, confidence: 0.7, box: rect(0.1, 0.1, 0.05, 0.05)),
            RawDetection(type: .blackhead, confidence: 0.25, box: rect(0.5, 0.5, 0.01, 0.01)),
            RawDetection(type: .papule, confidence: 0.39, box: rect(0.8, 0.8, 0.02, 0.02)),
        ], thresholds: thresholds)
        #expect(kept.map(\.type) == [.blackhead])
        #expect(thresholds[.papule] == DetectionFilter.defaultMinConfidence, "missing classes fall back")
        #expect(thresholds.minimum == 0.2)
    }
}

@Suite("Skin mask from face landmarks")
struct SkinMaskTests {
    private let square = FacePolygon([
        ImagePoint(x: 0.4, y: 0.4), ImagePoint(x: 0.6, y: 0.4),
        ImagePoint(x: 0.6, y: 0.6), ImagePoint(x: 0.4, y: 0.6),
    ])

    @Test("Point in polygon")
    func contains() {
        #expect(square.contains(ImagePoint(x: 0.5, y: 0.5)))
        #expect(!square.contains(ImagePoint(x: 0.65, y: 0.5)))
        #expect(!FacePolygon([ImagePoint(x: 0, y: 0), ImagePoint(x: 1, y: 1)]).contains(ImagePoint(x: 0.5, y: 0.5)))
    }

    @Test("Dilation grows the polygon by a margin relative to the face size")
    func dilation() {
        let face = rect(0, 0, 1, 1)
        let grown = square.dilated(by: 0.05, face: face)
        #expect(grown.contains(ImagePoint(x: 0.63, y: 0.5)))
        #expect(!grown.contains(ImagePoint(x: 0.7, y: 0.5)))
    }

    @Test("Clipping keeps only the lower part (Vision y grows upwards)")
    func clipping() {
        let lower = square.clipped(maxY: 0.45)
        #expect(lower.contains(ImagePoint(x: 0.5, y: 0.42)))
        #expect(!lower.contains(ImagePoint(x: 0.5, y: 0.5)))
        #expect(isClose(lower.bounds.height, 0.05, tolerance: 1e-9))
    }

    private var landmarks: FaceLandmarkPoints {
        func blob(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> [ImagePoint] {
            (0..<12).map { step in
                let angle = Double(step) / 12 * 2 * .pi
                return ImagePoint(x: cx + rx * cos(angle), y: cy + ry * sin(angle))
            }
        }
        // Face box 0.2…0.8; Vision y up, so eyes are high (≈0.62) and lips low (≈0.32).
        let contour = (0...16).map { step -> ImagePoint in
            let angle = Double.pi + Double(step) / 16 * .pi   // left ear → chin → right ear
            return ImagePoint(x: 0.5 + 0.3 * cos(angle), y: 0.55 + 0.35 * sin(angle))
        }
        return FaceLandmarkPoints(
            leftEye: blob(0.38, 0.62, 0.05, 0.015), rightEye: blob(0.62, 0.62, 0.05, 0.015),
            leftEyebrow: blob(0.38, 0.69, 0.07, 0.01), rightEyebrow: blob(0.62, 0.69, 0.07, 0.01),
            outerLips: blob(0.5, 0.32, 0.08, 0.03), nose: blob(0.5, 0.47, 0.05, 0.07),
            faceContour: contour
        )
    }

    @Test("Detections on eyes, brows, lips, nostrils and outside the face are dropped; cheeks, nose bridge and forehead are kept",
          arguments: [
            (0.38, 0.62, false), // eye
            (0.62, 0.69, false), // eyebrow
            (0.5, 0.32, false),  // lips
            (0.5, 0.42, false),  // nostrils (lower part of the nose outline)
            (0.5, 0.52, true),   // upper nose stays (blackheads live there)
            (0.3, 0.45, true),   // cheek
            (0.5, 0.82, true),   // forehead, inside the face box
            (0.5, 0.15, false),  // neck, below the jaw contour
            (0.05, 0.5, false),  // background beside the face
          ])
    func mask(x: Double, y: Double, allowed: Bool) {
        let mask = SkinMaskBuilder.mask(for: landmarks, face: rect(0.2, 0.2, 0.6, 0.6))
        #expect(mask.allows(ImagePoint(x: x, y: y)) == allowed)
    }

    @Test("Without a usable contour only the feature regions are excluded")
    func noContour() {
        let partial = FaceLandmarkPoints(
            leftEye: [], rightEye: [], leftEyebrow: [], rightEyebrow: [],
            outerLips: landmarks.outerLips, nose: [], faceContour: []
        )
        let mask = SkinMaskBuilder.mask(for: partial, face: rect(0.2, 0.2, 0.6, 0.6))
        #expect(mask.faceRegion == nil)
        #expect(mask.allows(ImagePoint(x: 0.05, y: 0.05)))
        #expect(!mask.allows(ImagePoint(x: 0.5, y: 0.32)))
    }
}

@Suite("Colour normalisation gains")
struct ColorNormalizationTests {
    @Test("A neutral image at the target brightness is left alone")
    func neutral() {
        let gains = ColorNormalization.gains(meanRed: 0.5, meanGreen: 0.5, meanBlue: 0.5)
        #expect(gains == ColorNormalization.Gains(red: 1, green: 1, blue: 1))
    }

    @Test("Exposure: a dark image is brightened to the target")
    func exposure() {
        let gains = ColorNormalization.gains(meanRed: 0.25, meanGreen: 0.25, meanBlue: 0.25)
        #expect(isClose(gains.red, 2) && isClose(gains.green, 2) && isClose(gains.blue, 2))
    }

    @Test("White balance is only partly corrected, so skin keeps its colour")
    func partialBalance() {
        let gains = ColorNormalization.gains(meanRed: 0.6, meanGreen: 0.5, meanBlue: 0.4, strength: 0.5)
        // gray 0.5 → exposure 1; full balance would be 0.833 / 1 / 1.25; half strength → 0.9167 / 1 / 1.125
        #expect(isClose(gains.red, 0.916_666_666, tolerance: 1e-6))
        #expect(isClose(gains.green, 1))
        #expect(isClose(gains.blue, 1.125))
    }

    @Test("Gains are clamped so a black frame cannot explode")
    func clamped() {
        let gains = ColorNormalization.gains(meanRed: 0.01, meanGreen: 0.01, meanBlue: 0.0)
        #expect(gains.red <= ColorNormalization.gainRange.upperBound)
        #expect(gains.blue <= ColorNormalization.gainRange.upperBound)
        #expect(ColorNormalization.gains(meanRed: 0, meanGreen: 0, meanBlue: 0)
            == ColorNormalization.Gains(red: 1, green: 1, blue: 1))
    }
}

@Suite("Multi-frame agreement")
struct FrameAgreementTests {
    private let size = CGSize(width: 1000, height: 1000)

    private func spot(_ x: Double, _ confidence: Double, _ type: LesionType = .papule) -> RawDetection {
        RawDetection(type: type, confidence: confidence, box: rect(x, 0.5, 0.01, 0.01))
    }

    @Test("A spot seen in 2 of 3 frames is kept once; a one-frame flicker is dropped")
    func twoOfThree() {
        let frames = [
            [spot(0.2, 0.6), spot(0.7, 0.9)],
            [spot(0.201, 0.8)],
            [spot(0.5, 0.95)],
        ]
        let kept = FrameAgreement.consensus(frames, minVotes: 2, imageSize: size)
        #expect(kept.count == 1)
        #expect(kept.first?.confidence == 0.8, "the most confident member represents the spot")
    }

    @Test("Two detections in the same frame never vote twice for one spot")
    func oneVotePerFrame() {
        let frames = [[spot(0.2, 0.6), spot(0.2005, 0.7)], [], []]
        #expect(FrameAgreement.consensus(frames, minVotes: 2, imageSize: size).isEmpty)
    }
}

@Suite("Grouped breakout index (proposal, ML-PLAN M1.6 — not used for users' numbers yet)")
struct GroupedBreakoutIndexTests {
    private func spot(_ type: LesionType, _ confidence: Double = 0.9) -> RawDetection {
        RawDetection(type: type, confidence: confidence, box: rect(0, 0, 0.01, 0.01))
    }

    @Test("Comedones weigh 1, inflamed spots 2, confident nodules 4, marks 0")
    func weights() {
        let index = GroupedBreakoutIndex.index(for: [
            spot(.blackhead), spot(.whitehead), spot(.papule), spot(.pustule), spot(.nodule), spot(.darkSpot),
        ])
        #expect(index == 1 + 1 + 2 + 2 + 4 + 0)
    }

    @Test("An unsure nodule counts as an inflamed spot")
    func unsureNodule() {
        #expect(GroupedBreakoutIndex.group(of: .nodule, confidence: 0.5) == .inflamed)
        #expect(GroupedBreakoutIndex.group(of: .nodule, confidence: GroupedBreakoutIndex.noduleMinConfidence) == .nodule)
        #expect(GroupedBreakoutIndex.index(for: [spot(.nodule, 0.5)]) == 2)
    }
}

@Suite("Detection pipeline")
struct DetectionPipelineTests {
    private let imageSize = CGSize(width: 1000, height: 2000)
    private let face = ImageRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2)

    @Test("Baseline plans one run over the square face crop, exactly as before the refactor")
    func baselinePlan() {
        let plan = DetectionPipeline(configuration: .baseline).plan(imageSize: imageSize, face: face)
        let expectedCrop = FaceCrop.squarePixelRect(face: face, imageSize: imageSize).integral
        #expect(plan.cropRect == expectedCrop)
        #expect(plan.tiles.count == 1)
        #expect(plan.region(of: plan.tiles[0]) == expectedCrop)
    }

    @Test("Without a face the whole image is used")
    func noFace() {
        let plan = DetectionPipeline(configuration: .baseline).plan(imageSize: imageSize, face: nil)
        #expect(plan.cropRect == CGRect(origin: .zero, size: imageSize))
    }

    @Test("Tiled regions stay inside the crop and are whole pixels")
    func tiledRegions() {
        let config = DetectionPipeline.Configuration(tiling: .twoByTwoWithWhole)
        let plan = DetectionPipeline(configuration: config).plan(imageSize: imageSize, face: face)
        #expect(plan.tiles.count == 5)
        #expect(plan.tiles.allSatisfy { plan.cropRect.contains(plan.region(of: $0)) })
        #expect(plan.tiles.allSatisfy { $0.rect == $0.rect.integral })
    }

    @Test("Baseline merge equals mapping to image space + the old filter")
    func baselineMerge() {
        let pipeline = DetectionPipeline(configuration: .baseline)
        let plan = pipeline.plan(imageSize: imageSize, face: face)
        let raw = [
            RawDetection(type: .papule, confidence: 0.6, box: rect(0.2, 0.2, 0.05, 0.05)),
            RawDetection(type: .pustule, confidence: 0.8, box: rect(0.205, 0.2, 0.05, 0.05)),
            RawDetection(type: .blackhead, confidence: 0.3, box: rect(0.7, 0.7, 0.01, 0.01)),
        ]
        let merged = pipeline.merge([raw], plan: plan, mask: nil)
        let region = plan.region(of: plan.tiles[0])
        let expected = DetectionFilter.filter(raw.map {
            RawDetection(type: $0.type, confidence: $0.confidence,
                         box: ImageSpace.toImage($0.box, region: region, imageSize: imageSize))
        })
        #expect(merged == expected)
        #expect(merged.count == 1)
    }

    @Test("A lesion near a tile seam is counted once")
    func seamCountedOnce() throws {
        let config = DetectionPipeline.Configuration(tiling: Tiling(grid: 2, overlap: 0.2, includesWholeCrop: true))
        let pipeline = DetectionPipeline(configuration: config)
        let plan = pipeline.plan(imageSize: imageSize, face: face)
        // One real lesion in image space, right where the left column ends (inside the overlap band).
        let leftTile = try #require(plan.tiles.first { $0.interiorEdges == [.right, .bottom] })
        let leftRegion = plan.region(of: leftTile)
        let lesionPixels = CGRect(x: leftRegion.maxX - 6, y: leftRegion.minY + 100, width: 12, height: 12)
        let lesion = ImageSpace.normalized(lesionPixels, imageSize: imageSize)

        // Fake model: every run that sees any of the lesion reports it, clipped to what it sees (like a real detector).
        let outputs = plan.tiles.map { tile -> [RawDetection] in
            let region = plan.region(of: tile)
            let visible = region.intersection(lesionPixels)
            guard !visible.isNull, visible.width > 0 else { return [] }
            let box = ImageSpace.toRegion(ImageSpace.normalized(visible, imageSize: imageSize),
                                          region: region, imageSize: imageSize)
            return [RawDetection(type: .whitehead, confidence: 0.9, box: box)]
        }
        #expect(outputs.filter { !$0.isEmpty }.count >= 3, "left tile (cut), right tile (whole) and whole crop see it")
        let merged = pipeline.merge(outputs, plan: plan, mask: nil)
        #expect(merged.count == 1)
        #expect(DetectionMatching.isSameSpot(try #require(merged.first).box, as: lesion, imageSize: imageSize))
    }

    @Test("The skin mask removes detections whose centre is on a masked feature")
    func masked() {
        let pipeline = DetectionPipeline(configuration: .baseline)
        let plan = pipeline.plan(imageSize: CGSize(width: 100, height: 100), face: nil)
        let blocker = FacePolygon([
            ImagePoint(x: 0, y: 0), ImagePoint(x: 0.5, y: 0), ImagePoint(x: 0.5, y: 1), ImagePoint(x: 0, y: 1),
        ])
        let mask = SkinMask(faceRegion: nil, excluded: [blocker])
        let merged = pipeline.merge([[
            RawDetection(type: .papule, confidence: 0.9, box: rect(0.1, 0.5, 0.05, 0.05)),
            RawDetection(type: .papule, confidence: 0.9, box: rect(0.8, 0.5, 0.05, 0.05)),
        ]], plan: plan, mask: mask)
        #expect(merged.count == 1)
        #expect(isClose(merged.first?.box.x ?? 0, 0.8))
    }

    @Test("detect() crops each planned region, runs the model once per region, in plan order")
    func detectGlue() throws {
        let image = try #require(Self.solidImage(width: 200, height: 300))
        let config = DetectionPipeline.Configuration(tiling: .twoByTwoWithWhole)
        let pipeline = DetectionPipeline(configuration: config)
        let faceBox = ImageRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4)
        let plan = pipeline.plan(imageSize: CGSize(width: 200, height: 300), face: faceBox)
        var seenSizes: [CGSize] = []
        _ = try pipeline.detect(in: image, face: faceBox, mask: nil) { tile in
            seenSizes.append(CGSize(width: tile.width, height: tile.height))
            return []
        }
        #expect(seenSizes == plan.tiles.map { plan.region(of: $0).size })
    }

    @Test("The shipping configuration and its version move together")
    func shippingVersion() {
        // Changing `.shipping` changes users' numbers: bump `shippingVersion` and update this test (ML-PLAN M1.7).
        #expect(DetectionPipeline.Configuration.shipping == .baseline)
        #expect(DetectionPipeline.shippingVersion == "2d-1")
    }

    static func solidImage(width: Int, height: Int) -> CGImage? {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(CGColor(red: 0.8, green: 0.6, blue: 0.5, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage()
    }
}

@Suite("Counting versions (ML-PLAN M1.7)")
struct CountingVersionTests {
    private func version(_ model: String, _ pipeline: String?) -> CountingVersion {
        CountingVersion(modelVersion: model, pipelineVersion: pipeline)
    }

    @Test("Scans from before versioning count the same as pipeline 2d-1, so shipping versioning adds no marker")
    func unversionedEqualsFirst() {
        #expect(version("acneObj28200", nil) == version("acneObj28200", "2d-1"))
    }

    @Test("A marker is placed on the first scan counted differently")
    func changePoints() {
        let versions = [
            version("legacy", nil),
            version("acneObj28200", nil),
            version("acneObj28200", "2d-1"),
            version("acneObj28200", "2d-2"),
            version("acneObj28200", "2d-2"),
        ]
        #expect(CountingVersion.changePoints(versions) == [1, 3])
        #expect(CountingVersion.changePoints([]) == [])
    }
}
