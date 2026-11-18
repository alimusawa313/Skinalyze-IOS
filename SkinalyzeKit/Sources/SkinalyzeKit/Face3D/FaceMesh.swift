import Foundation
import SwiftData

/// A captured ARKit face mesh, ready to persist. Only on Face ID iPhones — iPhone Duo has no Face ID sensor (2D only).
public struct FaceMeshDraft: Sendable, Hashable {
    public let vertices: [SIMD3<Float>]
    public let indices: [UInt16]
    /// Per-vertex coordinates into `texture` (the camera frame).
    public let textureCoordinates: [SIMD2<Float>]
    /// Per-vertex position in the upright portrait frame, normalized 0…1, top-left origin.
    public let projected: [SIMD2<Float>]
    /// Camera frame (JPEG/HEIC) used as the face texture.
    public let texture: Data
    /// `true` when `projected` is mirrored relative to the stored (unmirrored) photos.
    public let mirroredProjection: Bool

    public init(vertices: [SIMD3<Float>], indices: [UInt16], textureCoordinates: [SIMD2<Float>],
                projected: [SIMD2<Float>], texture: Data, mirroredProjection: Bool) {
        self.vertices = vertices
        self.indices = indices
        self.textureCoordinates = textureCoordinates
        self.projected = projected
        self.texture = texture
        self.mirroredProjection = mirroredProjection
    }
}

public struct FacePin: Sendable, Hashable, Codable {
    public let vertexIndex: Int
    public let type: LesionType

    public init(vertexIndex: Int, type: LesionType) {
        self.vertexIndex = vertexIndex
        self.type = type
    }
}

/// Places front-photo detections on the mesh: map each detection's position *relative to the face box* from the 2D
/// photo into the mesh's projected face box, then snap to the nearest projected vertex.
public enum FacePinMapper {
    public static func pins(for detections: [DetectionDraft], photoFace: ImageRect, mesh: FaceMeshDraft) -> [FacePin] {
        guard !mesh.projected.isEmpty, photoFace.width > 0, photoFace.height > 0 else { return [] }
        let xs = mesh.projected.map(\.x), ys = mesh.projected.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }

        return detections.filter { $0.captureAngle == .front }.compactMap { detection in
            // Relative position inside the photo's face box (top-left origin; Vision is bottom-left).
            var u = (detection.box.center.x - photoFace.x) / photoFace.width
            let v = 1 - (detection.box.center.y - photoFace.y) / photoFace.height
            guard (-0.1...1.1).contains(u), (-0.1...1.1).contains(v) else { return nil }
            if mesh.mirroredProjection { u = 1 - u }
            let target = SIMD2(minX + Float(u) * (maxX - minX), minY + Float(v) * (maxY - minY))
            let nearest = mesh.projected.indices.min {
                distanceSquared(mesh.projected[$0], target) < distanceSquared(mesh.projected[$1], target)
            }
            return nearest.map { FacePin(vertexIndex: $0, type: detection.type) }
        }
    }

    private static func distanceSquared(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let d = a - b
        return d.x * d.x + d.y * d.y
    }
}

/// Packing of mesh buffers into `Data` for SwiftData external storage.
public enum FaceMeshCodec {
    public static func encode<T: BitwiseCopyable>(_ values: [T]) -> Data {
        values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func decodeVertices(_ data: Data) -> [SIMD3<Float>] {
        data.withUnsafeBytes { Array($0.bindMemory(to: SIMD3<Float>.self)) }
    }

    public static func decodeUVs(_ data: Data) -> [SIMD2<Float>] {
        data.withUnsafeBytes { Array($0.bindMemory(to: SIMD2<Float>.self)) }
    }

    public static func decodeIndices(_ data: Data) -> [UInt16] {
        data.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }
    }
}

/// Persisted face mesh for a scan. Additive + optional everywhere (CloudKit schema is additive-only).
@Model
public final class FaceMeshRecord {
    public var id: UUID = UUID()
    @Attribute(.externalStorage) public var vertexData: Data?
    @Attribute(.externalStorage) public var indexData: Data?
    @Attribute(.externalStorage) public var uvData: Data?
    @Attribute(.externalStorage) public var textureData: Data?
    public var pinsJSON: Data?
    @Relationship(inverse: \ScanSession.faceMesh) public var session: ScanSession?

    public init(draft: FaceMeshDraft, pins: [FacePin]) {
        vertexData = FaceMeshCodec.encode(draft.vertices)
        indexData = FaceMeshCodec.encode(draft.indices)
        uvData = FaceMeshCodec.encode(draft.textureCoordinates)
        textureData = draft.texture
        pinsJSON = try? JSONEncoder().encode(pins)
    }

    public var vertices: [SIMD3<Float>] { vertexData.map(FaceMeshCodec.decodeVertices) ?? [] }
    public var indices: [UInt16] { indexData.map(FaceMeshCodec.decodeIndices) ?? [] }
    public var textureCoordinates: [SIMD2<Float>] { uvData.map(FaceMeshCodec.decodeUVs) ?? [] }
    public var pins: [FacePin] { pinsJSON.flatMap { try? JSONDecoder().decode([FacePin].self, from: $0) } ?? [] }
}
