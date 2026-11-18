import Foundation
import simd

/// RGBA8 pixels of an upright photo (row 0 = top).
public struct PhotoPixels: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]

    public init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba = rgba
    }
}

/// One capture of the head: its depth map, where the face is, feature landmarks and the photo.
public struct ScanView: Sendable {
    public let depth: DepthMap
    /// Vision face box (normalized, bottom-left origin) in the upright photo.
    public let faceBox: ImageRect
    /// Feature landmarks (eyes, brows, nose, lips — not the face contour), normalized, top-left origin, in the same
    /// order for every view of a scan.
    public let landmarks: [SIMD2<Float>]
    public let photo: PhotoPixels

    public init(depth: DepthMap, faceBox: ImageRect, landmarks: [SIMD2<Float>], photo: PhotoPixels) {
        self.depth = depth
        self.faceBox = faceBox
        self.landmarks = landmarks
        self.photo = photo
    }
}

/// p ↦ R·p + t
struct RigidTransform {
    var rotation: simd_float3x3
    var translation: SIMD3<Float>

    static let identity = RigidTransform(rotation: matrix_identity_float3x3, translation: .zero)

    func apply(_ point: SIMD3<Float>) -> SIMD3<Float> { rotation * point + translation }
    /// Inverse applied to a point: Rᵀ(p − t).
    func unapply(_ point: SIMD3<Float>) -> SIMD3<Float> { rotation.transpose * (point - translation) }
    /// Turn about the vertical axis, in degrees.
    var yawDegrees: Float { atan2(rotation.columns.2.x, rotation.columns.2.z) * 180 / .pi }
}

/// A view with its head segmented and lifted to 3D (camera frame: x right, y down, z forward).
struct PreparedView {
    let width: Int
    let height: Int
    let depth: [Float]
    let intrinsics: CameraIntrinsics
    let mask: [Bool]
    let points: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    /// Landmarks lifted onto the head surface (nil where a landmark misses it).
    let landmarks3D: [SIMD3<Float>?]
    let photo: PhotoPixels

    /// The pixel where this camera sees camera-frame point `q`, if the measured depth there agrees.
    func pixelSeeing(_ q: SIMD3<Float>, tolerance: Float) -> (u: Float, v: Float)? {
        guard q.z > 0.05 else { return nil }
        let x = intrinsics.fx * q.x / q.z + intrinsics.cx, y = intrinsics.fy * q.y / q.z + intrinsics.cy
        let column = Int(x.rounded()), row = Int(y.rounded())
        guard column >= 0, row >= 0, column < width, row < height else { return nil }
        let index = row * width + column
        guard mask[index], abs(depth[index] - q.z) < tolerance else { return nil }
        return (x / Float(width), y / Float(height))
    }
}

/// Segments the head in each view and finds how the head moved between views.
///
/// A (bald) head is close to a ball, so sliding surfaces onto each other cannot tell how far it turned. The pose is
/// therefore anchored on facial landmarks lifted to 3D (RANSAC rejects landmarks hidden in a turned view), then refined
/// with point-to-plane ICP that keeps those anchors as a constraint.
enum MultiViewRegistration {
    static let landmarkInlierDistance: Float = 0.007
    static let minimumLandmarkInliers = 8
    static let ransacIterations = 3000
    static let icpIterations = 50
    /// Registration is rejected above this surface error (metres) or below this many matched surface points.
    static let maximumSurfaceError: Float = 0.006
    static let minimumSurfaceInliers = 300

    // MARK: Per-view preparation

    static func prepare(_ view: ScanView) -> PreparedView? {
        let width = view.depth.width, height = view.depth.height
        let depth = view.depth.meters
        guard width > 8, height > 8, depth.count == width * height else { return nil }
        let k = view.depth.intrinsics ?? CameraIntrinsics(fx: Float(max(width, height)) * 0.87, fy: Float(max(width, height)) * 0.87,
                                                           cx: Float(width) / 2, cy: Float(height) / 2)
        // Face box → top-left pixels.
        let x0 = clamp(Int(view.faceBox.x * Double(width)), width), x1 = clamp(Int((view.faceBox.x + view.faceBox.width) * Double(width)), width)
        let y0 = clamp(Int((1 - view.faceBox.y - view.faceBox.height) * Double(height)), height)
        let y1 = clamp(Int((1 - view.faceBox.y) * Double(height)), height)
        guard x1 > x0, y1 > y0 else { return nil }

        var inBox: [Float] = []
        for y in y0...y1 {
            for x in x0...x1 {
                let z = depth[y * width + x]
                if z.isFinite, z > 0 { inBox.append(z) }
            }
        }
        guard !inBox.isEmpty else { return nil }
        inBox.sort()
        let reference = inBox[inBox.count / 2]

        // Head = region grown from the face, in a depth band around it, between the top of the head and the neck.
        let boxHeight = y1 - y0
        let neckRow = min(height - 1, y1 + Int(Float(boxHeight) * 0.30))
        let topRow = max(0, y0 - Int(Float(boxHeight) * 1.2))
        func accepted(_ index: Int) -> Bool {
            let z = depth[index]
            return z.isFinite && z > reference - 0.14 && z < reference + 0.22
        }
        var mask = [Bool](repeating: false, count: width * height)
        var seed = ((y0 + y1) / 2) * width + (x0 + x1) / 2
        if !accepted(seed) {
            guard let near = (y0...y1).lazy.flatMap({ y in (x0...x1).lazy.map { y * width + $0 } }).first(where: accepted) else { return nil }
            seed = near
        }
        var stack = [seed]
        mask[seed] = true
        while let index = stack.popLast() {
            let x = index % width, y = index / width
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && ny >= topRow && nx < width && ny <= neckRow {
                let next = ny * width + nx
                if !mask[next], accepted(next), abs(depth[next] - depth[index]) < 0.02 {
                    mask[next] = true
                    stack.append(next)
                }
            }
        }

        let points: [SIMD3<Float>] = (0..<(width * height)).map { index in
            let z = depth[index]
            return SIMD3((Float(index % width) - k.cx) / k.fx * z, (Float(index / width) - k.cy) / k.fy * z, z)
        }
        var normals = [SIMD3<Float>](repeating: .zero, count: width * height)
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let index = y * width + x
                guard mask[index], mask[index - 2], mask[index + 2], mask[index - 2 * width], mask[index + 2 * width] else { continue }
                let normal = simd_cross(points[index + 2] - points[index - 2], points[index + 2 * width] - points[index - 2 * width])
                let length = simd_length(normal)
                guard length > 0 else { continue }
                normals[index] = normal.z > 0 ? -normal / length : normal / length // toward the camera
            }
        }
        let landmarks3D: [SIMD3<Float>?] = view.landmarks.map { landmark in
            let x = Int((landmark.x * Float(width)).rounded()), y = Int((landmark.y * Float(height)).rounded())
            guard x >= 0, y >= 0, x < width, y < height, mask[y * width + x] else { return nil }
            return points[y * width + x]
        }
        return PreparedView(width: width, height: height, depth: depth, intrinsics: k, mask: mask, points: points,
                            normals: normals, landmarks3D: landmarks3D, photo: view.photo)
    }

    // MARK: Pose

    /// Side-view camera → front-view camera, or nil when the views can't be registered reliably.
    static func register(_ side: PreparedView, to front: PreparedView) -> RigidTransform? {
        let pairs = zip(side.landmarks3D, front.landmarks3D).compactMap { a, b -> (SIMD3<Float>, SIMD3<Float>)? in
            guard let a, let b else { return nil }
            return (a, b)
        }
        guard pairs.count >= minimumLandmarkInliers else { return nil }
        var generator = LinearCongruentialGenerator(seed: 0x5EED)
        var best: [(SIMD3<Float>, SIMD3<Float>)] = []
        for _ in 0..<ransacIterations {
            let pick = (0..<4).map { _ in pairs[Int(generator.next() % UInt64(pairs.count))] }
            let candidate = horn(pick.map(\.0), pick.map(\.1))
            let inliers = pairs.filter { simd_distance(candidate.apply($0.0), $0.1) < landmarkInlierDistance }
            if inliers.count > best.count { best = inliers }
        }
        guard best.count >= minimumLandmarkInliers else { return nil }
        let initial = horn(best.map(\.0), best.map(\.1))
        let refined = anchoredICP(source: side, target: front, initial: initial, anchors: best)
        guard refined.inliers >= minimumSurfaceInliers, refined.error <= maximumSurfaceError else { return nil }
        return refined.transform
    }

    /// Horn's closed-form absolute orientation: R, t minimising Σ|R·a + t − b|².
    static func horn(_ a: [SIMD3<Float>], _ b: [SIMD3<Float>]) -> RigidTransform {
        let count = Float(a.count)
        let centreA = a.reduce(.zero, +) / count, centreB = b.reduce(.zero, +) / count
        var s = [[Double]](repeating: [0, 0, 0], count: 3) // s[i][j] = Σ p_i q_j
        for index in a.indices {
            let p = a[index] - centreA, q = b[index] - centreB
            let pv = [Double(p.x), Double(p.y), Double(p.z)], qv = [Double(q.x), Double(q.y), Double(q.z)]
            for i in 0..<3 { for j in 0..<3 { s[i][j] += pv[i] * qv[j] } }
        }
        let n = simd_double4x4(rows: [
            SIMD4(s[0][0] + s[1][1] + s[2][2], s[1][2] - s[2][1], s[2][0] - s[0][2], s[0][1] - s[1][0]),
            SIMD4(s[1][2] - s[2][1], s[0][0] - s[1][1] - s[2][2], s[0][1] + s[1][0], s[2][0] + s[0][2]),
            SIMD4(s[2][0] - s[0][2], s[0][1] + s[1][0], -s[0][0] + s[1][1] - s[2][2], s[1][2] + s[2][1]),
            SIMD4(s[0][1] - s[1][0], s[2][0] + s[0][2], s[1][2] + s[2][1], -s[0][0] - s[1][1] + s[2][2]),
        ])
        // Largest eigenvector by power iteration on a positively shifted matrix.
        var shift = 0.0
        for column in 0..<4 { for row in 0..<4 { shift += abs(n[column][row]) } }
        let shifted = n + simd_double4x4(diagonal: SIMD4(repeating: shift))
        var q = SIMD4<Double>(1, 0.1, 0.1, 0.1)
        for _ in 0..<200 { q = simd_normalize(shifted * q) }
        let rotation = simd_float3x3(simd_quatf(ix: Float(q.y), iy: Float(q.z), iz: Float(q.w), r: Float(q.x)))
        return RigidTransform(rotation: rotation, translation: centreB - rotation * centreA)
    }

    /// Point-to-plane ICP with projective association, anchored by landmark pairs (point-to-point) so the head can't
    /// slide round.
    static func anchoredICP(source: PreparedView, target: PreparedView, initial: RigidTransform,
                            anchors: [(SIMD3<Float>, SIMD3<Float>)]) -> (transform: RigidTransform, inliers: Int, error: Float) {
        var transform = initial
        let samples = stride(from: 0, to: source.width * source.height, by: 3).filter {
            source.mask[$0] && source.normals[$0] != .zero && ($0 / source.width) % 3 == 0
        }
        var inliers = 0
        var error: Float = 1
        for iteration in 0..<icpIterations {
            let maximumDistance: Float = iteration < 15 ? 0.02 : 0.01
            var a = [[Double]](repeating: [Double](repeating: 0, count: 6), count: 6)
            var b = [Double](repeating: 0, count: 6)
            var count = 0
            var squared: Float = 0
            for index in samples {
                let q = transform.apply(source.points[index])
                guard q.z > 0.05 else { continue }
                let k = target.intrinsics
                let column = Int((k.fx * q.x / q.z + k.cx).rounded()), row = Int((k.fy * q.y / q.z + k.cy).rounded())
                guard column >= 0, row >= 0, column < target.width, row < target.height else { continue }
                let match = row * target.width + column
                guard target.mask[match], target.normals[match] != .zero else { continue }
                let normal = target.normals[match]
                let difference = q - target.points[match]
                guard simd_length(difference) < maximumDistance,
                      simd_dot(transform.rotation * source.normals[index], normal) > 0.4 else { continue }
                let residual = simd_dot(difference, normal)
                let cross = simd_cross(q, normal)
                let jacobian = [Double(cross.x), Double(cross.y), Double(cross.z), Double(normal.x), Double(normal.y), Double(normal.z)]
                for i in 0..<6 {
                    for j in 0..<6 { a[i][j] += jacobian[i] * jacobian[j] }
                    b[i] -= jacobian[i] * Double(residual)
                }
                count += 1
                squared += residual * residual
            }
            inliers = count
            error = count > 0 ? (squared / Float(count)).squareRoot() : 1
            // Each anchor pulls with a share of the surface points' weight. The anchors dominate at first (they fix
            // the turn, which surfaces alone can't), then fade so their few-millimetre noise doesn't bias the final fit.
            let anchorShare: Double = iteration < 15 ? 2 : (iteration < 30 ? 0.5 : 0.1)
            let weight = Double(max(count, 300)) * anchorShare / Double(max(anchors.count, 1))
            for (from, to) in anchors {
                let q = transform.apply(from), d = q - to
                let rows: [[Double]] = [
                    [0, Double(q.z), Double(-q.y), 1, 0, 0],
                    [Double(-q.z), 0, Double(q.x), 0, 1, 0],
                    [Double(q.y), Double(-q.x), 0, 0, 0, 1],
                ]
                let residuals = [Double(d.x), Double(d.y), Double(d.z)]
                for r in 0..<3 {
                    for i in 0..<6 {
                        for j in 0..<6 { a[i][j] += weight * rows[r][i] * rows[r][j] }
                        b[i] -= weight * rows[r][i] * residuals[r]
                    }
                }
            }
            for i in 0..<6 { a[i][i] += 1e-6 }
            guard let step = solve(a, b) else { break }
            let omega = SIMD3(Float(step[0]), Float(step[1]), Float(step[2]))
            let shift = SIMD3(Float(step[3]), Float(step[4]), Float(step[5]))
            let angle = simd_length(omega)
            let delta = angle > 1e-9 ? simd_float3x3(simd_quatf(angle: angle, axis: omega / angle)) : matrix_identity_float3x3
            transform = RigidTransform(rotation: delta * transform.rotation, translation: delta * transform.translation + shift)
        }
        return (transform, inliers, error)
    }

    /// Gaussian elimination with partial pivoting for the 6×6 normal equations.
    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var m = matrix
        var v = vector
        let n = 6
        for column in 0..<n {
            var pivot = column
            for row in column..<n where abs(m[row][column]) > abs(m[pivot][column]) { pivot = row }
            guard abs(m[pivot][column]) > 1e-12 else { return nil }
            m.swapAt(column, pivot)
            v.swapAt(column, pivot)
            for row in (column + 1)..<n {
                let factor = m[row][column] / m[column][column]
                for j in column..<n { m[row][j] -= factor * m[column][j] }
                v[row] -= factor * v[column]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for column in stride(from: n - 1, through: 0, by: -1) {
            var sum = v[column]
            for j in (column + 1)..<n { sum -= m[column][j] * x[j] }
            x[column] = sum / m[column][column]
        }
        return x
    }

    private static func clamp(_ value: Int, _ size: Int) -> Int { min(max(value, 0), size - 1) }
}

/// Small deterministic generator so registration gives the same answer for the same scan.
struct LinearCongruentialGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 16
    }
}
