import Foundation
import SwiftData
import Testing
@testable import SkinalyzeKit

@Suite("3D face mesh")
struct FaceMeshTests {
    private let triangle = FaceMeshDraft(
        vertices: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0.1)],
        indices: [0, 1, 2, 1, 3, 2],
        textureCoordinates: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)],
        projected: [SIMD2(0.40, 0.40), SIMD2(0.60, 0.40), SIMD2(0.40, 0.60), SIMD2(0.60, 0.60)],
        texture: Data([1, 2, 3]),
        mirroredProjection: false
    )

    @Test("Mesh buffers round-trip through Data without loss")
    func roundTrip() {
        #expect(FaceMeshCodec.decodeVertices(FaceMeshCodec.encode(triangle.vertices)) == triangle.vertices)
        #expect(FaceMeshCodec.decodeIndices(FaceMeshCodec.encode(triangle.indices)) == triangle.indices)
        #expect(FaceMeshCodec.decodeUVs(FaceMeshCodec.encode(triangle.textureCoordinates)) == triangle.textureCoordinates)
    }

    @Test("Pins land on the nearest projected vertex, mapped through the face boxes")
    func pinMapping() {
        // Photo face box covers 0.2…0.8; the mesh's projected face box covers 0.4…0.6.
        let photoFace = ImageRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let topRightOfPhotoFace = ImageRect(x: 0.79, y: 0.79, width: 0.01, height: 0.01) // near (0.8, 0.8) Vision coords
        let pins = FacePinMapper.pins(
            for: [DetectionDraft(type: .papule, confidence: 0.9, box: topRightOfPhotoFace, captureAngle: .front)],
            photoFace: photoFace,
            mesh: triangle
        )
        // Vision y is bottom-up; projected coords are top-down → photo top-right maps to projected (0.6, 0.4) = vertex 1.
        #expect(pins == [FacePin(vertexIndex: 1, type: .papule)])
    }

    @Test("Mirrored projections flip x before matching")
    func mirrored() {
        let mirrored = FaceMeshDraft(vertices: triangle.vertices, indices: triangle.indices,
                                     textureCoordinates: triangle.textureCoordinates, projected: triangle.projected,
                                     texture: triangle.texture, mirroredProjection: true)
        let photoFace = ImageRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let pins = FacePinMapper.pins(
            for: [DetectionDraft(type: .nodule, confidence: 0.9, box: ImageRect(x: 0.79, y: 0.79, width: 0.01, height: 0.01), captureAngle: .front)],
            photoFace: photoFace, mesh: mirrored
        )
        #expect(pins.first?.vertexIndex == 0)
    }

    @Test("Mesh record persists alongside its scan (additive model)")
    @MainActor
    func persists() throws {
        let container = try ModelContainer(for: Schema(SkinalyzeSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let session = ScanSession()
        context.insert(session)
        let record = FaceMeshRecord(draft: triangle, pins: [FacePin(vertexIndex: 2, type: .pustule)])
        context.insert(record)
        session.faceMesh = record
        try context.save()
        let fetched = try #require(try context.fetch(FetchDescriptor<ScanSession>()).first?.faceMesh)
        #expect(fetched.vertices == triangle.vertices)
        #expect(fetched.pins == [FacePin(vertexIndex: 2, type: .pustule)])
    }
}
