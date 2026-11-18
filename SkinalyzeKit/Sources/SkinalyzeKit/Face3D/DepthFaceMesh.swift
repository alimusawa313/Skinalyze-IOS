import Foundation

/// Pinhole intrinsics in depth-map pixel units.
public struct CameraIntrinsics: Sendable, Hashable {
    public let fx: Float
    public let fy: Float
    public let cx: Float
    public let cy: Float

    public init(fx: Float, fy: Float, cx: Float, cy: Float) {
        self.fx = fx
        self.fy = fy
        self.cx = cx
        self.cy = cy
    }
}

/// A TrueDepth depth map aligned with the stored front photo: upright, unmirrored, row-major, top-left origin.
/// Values are metres; NaN / ≤ 0 mean "no depth here".
public struct DepthMap: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let meters: [Float]
    public let intrinsics: CameraIntrinsics?

    public init(width: Int, height: Int, meters: [Float], intrinsics: CameraIntrinsics?) {
        self.width = width
        self.height = height
        self.meters = meters
        self.intrinsics = intrinsics
    }

    func depth(_ x: Int, _ y: Int) -> Float? {
        let value = meters[y * width + x]
        return value.isFinite && value > 0 ? value : nil
    }
}

/// Turns the front photo's TrueDepth depth map into a real, metric mesh of the user's face, textured with that photo.
/// The background is cut away (anything well behind the face) and triangles never bridge depth jumps (hair edges,
/// ears against the wall), so what you turn in the viewer is your actual face shape — not a generic template.
public enum DepthMeshBuilder {
    /// Grid resolution cap (keeps the mesh well under `UInt16` indices and fast to render).
    public static let maxGridSide = 150
    /// How far behind the face's reference depth a point may be and still count as "you" (ears, jaw).
    public static let maxDepthBehindFace: Float = 0.12
    /// How far in front of the reference depth a point may be (nose tip).
    public static let maxDepthInFront: Float = 0.08
    /// Triangles spanning a bigger depth step than this are dropped (silhouette edges).
    public static let maxEdgeJump: Float = 0.025
    /// Margins around Vision's face box (which stops at the brows): forehead above, ears at the sides, a bit of jaw.
    static let sideMargin = 0.2
    static let topMargin = 0.35
    static let bottomMargin = 0.12

    public static func build(depth: DepthMap, faceBox: ImageRect, texture: Data) -> FaceMeshDraft? {
        let width = depth.width, height = depth.height
        guard width > 2, height > 2, depth.meters.count == width * height,
              let region = pixelRegion(faceBox, width: width, height: height),
              let reference = referenceDepth(depth, faceBox: faceBox) else { return nil }
        let intrinsics = depth.intrinsics ?? defaultIntrinsics(width: width, height: height)
        let accepts = { (z: Float) in z >= reference - maxDepthInFront && z <= reference + maxDepthBehindFace }

        let step = max(1, max(region.x1 - region.x0, region.y1 - region.y0) / maxGridSide)
        let columns = (region.x1 - region.x0) / step + 1
        let rows = (region.y1 - region.y0) / step + 1
        var grid = [Int](repeating: -1, count: columns * rows)
        var depths: [Float] = []
        var points: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var projected: [SIMD2<Float>] = []

        for row in 0..<rows {
            for column in 0..<columns {
                let px = region.x0 + column * step, py = region.y0 + row * step
                guard let z = smoothedDepth(depth, px, py, radius: max(1, step / 2), accepts: accepts) else { continue }
                grid[row * columns + column] = points.count
                depths.append(z)
                points.append(unproject(Float(px), Float(py), z: z, intrinsics))
                let u = (Float(px) + 0.5) / Float(width), v = (Float(py) + 0.5) / Float(height)
                uvs.append(SIMD2(u, 1 - v)) // texture V grows upward
                projected.append(SIMD2(u, v))
            }
        }
        guard points.count >= 3, points.count < Int(UInt16.max) else { return nil }

        let indices = triangulate(grid: grid, columns: columns, rows: rows, depths: depths)
        guard !indices.isEmpty else { return nil }

        // Centre on the face box (at reference depth) so the viewer turns the head around the face; depth grows away
        // from the camera, so flip it: the face bulges toward the viewer (+Z).
        let centre = unproject(Float((faceBox.x + faceBox.width / 2) * Double(width)),
                               Float((1 - faceBox.y - faceBox.height / 2) * Double(height)),
                               z: reference, intrinsics)
        let vertices = points.map { SIMD3($0.x - centre.x, $0.y - centre.y, reference - $0.z) }

        return FaceMeshDraft(vertices: vertices, indices: indices, textureCoordinates: uvs, projected: projected,
                             texture: texture, mirroredProjection: false, projectedIsPhotoSpace: true)
    }

    // MARK: - Steps

    private struct Region {
        let x0: Int, y0: Int, x1: Int, y1: Int
    }

    private static func pixelRegion(_ box: ImageRect, width: Int, height: Int) -> Region? {
        let left = box.x - box.width * sideMargin
        let right = box.x + box.width * (1 + sideMargin)
        let top = 1 - (box.y + box.height) - box.height * topMargin
        let bottom = 1 - box.y + box.height * bottomMargin
        let x0 = clamp(Int(left * Double(width)), width), x1 = clamp(Int(right * Double(width)), width)
        let y0 = clamp(Int(top * Double(height)), height), y1 = clamp(Int(bottom * Double(height)), height)
        guard x1 - x0 >= 2, y1 - y0 >= 2 else { return nil }
        return Region(x0: x0, y0: y0, x1: x1, y1: y1)
    }

    /// Median depth of the central half of the face box — robust to holes and the odd stray pixel.
    private static func referenceDepth(_ depth: DepthMap, faceBox: ImageRect) -> Float? {
        let x0 = clamp(Int((faceBox.x + faceBox.width / 4) * Double(depth.width)), depth.width)
        let x1 = clamp(Int((faceBox.x + faceBox.width * 3 / 4) * Double(depth.width)), depth.width)
        let y0 = clamp(Int((1 - faceBox.y - faceBox.height * 3 / 4) * Double(depth.height)), depth.height)
        let y1 = clamp(Int((1 - faceBox.y - faceBox.height / 4) * Double(depth.height)), depth.height)
        guard x1 >= x0, y1 >= y0 else { return nil }
        var samples: [Float] = []
        for y in y0...y1 {
            for x in x0...x1 {
                if let z = depth.depth(x, y) { samples.append(z) }
            }
        }
        guard !samples.isEmpty else { return nil }
        samples.sort()
        return samples[samples.count / 2]
    }

    /// Mean of accepted depths around (x, y); nil when the centre itself has no accepted depth.
    private static func smoothedDepth(_ depth: DepthMap, _ x: Int, _ y: Int, radius: Int,
                                      accepts: (Float) -> Bool) -> Float? {
        guard let centre = depth.depth(x, y), accepts(centre) else { return nil }
        var sum: Float = 0
        var count: Float = 0
        for ny in max(0, y - radius)...min(depth.height - 1, y + radius) {
            for nx in max(0, x - radius)...min(depth.width - 1, x + radius) {
                guard let z = depth.depth(nx, ny), accepts(z), abs(z - centre) <= maxEdgeJump else { continue }
                sum += z
                count += 1
            }
        }
        return sum / count
    }

    private static func unproject(_ px: Float, _ py: Float, z: Float, _ k: CameraIntrinsics) -> SIMD3<Float> {
        SIMD3((px - k.cx) / k.fx * z, -(py - k.cy) / k.fy * z, z)
    }

    /// Two triangles per grid cell, counter-clockwise seen from the viewer, skipping holes and depth jumps.
    private static func triangulate(grid: [Int], columns: Int, rows: Int, depths: [Float]) -> [UInt16] {
        var indices: [UInt16] = []
        func add(_ a: Int, _ b: Int, _ c: Int) {
            guard a >= 0, b >= 0, c >= 0 else { return }
            let lo = min(depths[a], depths[b], depths[c]), hi = max(depths[a], depths[b], depths[c])
            guard hi - lo <= maxEdgeJump else { return }
            indices.append(contentsOf: [UInt16(a), UInt16(b), UInt16(c)])
        }
        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                let topLeft = grid[row * columns + column], topRight = grid[row * columns + column + 1]
                let bottomLeft = grid[(row + 1) * columns + column], bottomRight = grid[(row + 1) * columns + column + 1]
                add(topLeft, bottomLeft, topRight)
                add(topRight, bottomLeft, bottomRight)
            }
        }
        return indices
    }

    /// Roughly the TrueDepth front camera's field of view, used only when calibration data is missing.
    private static func defaultIntrinsics(width: Int, height: Int) -> CameraIntrinsics {
        let focal = Float(max(width, height)) * 0.87
        return CameraIntrinsics(fx: focal, fy: focal, cx: Float(width) / 2, cy: Float(height) / 2)
    }

    private static func clamp(_ value: Int, _ size: Int) -> Int { min(max(value, 0), size - 1) }
}
