import ARKit
import CoreImage
import OSLog
import SkinalyzeKit

/// Captures one ARKit face mesh + camera frame for the optional 3D view.
///
/// Only on devices where `ARFaceTrackingConfiguration.isSupported` (Face ID iPhones). iPhone Duo has no Face ID
/// sensor, so it never offers 3D (owner decision). Runs only after the 2D capture session has stopped — the front
/// camera can't serve AVFoundation and ARKit at the same time.
@MainActor
final class FaceMeshCapturer: NSObject, ARSessionDelegate {
    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    enum CaptureError: Error {
        case unsupported
        case timedOut
        case noFrame
    }

    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Face3D")
    /// Frames to let tracking settle before sampling.
    private static let warmUpFrames = 20
    private static let timeout: Duration = .seconds(6)
    /// ARKit's portrait display transform mirrors the front camera; stored photos are unmirrored. Verify on device.
    static let projectionIsMirrored = true

    private let session = ARSession()
    private var frameCount = 0
    private var continuation: CheckedContinuation<FaceMeshDraft, Error>?

    func capture() async throws -> FaceMeshDraft {
        guard Self.isSupported else { throw CaptureError.unsupported }
        session.delegate = self
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        defer { session.pause() }

        return try await withThrowingTaskGroup(of: FaceMeshDraft.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { self.continuation = $0 }
            }
            group.addTask {
                try await Task.sleep(for: Self.timeout)
                throw CaptureError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CaptureError.noFrame }
            return result
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else { return }
        let draft = Self.makeDraft(frame: frame, face: face)
        Task { @MainActor in self.receive(draft) }
    }

    private func receive(_ draft: FaceMeshDraft?) {
        frameCount += 1
        guard frameCount >= Self.warmUpFrames, let draft, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: draft)
    }

    nonisolated private static func makeDraft(frame: ARFrame, face: ARFaceAnchor) -> FaceMeshDraft? {
        let geometry = face.geometry
        let imageSize = CGSize(width: CVPixelBufferGetWidth(frame.capturedImage), height: CVPixelBufferGetHeight(frame.capturedImage))
        let portrait = CGSize(width: imageSize.height, height: imageSize.width)
        // Normalized raw-image → normalized portrait-viewport; inverted to go back for texture lookup.
        let toRaw = frame.displayTransform(for: .portrait, viewportSize: portrait).inverted()

        var projected: [SIMD2<Float>] = []
        var uvs: [SIMD2<Float>] = []
        projected.reserveCapacity(geometry.vertices.count)
        uvs.reserveCapacity(geometry.vertices.count)
        for vertex in geometry.vertices {
            let world = face.transform * SIMD4(vertex, 1)
            let point = frame.camera.projectPoint(SIMD3(world.x, world.y, world.z), orientation: .portrait, viewportSize: portrait)
            let normalized = CGPoint(x: point.x / portrait.width, y: point.y / portrait.height)
            projected.append(SIMD2(Float(normalized.x), Float(normalized.y)))
            let raw = normalized.applying(toRaw)
            uvs.append(SIMD2(Float(raw.x), Float(1 - raw.y))) // texture V grows upward
        }
        guard let texture = jpeg(frame.capturedImage) else { return nil }
        return FaceMeshDraft(
            vertices: Array(geometry.vertices),
            indices: geometry.triangleIndices.map { UInt16(bitPattern: $0) },
            textureCoordinates: uvs,
            projected: projected,
            texture: texture,
            mirroredProjection: projectionIsMirrored
        )
    }

    nonisolated private static func jpeg(_ buffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer)
        return CIContext().jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.8])
    }
}
