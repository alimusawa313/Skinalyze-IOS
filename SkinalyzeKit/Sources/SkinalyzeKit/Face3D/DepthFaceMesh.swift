import Foundation
import simd

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

    /// Nearest-neighbour resample (streamed depth can come at a different size than the photo's depth).
    public func resampled(width newWidth: Int, height newHeight: Int) -> DepthMap {
        guard newWidth != width || newHeight != height, newWidth > 0, newHeight > 0 else { return self }
        var out = [Float](repeating: .nan, count: newWidth * newHeight)
        for y in 0..<newHeight {
            let sy = min(height - 1, y * height / newHeight)
            for x in 0..<newWidth {
                out[y * newWidth + x] = meters[sy * width + min(width - 1, x * width / newWidth)]
            }
        }
        return DepthMap(width: newWidth, height: newHeight, meters: out, intrinsics: nil)
    }

    /// Rotates by quarter turns (clockwise), e.g. to match a photo's EXIF orientation. Intrinsics follow.
    public func rotated(quarterTurnsClockwise turns: Int) -> DepthMap {
        let n = ((turns % 4) + 4) % 4
        guard n != 0 else { return self }
        let w = width, h = height
        let swaps = n % 2 == 1
        let outW = swaps ? h : w, outH = swaps ? w : h
        var out = [Float](repeating: .nan, count: meters.count)
        for y in 0..<outH {
            for x in 0..<outW {
                let source: (Int, Int) = switch n {
                case 1: (y, h - 1 - x)          // clockwise
                case 2: (w - 1 - x, h - 1 - y)  // half turn
                default: (w - 1 - y, x)         // counter-clockwise
                }
                out[y * outW + x] = meters[source.1 * w + source.0]
            }
        }
        let k = intrinsics.map { k in
            swaps ? CameraIntrinsics(fx: k.fy, fy: k.fx, cx: Float(outW) / 2, cy: Float(outH) / 2)
                  : CameraIntrinsics(fx: k.fx, fy: k.fy, cx: Float(outW) / 2, cy: Float(outH) / 2)
        }
        return DepthMap(width: outW, height: outH, meters: out, intrinsics: k)
    }
}

/// Temporal fusion of a burst of depth frames taken while the user holds still: the per-pixel median removes sensor
/// noise and flying pixels and fills holes that only some frames have.
public enum DepthFusion {
    public static func median(_ maps: [DepthMap]) -> DepthMap? {
        guard let first = maps.first,
              maps.allSatisfy({ $0.width == first.width && $0.height == first.height && $0.meters.count == first.meters.count })
        else { return nil }
        guard maps.count > 1 else { return first }
        let minimumSamples = max(1, maps.count / 3)
        var fused = [Float](repeating: .nan, count: first.meters.count)
        var samples: [Float] = []
        samples.reserveCapacity(maps.count)
        for index in fused.indices {
            samples.removeAll(keepingCapacity: true)
            for map in maps {
                let value = map.meters[index]
                if value.isFinite, value > 0 { samples.append(value) }
            }
            guard samples.count >= minimumSamples else { continue }
            samples.sort()
            let mid = samples.count / 2
            fused[index] = samples.count.isMultiple(of: 2) ? (samples[mid - 1] + samples[mid]) / 2 : samples[mid]
        }
        return DepthMap(width: first.width, height: first.height, meters: fused,
                        intrinsics: first.intrinsics ?? maps.lazy.compactMap(\.intrinsics).first)
    }
}

/// Turns the front photo's (fused) TrueDepth depth map into a real, metric mesh of the user's face, textured with that
/// photo. Quality steps: edge-preserving smoothing, the noisy rim eroded, only the largest connected piece kept (no
/// floating headphone/hair fragments), and triangles seen edge-on dropped (no stretched streaks at jaw and neck).
public enum DepthMeshBuilder {
    /// Grid resolution cap; the vertex count must stay under `UInt16` indices (the step grows if needed).
    public static let maxGridSide = 220
    /// How far behind the face's reference depth a point may be and still count as the face (cheek → ear).
    public static let maxDepthBehindFace: Float = 0.08
    /// How far in front of the reference depth a point may be (nose tip).
    public static let maxDepthInFront: Float = 0.08
    /// Neighbouring samples further apart in depth than this are not connected (silhouette edges).
    public static let maxEdgeJump: Float = 0.02
    /// Triangles whose normal is further than ~75° from the viewer are dropped (edge-on streaks).
    public static let minFacingCosine: Float = 0.25
    /// Range kernel of the bilateral smoothing (metres): smooths sensor noise, keeps nose and brow edges.
    static let smoothingSigma: Float = 0.004
    /// Margins around Vision's face box (which stops at the brows): forehead above, a little of the sides and jaw.
    static let sideMargin = 0.12
    static let topMargin = 0.32
    static let bottomMargin = 0.05

    public static func build(depth: DepthMap, faceBox: ImageRect, texture: Data) -> FaceMeshDraft? {
        let width = depth.width, height = depth.height
        guard width > 2, height > 2, depth.meters.count == width * height,
              let region = pixelRegion(faceBox, width: width, height: height),
              let reference = referenceDepth(depth, faceBox: faceBox) else { return nil }
        var step = max(1, max(region.x1 - region.x0, region.y1 - region.y0) / maxGridSide)
        while step <= 8 {
            if let mesh = build(depth: depth, faceBox: faceBox, texture: texture, region: region,
                                reference: reference, step: step) {
                return mesh
            }
            step += 1
        }
        return nil
    }

    // MARK: - Steps

    private struct Region {
        let x0: Int, y0: Int, x1: Int, y1: Int
    }

    /// One attempt at a grid step; nil when nothing usable or too many vertices for `UInt16` indices.
    private static func build(depth: DepthMap, faceBox: ImageRect, texture: Data, region: Region,
                              reference: Float, step: Int) -> FaceMeshDraft? {
        let width = depth.width, height = depth.height
        let intrinsics = depth.intrinsics ?? defaultIntrinsics(width: width, height: height)
        let accepts = { (z: Float) in z >= reference - maxDepthInFront && z <= reference + maxDepthBehindFace }
        let columns = (region.x1 - region.x0) / step + 1
        let rows = (region.y1 - region.y0) / step + 1

        // 1. Sample with edge-preserving smoothing.
        var grid = [Float](repeating: .nan, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let px = region.x0 + column * step, py = region.y0 + row * step
                grid[row * columns + column] = smoothedDepth(depth, px, py, radius: max(2, step), accepts: accepts) ?? .nan
            }
        }
        // 2. Erode the rim (depth at silhouettes is the noisiest) and 3. keep only the largest connected piece.
        grid = eroded(grid, columns: columns, rows: rows)
        grid = largestPiece(grid, columns: columns, rows: rows)

        // 4. Vertices.
        var index = [Int](repeating: -1, count: columns * rows)
        var points: [SIMD3<Float>] = [], depths: [Float] = [], uvs: [SIMD2<Float>] = [], projected: [SIMD2<Float>] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let z = grid[row * columns + column]
                guard z.isFinite else { continue }
                let px = region.x0 + column * step, py = region.y0 + row * step
                index[row * columns + column] = points.count
                depths.append(z)
                points.append(unproject(Float(px), Float(py), z: z, intrinsics))
                let u = (Float(px) + 0.5) / Float(width), v = (Float(py) + 0.5) / Float(height)
                uvs.append(SIMD2(u, 1 - v)) // texture V grows upward
                projected.append(SIMD2(u, v))
            }
        }
        guard points.count >= 3, points.count < Int(UInt16.max) else { return nil }

        // Centre on the face box (at reference depth); flip depth so the face bulges toward the viewer (+Z).
        let centre = unproject(Float((faceBox.x + faceBox.width / 2) * Double(width)),
                               Float((1 - faceBox.y - faceBox.height / 2) * Double(height)),
                               z: reference, intrinsics)
        let vertices = points.map { SIMD3($0.x - centre.x, $0.y - centre.y, reference - $0.z) }

        // 5. Triangles: skip holes, depth jumps and edge-on faces.
        let indices = triangulate(index: index, columns: columns, rows: rows, depths: depths, vertices: vertices)
        guard !indices.isEmpty else { return nil }
        return FaceMeshDraft(vertices: vertices, indices: indices, textureCoordinates: uvs, projected: projected,
                             texture: texture, mirroredProjection: false, projectedIsPhotoSpace: true)
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

    /// Bilateral mean of accepted depths around (x, y): neighbours at a similar depth count, edges don't blur.
    private static func smoothedDepth(_ depth: DepthMap, _ x: Int, _ y: Int, radius: Int,
                                      accepts: (Float) -> Bool) -> Float? {
        guard let centre = depth.depth(x, y), accepts(centre) else { return nil }
        let twoSigmaSquared = 2 * smoothingSigma * smoothingSigma
        var sum: Float = 0
        var weights: Float = 0
        for ny in max(0, y - radius)...min(depth.height - 1, y + radius) {
            for nx in max(0, x - radius)...min(depth.width - 1, x + radius) {
                guard let z = depth.depth(nx, ny), accepts(z) else { continue }
                let difference = z - centre
                guard abs(difference) <= maxEdgeJump else { continue }
                let weight = exp(-difference * difference / twoSigmaSquared)
                sum += z * weight
                weights += weight
            }
        }
        return weights > 0 ? sum / weights : centre
    }

    /// Drops samples on the rim (any 4-neighbour missing).
    private static func eroded(_ grid: [Float], columns: Int, rows: Int) -> [Float] {
        var out = grid
        for row in 0..<rows {
            for column in 0..<columns where grid[row * columns + column].isFinite {
                let neighbours = [(column - 1, row), (column + 1, row), (column, row - 1), (column, row + 1)]
                let onRim = neighbours.contains { c, r in
                    c < 0 || r < 0 || c >= columns || r >= rows || !grid[r * columns + c].isFinite
                }
                if onRim { out[row * columns + column] = .nan }
            }
        }
        return out
    }

    /// Keeps only the largest 4-connected piece (connections never cross a depth jump).
    private static func largestPiece(_ grid: [Float], columns: Int, rows: Int) -> [Float] {
        var label = [Int](repeating: -1, count: grid.count)
        var sizes: [Int] = []
        for start in grid.indices where grid[start].isFinite && label[start] < 0 {
            let id = sizes.count
            var stack = [start]
            label[start] = id
            var size = 0
            while let cell = stack.popLast() {
                size += 1
                let column = cell % columns, row = cell / columns
                for (c, r) in [(column - 1, row), (column + 1, row), (column, row - 1), (column, row + 1)] {
                    guard c >= 0, r >= 0, c < columns, r < rows else { continue }
                    let next = r * columns + c
                    guard label[next] < 0, grid[next].isFinite, abs(grid[next] - grid[cell]) <= maxEdgeJump else { continue }
                    label[next] = id
                    stack.append(next)
                }
            }
            sizes.append(size)
        }
        guard let keep = sizes.indices.max(by: { sizes[$0] < sizes[$1] }) else { return grid }
        return grid.indices.map { label[$0] == keep ? grid[$0] : .nan }
    }

    private static func unproject(_ px: Float, _ py: Float, z: Float, _ k: CameraIntrinsics) -> SIMD3<Float> {
        SIMD3((px - k.cx) / k.fx * z, -(py - k.cy) / k.fy * z, z)
    }

    /// Two triangles per grid cell, counter-clockwise seen from the viewer, skipping holes, jumps and edge-on faces.
    private static func triangulate(index: [Int], columns: Int, rows: Int, depths: [Float],
                                    vertices: [SIMD3<Float>]) -> [UInt16] {
        var indices: [UInt16] = []
        func add(_ a: Int, _ b: Int, _ c: Int) {
            guard a >= 0, b >= 0, c >= 0 else { return }
            let lo = min(depths[a], depths[b], depths[c]), hi = max(depths[a], depths[b], depths[c])
            guard hi - lo <= maxEdgeJump else { return }
            let normal = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            let length = simd_length(normal)
            guard length > 0, abs(normal.z) / length >= minFacingCosine else { return }
            indices.append(contentsOf: [UInt16(a), UInt16(b), UInt16(c)])
        }
        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                let topLeft = index[row * columns + column], topRight = index[row * columns + column + 1]
                let bottomLeft = index[(row + 1) * columns + column], bottomRight = index[(row + 1) * columns + column + 1]
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
