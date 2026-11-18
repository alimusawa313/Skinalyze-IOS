import Foundation
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
}
