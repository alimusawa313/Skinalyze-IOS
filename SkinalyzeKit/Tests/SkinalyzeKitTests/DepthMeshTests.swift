import Foundation
import simd
import Testing
@testable import SkinalyzeKit

/// TrueDepth depth map → real face mesh (every scan on Face ID iPhones).
@Suite("TrueDepth face mesh")
struct DepthMeshTests {
    static let width = 120
    static let height = 160
    /// Face box (Vision, bottom-left origin) centred in the frame.
    static let faceBox = ImageRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

    /// A wall at 1 m with a "face": a 9 cm-tall dome at ~45 cm (nose closest) inside the face box.
    static func domeDepth() -> DepthMap {
        var meters = [Float](repeating: 1.0, count: width * height)
        let cx = Float(width) / 2, cy = Float(height) / 2
        let radius = Float(width) * 0.3
        for y in 0..<height {
            for x in 0..<width {
                let dx = Float(x) - cx, dy = Float(y) - cy
                let r2 = (dx * dx + dy * dy) / (radius * radius)
                if r2 < 1 { meters[y * width + x] = 0.49 - 0.09 * (1 - r2).squareRoot() }
            }
        }
        return DepthMap(width: width, height: height, meters: meters,
                        intrinsics: CameraIntrinsics(fx: 110, fy: 110, cx: Float(width) / 2, cy: Float(height) / 2))
    }

    @Test("Builds a real mesh from the face's depth: valid indices, UVs in range, fits UInt16")
    func buildsMesh() throws {
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data([1])))
        #expect(mesh.vertices.count > 200)
        #expect(mesh.vertices.count < Int(UInt16.max))
        #expect(mesh.indices.count.isMultiple(of: 3))
        #expect(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count })
        #expect(mesh.textureCoordinates.count == mesh.vertices.count)
        #expect(mesh.textureCoordinates.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        #expect(mesh.projectedIsPhotoSpace)
        #expect(!mesh.mirroredProjection)
    }

    @Test("The wall behind the head is cut away")
    func dropsBackground() throws {
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data()))
        // Every vertex is within the face's depth range (the wall sits ~0.5 m behind).
        #expect(mesh.vertices.allSatisfy { $0.z > -DepthMeshBuilder.maxDepthBehindFace - 0.01 })
    }

    @Test("Geometry is real: the closest point (nose) bulges toward the viewer, centred on the face")
    func noseIsClosest() throws {
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data()))
        let nearest = try #require(mesh.vertices.max { $0.z < $1.z })
        let farthest = try #require(mesh.vertices.min { $0.z < $1.z })
        #expect(nearest.z - farthest.z > 0.05) // centimetres of relief, not a flat card
        #expect(abs(nearest.x) < 0.02 && abs(nearest.y) < 0.03)
        // Metric scale: the dome spans tens of centimetres, not pixels with these intrinsics.
        let xs = mesh.vertices.map(\.x)
        #expect((0.1...0.4).contains((xs.max() ?? 0) - (xs.min() ?? 0)))
    }

    @Test("Triangles face the viewer (counter-clockwise from +Z) so the textured side is visible")
    func windingFacesViewer() throws {
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data()))
        let v = mesh.vertices
        let i = mesh.indices.prefix(3).map(Int.init)
        let a = v[i[1]] - v[i[0]], b = v[i[2]] - v[i[0]]
        #expect(a.x * b.y - a.y * b.x > 0)
    }

    @Test("No usable depth (all invalid) yields no mesh instead of a broken one")
    func invalidDepth() {
        let empty = DepthMap(width: 10, height: 10, meters: .init(repeating: .nan, count: 100), intrinsics: nil)
        #expect(DepthMeshBuilder.build(depth: empty, faceBox: Self.faceBox, texture: Data()) == nil)
    }

    @Test("Pins on photo-space meshes use the detection's photo position directly")
    func photoSpacePins() throws {
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data()))
        let center = DetectionDraft(type: .papule, confidence: 0.9,
                                    box: ImageRect(x: 0.49, y: 0.49, width: 0.02, height: 0.02), captureAngle: .front)
        let pin = try #require(FacePinMapper.pins(for: [center], photoFace: Self.faceBox, mesh: mesh).first)
        let projected = mesh.projected[pin.vertexIndex]
        #expect(abs(projected.x - 0.5) < 0.05 && abs(projected.y - 0.5) < 0.05)
    }

    // MARK: High quality (fusion, cleanup)

    @Test("Fusing several noisy depth frames (median) recovers the true surface and rejects outliers")
    func fusionDenoises() throws {
        let truth = Self.domeDepth()
        var frames: [DepthMap] = []
        var generator = SeededGenerator(seed: 7)
        for frame in 0..<9 {
            let noisy = truth.meters.map { $0 + Float.random(in: -0.004...0.004, using: &generator) }
            var meters = noisy
            if frame == 3 { meters[80 * Self.width + 60] = 0.05 } // a flying-pixel outlier
            frames.append(DepthMap(width: Self.width, height: Self.height, meters: meters, intrinsics: truth.intrinsics))
        }
        let fused = try #require(DepthFusion.median(frames))
        let centre = 80 * Self.width + 60
        #expect(abs(fused.meters[centre] - truth.meters[centre]) < 0.002)
        let errors = zip(fused.meters, truth.meters).map { abs($0 - $1) }
        #expect(errors.reduce(0, +) / Float(errors.count) < 0.0015)
    }

    @Test("Only frames that match the photo's own depth are fused (mirrored/moved frames are rejected)")
    func fusionRejectsMismatchedFrames() {
        // An asymmetric face: dome shifted left of centre, so a mirrored frame doesn't line up.
        var meters = [Float](repeating: 1.0, count: Self.width * Self.height)
        for y in 0..<Self.height {
            for x in 0..<Self.width {
                let dx = Float(x - 45), dy = Float(y - 80)
                let r2 = (dx * dx + dy * dy) / (30 * 30)
                if r2 < 1 { meters[y * Self.width + x] = 0.49 - 0.09 * (1 - r2).squareRoot() }
            }
        }
        let photo = DepthMap(width: Self.width, height: Self.height, meters: meters, intrinsics: nil)
        var mirroredMeters = meters
        for y in 0..<Self.height {
            for x in 0..<Self.width { mirroredMeters[y * Self.width + x] = meters[y * Self.width + (Self.width - 1 - x)] }
        }
        let mirrored = DepthMap(width: Self.width, height: Self.height, meters: mirroredMeters, intrinsics: nil)
        let slightlyNoisy = DepthMap(width: Self.width, height: Self.height,
                                     meters: meters.map { $0 + 0.002 }, intrinsics: nil)
        let kept = DepthFusion.consistent([mirrored, slightlyNoisy, mirrored], with: photo)
        #expect(kept.count == 1)
        #expect(kept.first == slightlyNoisy)
    }

    @Test("A face mask keeps only the face (no hair, headphones, neck)")
    func faceMaskLimitsMesh() throws {
        // Mask covers only the right half of the photo.
        let side = 64
        var alpha = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side { for x in (side / 2)..<side { alpha[y * side + x] = 255 } }
        let mask = FaceMask(width: side, height: side, alpha: alpha)
        let mesh = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data(), mask: mask))
        #expect(mesh.projected.allSatisfy { $0.x >= 0.5 - 0.02 })
        #expect(mesh.vertices.count > 50)
    }

    @Test("The mask only removes samples — depth of what's kept is identical to the unmasked build")
    func maskNeverAltersDepth() throws {
        let side = 64
        var alpha = [UInt8](repeating: 255, count: side * side)
        for y in 0..<side { for x in 0..<(side / 2) { alpha[y * side + x] = 0 } } // drop the left half
        let masked = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data(),
                                                         mask: FaceMask(width: side, height: side, alpha: alpha)))
        let full = try #require(DepthMeshBuilder.build(depth: Self.domeDepth(), faceBox: Self.faceBox, texture: Data()))
        // Every kept vertex exists, with the same position, in the unmasked mesh.
        let fullByUV = Dictionary(zip(full.projected.map { "\($0.x),\($0.y)" }, full.vertices), uniquingKeysWith: { a, _ in a })
        for (uv, vertex) in zip(masked.projected, masked.vertices) {
            let match = try #require(fullByUV["\(uv.x),\(uv.y)"])
            #expect(simd_distance(match, vertex) < 0.0001)
        }
    }

    @Test("Face mask samples by normalized position")
    func faceMaskSampling() {
        let mask = FaceMask(width: 2, height: 2, alpha: [0, 255, 0, 255])
        #expect(mask.value(u: 0.75, v: 0.25) == 1)
        #expect(mask.value(u: 0.25, v: 0.75) == 0)
    }

    @Test("Fusion fills a hole that only some frames have")
    func fusionFillsHoles() throws {
        let truth = Self.domeDepth()
        var holed = truth.meters
        holed[80 * Self.width + 60] = .nan
        let frames = [DepthMap(width: Self.width, height: Self.height, meters: holed, intrinsics: nil), truth, truth]
        let fused = try #require(DepthFusion.median(frames))
        #expect(fused.meters[80 * Self.width + 60].isFinite)
    }

    @Test("Quarter-turn rotation matches the photo's orientation (and swaps intrinsics)")
    func rotation() {
        // 3 wide × 2 tall: [a b c / d e f]
        let map = DepthMap(width: 3, height: 2, meters: [1, 2, 3, 4, 5, 6],
                           intrinsics: CameraIntrinsics(fx: 10, fy: 20, cx: 1.5, cy: 1))
        let clockwise = map.rotated(quarterTurnsClockwise: 1)
        #expect(clockwise.width == 2 && clockwise.height == 3)
        #expect(clockwise.meters == [4, 1, 5, 2, 6, 3]) // [d a / e b / f c]
        #expect(clockwise.intrinsics?.fx == 20 && clockwise.intrinsics?.fy == 10)
        #expect(map.rotated(quarterTurnsClockwise: 4).meters == map.meters)
        #expect(map.rotated(quarterTurnsClockwise: 2).meters == [6, 5, 4, 3, 2, 1])
    }

    @Test("Surfaces seen edge-on (the stretched streaks at jaw and neck) are cut away")
    func dropsGrazingTriangles() throws {
        // Left half: the face (dome). Right of the dome: a ramp that recedes 3 cm per pixel — nearly edge-on.
        var depth = Self.domeDepth().meters
        for y in 60..<100 {
            for x in 84..<92 { depth[y * Self.width + x] = 0.42 + Float(x - 84) * 0.03 }
        }
        let map = DepthMap(width: Self.width, height: Self.height, meters: depth, intrinsics: Self.domeDepth().intrinsics)
        let mesh = try #require(DepthMeshBuilder.build(depth: map, faceBox: Self.faceBox, texture: Data()))
        let v = mesh.vertices
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = v[Int(mesh.indices[t])], b = v[Int(mesh.indices[t + 1])], c = v[Int(mesh.indices[t + 2])]
            let n = simd_cross(b - a, c - a)
            let length = simd_length(n)
            guard length > 0 else { continue }
            // Viewer looks along -Z: no kept triangle may be steeper than the cut-off.
            #expect(abs(n.z) / length >= DepthMeshBuilder.minFacingCosine - 0.001)
        }
    }

    @Test("Detached fragments (headphones, hair strands) are dropped — only the face piece is kept")
    func keepsLargestPiece() throws {
        var depth = Self.domeDepth().meters
        // A gap of no depth, then a small island at face depth near the top-left of the region.
        for y in 30..<40 {
            for x in 30..<40 { depth[y * Self.width + x] = 0.42 }
        }
        let map = DepthMap(width: Self.width, height: Self.height, meters: depth, intrinsics: Self.domeDepth().intrinsics)
        let mesh = try #require(DepthMeshBuilder.build(depth: map, faceBox: Self.faceBox, texture: Data()))
        let islandU = Float(35) / Float(Self.width), islandV = Float(35) / Float(Self.height)
        #expect(!mesh.projected.contains { abs($0.x - islandU) < 0.04 && abs($0.y - islandV) < 0.04 })
    }
}

/// Deterministic RNG so noise tests are repeatable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
