import Foundation
import simd

/// Fuses the front capture with the turned captures into one head surface with real sides.
///
/// After registration (`MultiViewRegistration`) every view's depth is resampled onto one grid wrapped around the head's
/// vertical axis — radius as a function of (azimuth, height) — weighting each view by how squarely it looks at that
/// patch of head (the front photo dominates the face). The texture is baked the same way: every texel blends the
/// photos that see it. The result is a single mesh + single texture: no seams, cracks or overlapping shells.
/// Developed and verified offline on real three-angle TrueDepth captures.
public enum MultiViewFusion {
    public struct Result: Sendable {
        /// App convention: centred, x right, y up, z toward the viewer (metres).
        public let vertices: [SIMD3<Float>]
        public let indices: [UInt16]
        /// Into `texture`; V grows upward.
        public let textureCoordinates: [SIMD2<Float>]
        /// Position in the front photo (normalized, top-left) for vertices the front camera sees; (−1, −1) otherwise.
        public let projected: [SIMD2<Float>]
        public let texture: PhotoPixels
        /// Recovered head turn of each registered side view (degrees, signed).
        public let sideYawDegrees: [Float]
        /// The point (front-camera frame) that was moved to the origin.
        public let centre: SIMD3<Float>
    }

    // Grid: 250 × 250 nodes stay under the 16-bit index limit of stored meshes.
    static let columns = 250
    static let rows = 250
    static let azimuthLimit: Float = 135 * .pi / 180
    /// The texture wraps ±135° of head, so the face gets about a third of its width: 2048 keeps the face near the
    /// front photo's own resolution (1024 left it at ~350 px across, visibly soft).
    static let textureSide = 2048
    /// The front photo owns the front of the face: its weight ramps up smoothly (no step, which drew a hard oval seam)
    /// from this facing…
    static let frontRampStart: Float = 0.4
    /// …to full dominance here (~45°).
    static let frontRampEnd: Float = 0.7
    static let frontDominance: Float = 6
    static let bleedCells = 6
    /// Views count only where they see the surface better than this (cosine between surface direction and view).
    static let minimumFacing: Float = 0.25
    /// A view's own measured normal must face it at least this much (edge-on depth is unreliable).
    static let minimumOwnFacing: Float = 0.3
    /// Anything further than this from the head's vertical axis is shoulder, not head.
    static let maximumAxisDistance: Float = 0.145
    /// Lips → chin, and how far behind the surface centroid the head's centre lies.
    static let lipsToChin: Float = 0.04
    static let centreDepth: Float = 0.055
    static let depthAgreement: Float = 0.012

    public static func fuse(front frontView: ScanView, sides sideViews: [ScanView]) -> Result? {
        guard let front = MultiViewRegistration.prepare(frontView) else { return nil }
        var views = [front]
        var poses = [RigidTransform.identity]
        for sideView in sideViews {
            guard let side = MultiViewRegistration.prepare(sideView),
                  let pose = MultiViewRegistration.register(side, to: front) else { continue }
            views.append(side)
            poses.append(pose)
        }
        guard views.count > 1 else { return nil }
        let frame = HeadFrame(front: front, views: views, poses: poses)
        guard let frame else { return nil }
        let gains = brightnessGains(frame)
        let radius = fuseRadius(frame)
        return buildResult(frame, radius: radius, gains: gains)
    }

    // MARK: - Head frame

    /// Everything expressed in the front camera's frame (x right, y down, z forward).
    struct HeadFrame {
        let views: [PreparedView]
        let poses: [RigidTransform]
        let cameraCentres: [SIMD3<Float>]
        let centre: SIMD3<Float>
        let chinY: Float
        let topY: Float

        init?(front: PreparedView, views: [PreparedView], poses: [RigidTransform]) {
            // The lips sit at the 85th percentile of the landmarks' heights (the single lowest can land on the neck).
            let heights = front.landmarks3D.compactMap { $0?.y }.sorted()
            guard heights.count >= 6 else { return nil }
            let chin = heights[heights.count * 85 / 100] + MultiViewFusion.lipsToChin
            var sum = SIMD3<Float>.zero
            var count: Float = 0
            for index in 0..<(front.width * front.height) where front.mask[index] && front.points[index].y < chin {
                sum += front.points[index]
                count += 1
            }
            guard count > 100 else { return nil }
            let centre = sum / count + SIMD3(0, 0, MultiViewFusion.centreDepth)
            // Top of the head: robust minimum height of head points near the axis.
            var tops: [Float] = []
            for (view, pose) in zip(views, poses) {
                for index in stride(from: 0, to: view.width * view.height, by: 5) where view.mask[index] {
                    let p = pose.apply(view.points[index])
                    if simd_length(SIMD2(p.x - centre.x, p.z - centre.z)) < MultiViewFusion.maximumAxisDistance { tops.append(p.y) }
                }
            }
            guard tops.count > 100 else { return nil }
            tops.sort()
            self.views = views
            self.poses = poses
            cameraCentres = poses.map(\.translation)
            self.centre = centre
            chinY = chin
            topY = tops[tops.count / 200] - 0.004
        }

        /// Lower limit of the head at depth z: the jaw line rises from the chin (front) to the ear lobe (back).
        func jawLimit(_ z: Float) -> Float {
            let front = centre.z - 0.07, back = centre.z + 0.02
            let t = min(max((z - front) / (back - front), 0), 1)
            return chinY + (0.012 - MultiViewFusion.lipsToChin) * t
        }

        func cylindrical(_ p: SIMD3<Float>) -> (azimuth: Float, radius: Float) {
            let dx = p.x - centre.x, dz = centre.z - p.z // dz > 0 toward the camera
            return (atan2(dx, dz), (dx * dx + dz * dz).squareRoot())
        }

        func point(azimuth: Float, y: Float, radius: Float) -> SIMD3<Float> {
            SIMD3(centre.x + radius * sin(azimuth), y, centre.z - radius * cos(azimuth))
        }

        /// How squarely camera `view` looks at the patch of head around `p`, judged by direction from the head centre
        /// (smooth, and identical for every view).
        func facing(_ view: Int, _ p: SIMD3<Float>) -> Float {
            simd_dot(simd_normalize(p - centre), simd_normalize(cameraCentres[view] - p))
        }

        func weight(_ view: Int, _ p: SIMD3<Float>) -> Float {
            let f = facing(view, p)
            guard f > MultiViewFusion.minimumFacing else { return 0 }
            let base = pow(f - MultiViewFusion.minimumFacing, 3)
            guard view == 0 else { return base }
            return base * (1 + (MultiViewFusion.frontDominance - 1) * MultiViewFusion.smoothstep(
                MultiViewFusion.frontRampStart, MultiViewFusion.frontRampEnd, f))
        }

        func seen(by view: Int, _ p: SIMD3<Float>) -> (u: Float, v: Float)? {
            views[view].pixelSeeing(poses[view].unapply(p), tolerance: MultiViewFusion.depthAgreement)
        }

        func azimuth(column: Float) -> Float {
            -MultiViewFusion.azimuthLimit + 2 * MultiViewFusion.azimuthLimit * column / Float(MultiViewFusion.columns - 1)
        }

        func y(row: Float) -> Float { topY + (chinY - topY) * row / Float(MultiViewFusion.rows - 1) }
    }

    // MARK: - Geometry

    private struct Sample {
        let column: Float
        let row: Float
        let radius: Float
        let weight: Float
    }

    /// Radius per grid node (NaN where no view measured the head).
    static func fuseRadius(_ frame: HeadFrame) -> [Float] {
        var samples: [Sample] = []
        for (index, view) in frame.views.enumerated() {
            let pose = frame.poses[index]
            for pixel in 0..<(view.width * view.height) where view.mask[pixel] {
                let p = pose.apply(view.points[pixel])
                guard p.y < frame.jawLimit(p.z), p.y > frame.topY else { continue }
                if view.normals[pixel] != .zero,
                   simd_dot(pose.rotation * view.normals[pixel], simd_normalize(frame.cameraCentres[index] - p)) < minimumOwnFacing { continue }
                let weight = frame.weight(index, p)
                guard weight > 0 else { continue }
                let c = frame.cylindrical(p)
                guard c.radius < maximumAxisDistance, abs(c.azimuth) < azimuthLimit else { continue }
                samples.append(Sample(column: (c.azimuth + azimuthLimit) / (2 * azimuthLimit) * Float(columns - 1),
                                      row: (p.y - frame.topY) / (frame.chinY - frame.topY) * Float(rows - 1),
                                      radius: c.radius, weight: weight))
            }
        }
        func accumulate(rejecting mean: [Float]?) -> [Float] {
            var sum = [Float](repeating: 0, count: columns * rows), weights = [Float](repeating: 0, count: columns * rows)
            for sample in samples {
                let c0 = Int(sample.column), r0 = Int(sample.row)
                let fc = sample.column - Float(c0), fr = sample.row - Float(r0)
                let corners: [(Int, Int, Float)] = [(0, 0, (1 - fc) * (1 - fr)), (1, 0, fc * (1 - fr)), (0, 1, (1 - fc) * fr), (1, 1, fc * fr)]
                for (dc, dr, share) in corners where share > 0 {
                    let c = c0 + dc, r = r0 + dr
                    guard c >= 0, r >= 0, c < columns, r < rows else { continue }
                    let cell = r * columns + c
                    if let mean, mean[cell].isFinite, abs(sample.radius - mean[cell]) > 0.005 { continue } // outlier
                    sum[cell] += sample.weight * share * sample.radius
                    weights[cell] += sample.weight * share
                }
            }
            return (0..<(columns * rows)).map { weights[$0] > 1e-5 ? sum[$0] / weights[$0] : .nan }
        }
        var radius = accumulate(rejecting: accumulate(rejecting: nil))

        // Close pinholes between samples (cells surrounded by measured surface); the surface is never extended outward.
        for _ in 0..<2 {
            var next = radius
            for r in 1..<(rows - 1) {
                for c in 1..<(columns - 1) where !radius[r * columns + c].isFinite {
                    var sum: Float = 0, count: Float = 0
                    for dr in -1...1 {
                        for dc in -1...1 where dr != 0 || dc != 0 {
                            let value = radius[(r + dr) * columns + c + dc]
                            if value.isFinite { sum += value; count += 1 }
                        }
                    }
                    if count >= 6 { next[r * columns + c] = sum / count }
                }
            }
            radius = next
        }
        // Light smoothing of sensor noise (neighbours within 3 mm only, so edges stay).
        var smoothed = radius
        for r in 1..<(rows - 1) {
            for c in 1..<(columns - 1) where radius[r * columns + c].isFinite {
                let centre = radius[r * columns + c]
                var sum = centre * 2, count: Float = 2
                for dr in -1...1 {
                    for dc in -1...1 where dr != 0 || dc != 0 {
                        let value = radius[(r + dr) * columns + c + dc]
                        if value.isFinite, abs(value - centre) < 0.003 { sum += value; count += 1 }
                    }
                }
                smoothed[r * columns + c] = sum / count
            }
        }
        return smoothed
    }

    // MARK: - Colour

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Per-channel gains for each side view so its exposure and white balance match the front photo where both see
    /// the same skin (each shot is auto-exposed and auto-white-balanced on its own, which left pink sides against a
    /// yellower front). The front photo is the reference and is never changed.
    static let gainLimits: ClosedRange<Float> = 0.8...1.25

    static func brightnessGains(_ frame: HeadFrame) -> [SIMD3<Float>] {
        var gains = [SIMD3<Float>](repeating: SIMD3(1, 1, 1), count: frame.views.count)
        for index in 1..<frame.views.count {
            let view = frame.views[index]
            var ratios: [SIMD3<Float>] = []
            for pixel in stride(from: 0, to: view.width * view.height, by: 7) where view.mask[pixel] {
                let p = frame.poses[index].apply(view.points[pixel])
                guard let inFront = frame.seen(by: 0, p) else { continue }
                let own = sample(view.photo, u: (Float(pixel % view.width) + 0.5) / Float(view.width),
                                 v: (Float(pixel / view.width) + 0.5) / Float(view.height))
                let reference = sample(frame.views[0].photo, u: inFront.u, v: inFront.v)
                if min(own.x, own.y, own.z) > 20 { ratios.append(reference / own) }
            }
            guard ratios.count > 200 else { continue }
            func median(_ channel: KeyPath<SIMD3<Float>, Float>) -> Float {
                let sorted = ratios.map { $0[keyPath: channel] }.sorted()
                return min(max(sorted[sorted.count / 2], gainLimits.lowerBound), gainLimits.upperBound)
            }
            gains[index] = SIMD3(median(\.x), median(\.y), median(\.z))
        }
        return gains
    }

    /// Bilinear RGB sample at normalized (top-left) coordinates.
    static func sample(_ photo: PhotoPixels, u: Float, v: Float) -> SIMD3<Float> {
        let maxX = Float(photo.width) - 1.001, maxY = Float(photo.height) - 1.001
        let rawX: Float = u * Float(photo.width) - 0.5, rawY: Float = v * Float(photo.height) - 0.5
        let x: Float = min(max(rawX, 0), maxX), y: Float = min(max(rawY, 0), maxY)
        let x0 = Int(x), y0 = Int(y)
        let fx = x - Float(x0), fy = y - Float(y0)
        func pixel(_ px: Int, _ py: Int) -> SIMD3<Float> {
            let offset = (py * photo.width + px) * 4
            return SIMD3(Float(photo.rgba[offset]), Float(photo.rgba[offset + 1]), Float(photo.rgba[offset + 2]))
        }
        let top = pixel(x0, y0) * (1 - fx) + pixel(x0 + 1, y0) * fx
        let bottom = pixel(x0, y0 + 1) * (1 - fx) + pixel(x0 + 1, y0 + 1) * fx
        return top * (1 - fy) + bottom * fy
    }

    // MARK: - Mesh + texture

    static func buildResult(_ frame: HeadFrame, radius: [Float], gains: [SIMD3<Float>]) -> Result? {
        var points: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], projected: [SIMD2<Float>] = []
        var node = [Int](repeating: -1, count: columns * rows)
        for r in 0..<rows {
            for c in 0..<columns where radius[r * columns + c].isFinite {
                let p = frame.point(azimuth: frame.azimuth(column: Float(c)), y: frame.y(row: Float(r)), radius: radius[r * columns + c])
                node[r * columns + c] = points.count
                points.append(p)
                uvs.append(SIMD2(Float(c) / Float(columns - 1), 1 - Float(r) / Float(rows - 1)))
                if frame.facing(0, p) > 0.3, let seen = frame.seen(by: 0, p) {
                    projected.append(SIMD2(seen.u, seen.v))
                } else {
                    projected.append(SIMD2(-1, -1))
                }
            }
        }
        guard points.count >= 3, points.count < Int(UInt16.max) else { return nil }

        var indices: [UInt16] = []
        func add(_ a: Int, _ b: Int, _ c: Int) {
            guard a >= 0, b >= 0, c >= 0 else { return }
            guard simd_distance(points[a], points[b]) < 0.015, simd_distance(points[b], points[c]) < 0.015,
                  simd_distance(points[a], points[c]) < 0.015 else { return }
            indices.append(contentsOf: [UInt16(a), UInt16(b), UInt16(c)])
        }
        for r in 0..<(rows - 1) {
            for c in 0..<(columns - 1) {
                let topLeft = node[r * columns + c], topRight = node[r * columns + c + 1]
                let bottomLeft = node[(r + 1) * columns + c], bottomRight = node[(r + 1) * columns + c + 1]
                add(topLeft, bottomLeft, topRight)
                add(topRight, bottomLeft, bottomRight)
            }
        }
        indices = droppingFragments(indices, vertexCount: points.count)
        guard !indices.isEmpty else { return nil }

        // Centre on what is drawn; app convention flips y (up) and z (toward the viewer).
        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude), upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for index in indices {
            lower = simd_min(lower, points[Int(index)])
            upper = simd_max(upper, points[Int(index)])
        }
        let centre = (lower + upper) / 2
        let vertices = points.map { SIMD3($0.x - centre.x, -($0.y - centre.y), -($0.z - centre.z)) }
        let sideYaws = frame.poses.dropFirst().map(\.yawDegrees)
        return Result(vertices: vertices, indices: indices, textureCoordinates: uvs, projected: projected,
                      texture: bakeTexture(frame, radius: radius, gains: gains), sideYawDegrees: Array(sideYaws), centre: centre)
    }

    /// Keeps connected pieces with a meaningful number of triangles.
    private static func droppingFragments(_ indices: [UInt16], vertexCount: Int, minimumTriangles: Int = 400) -> [UInt16] {
        var parent = Array(0..<vertexCount)
        func find(_ x: Int) -> Int {
            var root = x
            while parent[root] != root {
                parent[root] = parent[parent[root]]
                root = parent[root]
            }
            return root
        }
        for t in stride(from: 0, to: indices.count, by: 3) {
            let a = find(Int(indices[t]))
            parent[find(Int(indices[t + 1]))] = a
            parent[find(Int(indices[t + 2]))] = a
        }
        var triangles: [Int: Int] = [:]
        for t in stride(from: 0, to: indices.count, by: 3) { triangles[find(Int(indices[t])), default: 0] += 1 }
        let largest = triangles.values.max() ?? 0
        let threshold = min(minimumTriangles, largest)
        var kept: [UInt16] = []
        kept.reserveCapacity(indices.count)
        for t in stride(from: 0, to: indices.count, by: 3) where triangles[find(Int(indices[t])), default: 0] >= threshold {
            kept.append(contentsOf: [indices[t], indices[t + 1], indices[t + 2]])
        }
        return kept
    }

    /// Azimuth across, height down; every texel blends the photos that see that point of the head.
    static func bakeTexture(_ frame: HeadFrame, radius: [Float], gains: [SIMD3<Float>]) -> PhotoPixels {
        let side = textureSide
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        var covered = [Bool](repeating: false, count: side * side)
        func radiusAt(column: Float, row: Float) -> Float? {
            let c0 = Int(column), r0 = Int(row)
            guard c0 >= 0, r0 >= 0, c0 < columns - 1, r0 < rows - 1 else { return nil }
            let a = radius[r0 * columns + c0], b = radius[r0 * columns + c0 + 1]
            let c = radius[(r0 + 1) * columns + c0], d = radius[(r0 + 1) * columns + c0 + 1]
            guard a.isFinite, b.isFinite, c.isFinite, d.isFinite else { return nil }
            let fc = column - Float(c0), fr = row - Float(r0)
            return (a * (1 - fc) + b * fc) * (1 - fr) + (c * (1 - fc) + d * fc) * fr
        }
        for ty in 0..<side {
            let row = Float(ty) / Float(side - 1) * Float(rows - 1)
            for tx in 0..<side {
                let column = Float(tx) / Float(side - 1) * Float(columns - 1)
                guard let r = radiusAt(column: column, row: row) else { continue }
                let p = frame.point(azimuth: frame.azimuth(column: column), y: frame.y(row: row), radius: r)
                var colour = SIMD3<Float>.zero
                var total: Float = 0
                for view in 0..<frame.views.count {
                    let weight = frame.weight(view, p)
                    guard weight > 0, let seen = frame.seen(by: view, p) else { continue }
                    colour += sample(frame.views[view].photo, u: seen.u, v: seen.v) * gains[view] * weight
                    total += weight
                }
                guard total > 0 else { continue }
                colour /= total
                let offset = (ty * side + tx) * 4
                rgba[offset] = UInt8(min(max(colour.x, 0), 255))
                rgba[offset + 1] = UInt8(min(max(colour.y, 0), 255))
                rgba[offset + 2] = UInt8(min(max(colour.z, 0), 255))
                rgba[offset + 3] = 255
                covered[ty * side + tx] = true
            }
        }
        // Bleed colour outward so mesh edges (and texels no view claimed) never sample empty texture: about six grid
        // cells' worth, whatever the texture size.
        for _ in 0..<(bleedCells * side / columns) {
            var next = rgba
            var nextCovered = covered
            var changed = false
            for ty in 1..<(side - 1) {
                for tx in 1..<(side - 1) where !covered[ty * side + tx] {
                    var sum = SIMD3<Float>.zero
                    var count: Float = 0
                    for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where covered[(ty + dy) * side + tx + dx] {
                        let offset = ((ty + dy) * side + tx + dx) * 4
                        sum += SIMD3(Float(rgba[offset]), Float(rgba[offset + 1]), Float(rgba[offset + 2]))
                        count += 1
                    }
                    guard count > 0 else { continue }
                    let offset = (ty * side + tx) * 4
                    next[offset] = UInt8(sum.x / count)
                    next[offset + 1] = UInt8(sum.y / count)
                    next[offset + 2] = UInt8(sum.z / count)
                    next[offset + 3] = 255
                    nextCovered[ty * side + tx] = true
                    changed = true
                }
            }
            rgba = next
            covered = nextCovered
            if !changed { break }
        }
        return PhotoPixels(width: side, height: side, rgba: rgba)
    }
}
