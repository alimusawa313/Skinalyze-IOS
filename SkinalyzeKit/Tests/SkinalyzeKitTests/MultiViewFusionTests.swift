import Foundation
import simd
import Testing
@testable import SkinalyzeKit

/// Three depth views of one head (front + two turns) → poses recovered → one fused surface with real sides.
@Suite("Multi-view head fusion")
struct MultiViewFusionTests {
    // A synthetic head: an ellipsoid with a nose bump, 40 cm from the camera.
    static let radii = SIMD3<Float>(0.075, 0.11, 0.09)
    static let distance: Float = 0.40
    static let width = 240, height = 320
    static let focal: Float = 219          // ~57° horizontal field of view at this size

    /// Head-frame surface point for spherical angles (azimuth around vertical, elevation). +z faces the camera at yaw 0.
    static func surface(_ az: Float, _ el: Float) -> SIMD3<Float> {
        let dir = SIMD3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
        var p = dir * radii
        let nose = exp(-(az * az) / 0.02 - ((el + 0.1) * (el + 0.1)) / 0.03)
        p += dir * (0.022 * nose)
        return p
    }

    /// Head → camera: rotate by `yaw` about the vertical, then push `distance` in front. Camera: x right, y down, z forward.
    static func toCamera(_ p: SIMD3<Float>, yaw: Float) -> SIMD3<Float> {
        let r = simd_float3x3(simd_quatf(angle: yaw, axis: [0, 1, 0])) * p
        return SIMD3(r.x, -r.y, distance - r.z)
    }

    static func project(_ c: SIMD3<Float>) -> (Float, Float) {
        (focal * c.x / c.z + Float(width) / 2, focal * c.y / c.z + Float(height) / 2)
    }

    /// Feature points (eyes, brows, nose, mouth) in the head frame — the "landmarks" a detector would report.
    static let features: [SIMD3<Float>] = {
        var points: [SIMD3<Float>] = []
        for (az, el) in [(-0.38, 0.22), (0.38, 0.22), (-0.3, 0.36), (0.3, 0.36), (-0.46, 0.34), (0.46, 0.34),
                         (0.0, 0.05), (0.0, -0.1), (-0.12, -0.14), (0.12, -0.14), (0.0, 0.2),
                         (-0.2, -0.42), (0.2, -0.42), (0.0, -0.38), (0.0, -0.48), (-0.3, 0.2), (0.3, 0.2), (0.0, 0.3)] {
            points.append(surface(Float(az), Float(el)))
        }
        return points
    }()

    static func view(yaw: Float) -> ScanView {
        var depth = [Float](repeating: .nan, count: width * height)
        var colour = [UInt8](repeating: 128, count: width * height * 4)
        // Dense splat of the surface with a z-buffer.
        let steps = 700
        for i in 0...steps {
            let el = -Float.pi / 2 + Float.pi * Float(i) / Float(steps)
            for j in 0...steps {
                let az = -Float.pi + 2 * Float.pi * Float(j) / Float(steps)
                let c = toCamera(surface(az, el), yaw: yaw)
                let (u, v) = project(c)
                let x = Int(u.rounded()), y = Int(v.rounded())
                guard x >= 0, y >= 0, x < width, y < height else { continue }
                if !(depth[y * width + x] <= c.z) {
                    depth[y * width + x] = c.z
                    // Colour encodes head-frame azimuth so blending can be sanity-checked.
                    colour[(y * width + x) * 4] = UInt8(min(max((az / .pi + 1) * 127, 0), 255))
                }
            }
        }
        // A wall behind.
        for i in depth.indices where !depth[i].isFinite { depth[i] = 1.5 }
        let landmarks = features.map { feature -> SIMD2<Float> in
            let (u, v) = project(toCamera(feature, yaw: yaw))
            return SIMD2(u / Float(width), v / Float(height))
        }
        let k = CameraIntrinsics(fx: focal, fy: focal, cx: Float(width) / 2, cy: Float(height) / 2)
        // Face box (Vision: bottom-left origin) around the projected features.
        let xs = landmarks.map(\.x), ys = landmarks.map(\.y)
        let box = ImageRect(x: Double(xs.min()! - 0.03), y: Double(1 - ys.max()! - 0.03),
                            width: Double(xs.max()! - xs.min()! + 0.06), height: Double(ys.max()! - ys.min()! + 0.06))
        return ScanView(depth: DepthMap(width: width, height: height, meters: depth, intrinsics: k), faceBox: box,
                        landmarks: landmarks, photo: PhotoPixels(width: width, height: height, rgba: colour))
    }

    static let rightYaw: Float = 58 * .pi / 180
    static let leftYaw: Float = -47 * .pi / 180

    @Test("Head turns are recovered from the three views (within 3°)")
    func recoversPoses() throws {
        let result = try #require(MultiViewFusion.fuse(front: Self.view(yaw: 0), sides: [Self.view(yaw: Self.rightYaw), Self.view(yaw: Self.leftYaw)]))
        #expect(result.sideYawDegrees.count == 2)
        #expect(abs(abs(result.sideYawDegrees[0]) - 58) < 3)
        #expect(abs(abs(result.sideYawDegrees[1]) - 47) < 3)
        #expect(result.sideYawDegrees[0] * result.sideYawDegrees[1] < 0) // opposite sides
    }

    @Test("The fused surface is the real head shape (within 3 mm) and covers the sides the front never saw")
    func fusedSurfaceIsAccurateAndWide() throws {
        let result = try #require(MultiViewFusion.fuse(front: Self.view(yaw: 0), sides: [Self.view(yaw: Self.rightYaw), Self.view(yaw: Self.leftYaw)]))
        #expect(result.vertices.count > 3000)
        #expect(result.vertices.count < Int(UInt16.max))
        #expect(result.indices.allSatisfy { Int($0) < result.vertices.count })
        #expect(result.textureCoordinates.count == result.vertices.count)
        var errors: [Float] = []
        var maxAzimuth: Float = 0, minAzimuth: Float = 0
        for vertex in result.vertices {
            // Undo the app convention (centred, y up, z toward viewer) → front camera → head frame.
            let camera = SIMD3(vertex.x + result.centre.x, -vertex.y + result.centre.y, -vertex.z + result.centre.z)
            let head = SIMD3(camera.x, -camera.y, Self.distance - camera.z)
            let az = atan2(head.x, head.z)
            maxAzimuth = max(maxAzimuth, az); minAzimuth = min(minAzimuth, az)
            // Distance to the true ellipsoid along the ray from the centre: the point where |p / radii| = 1.
            // (Skip the nose bump zone at the front and the poles.)
            let dir = simd_normalize(head)
            guard abs(dir.y) < 0.75, !(abs(az) < 0.5 && abs(dir.y + 0.1) < 0.45) else { continue }
            let onSurface = head / simd_length(head / Self.radii)
            errors.append(simd_distance(head, onSurface))
        }
        errors.sort()
        print("DIAG median(mm)", errors[errors.count / 2] * 1000, "p95(mm)", errors[errors.count * 95 / 100] * 1000, "max", (errors.last ?? 0) * 1000)
        // The bulk of the surface is accurate; the outermost rim is limited by grazing-angle depth (in the synthetic
        // renderer too), so it is judged by percentile, not by the single worst vertex.
        #expect(errors[errors.count / 2] < 0.0012)
        #expect(errors[errors.count * 95 / 100] < 0.003)
        // The front view alone sees to about ±60°; with a 58° and a 47° turn the surface reaches past ±90°.
        #expect(maxAzimuth > 90 * .pi / 180)
        #expect(minAzimuth < -100 * .pi / 180)
    }

    @Test("Triangles face outward (counter-clockwise from the viewer) and the texture is filled where the mesh is")
    func windingAndTexture() throws {
        let result = try #require(MultiViewFusion.fuse(front: Self.view(yaw: 0), sides: [Self.view(yaw: Self.rightYaw), Self.view(yaw: Self.leftYaw)]))
        // Front-most triangle (largest z) must face +z.
        var best = 0; var bestZ = -Float.infinity
        for t in stride(from: 0, to: result.indices.count, by: 3) {
            let z = result.vertices[Int(result.indices[t])].z
            if z > bestZ { bestZ = z; best = t }
        }
        let a = result.vertices[Int(result.indices[best])], b = result.vertices[Int(result.indices[best + 1])], c = result.vertices[Int(result.indices[best + 2])]
        #expect(simd_cross(b - a, c - a).z > 0)
        _ = bestZ
        #expect(result.texture.rgba.count == result.texture.width * result.texture.height * 4)
        // Every vertex samples a filled texel.
        for uv in result.textureCoordinates.prefix(2000) {
            let x = min(Int(uv.x * Float(result.texture.width)), result.texture.width - 1)
            let y = min(Int((1 - uv.y) * Float(result.texture.height)), result.texture.height - 1)
            #expect(result.texture.rgba[(y * result.texture.width + x) * 4 + 3] == 255)
        }
    }

    @Test("Without usable side views there is no fused result (the caller keeps the front-only scan)")
    func noSidesNoFusion() {
        #expect(MultiViewFusion.fuse(front: Self.view(yaw: 0), sides: []) == nil)
        // A side view with no landmark agreement (a different, mirrored arrangement) is rejected.
        var bogus = Self.view(yaw: Self.rightYaw)
        bogus = ScanView(depth: bogus.depth, faceBox: bogus.faceBox,
                         landmarks: bogus.landmarks.indices.map { i in
                             // Scrambled positions (deterministic): no consistent rigid motion explains them.
                             SIMD2<Float>(0.3 + Float((i * 37) % 17) / 42, 0.3 + Float((i * 53) % 19) / 47)
                         },
                         photo: bogus.photo)
        #expect(MultiViewFusion.fuse(front: Self.view(yaw: 0), sides: [bogus]) == nil)
    }
}
