import RealityKit
import SwiftUI
import UIKit
import SkinalyzeKit

/// Your real TrueDepth face scan, textured with your front photo, with lesion pins (Face ID iPhones only). Drag to turn (limited range), pinch to zoom,
/// double-tap to reset. Reduce Motion: no spring settle. VoiceOver users get the zone list instead (hidden here).
struct Face3DView: View {
    let mesh: FaceMeshRecord

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var yaw: Float = 0
    @State private var pitch: Float = 0
    @State private var scale: Float = 1
    @State private var dragStart: (yaw: Float, pitch: Float)?

    /// A single-view depth scan is a relief of the face: turning further would show its open back.
    private static let maxYaw: Float = 55 * .pi / 180
    private static let maxPitch: Float = 25 * .pi / 180
    /// TrueDepth face scans are ~20 cm across (metres); scale up to fill the default RealityView camera.
    private static let baseScale: Float = 9

    var body: some View {
        RealityView { content in
            guard let face = makeFaceEntity() else { return }
            face.name = "face"
            content.add(face)
        } update: { content in
            guard let face = content.entities.first(where: { $0.name == "face" }) else { return }
            face.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
            face.transform.scale = SIMD3(repeating: scale * Self.baseScale)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let start = dragStart ?? (yaw, pitch)
                    dragStart = start
                    yaw = min(max(start.yaw + Float(value.translation.width) * 0.01, -Self.maxYaw), Self.maxYaw)
                    pitch = min(max(start.pitch + Float(value.translation.height) * 0.01, -Self.maxPitch), Self.maxPitch)
                }
                .onEnded { _ in dragStart = nil }
        )
        .simultaneousGesture(MagnifyGesture().onChanged { scale = min(max(Float($0.magnification), 0.7), 2) })
        .onTapGesture(count: 2) {
            withDSAnimation(.gentle, reduceMotion: reduceMotion) {
                yaw = 0
                pitch = 0
                scale = 1
            }
        }
        .frame(minHeight: 320)
        .accessibilityHidden(true)
    }

    private func makeFaceEntity() -> Entity? {
        let vertices = mesh.vertices, uvs = mesh.textureCoordinates, indices = mesh.indices
        guard !vertices.isEmpty, uvs.count == vertices.count, !indices.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "face")
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices.map(UInt32.init))
        guard let resource = try? MeshResource.generate(from: [descriptor]) else { return nil }

        var material = UnlitMaterial()
        if let data = mesh.textureData, let image = UIImage(data: data)?.cgImage,
           let texture = try? TextureResource(image: image, options: .init(semantic: .color)) {
            material.color = .init(texture: .init(texture))
        }
        let face = ModelEntity(mesh: resource, materials: [material])

        for pin in mesh.pins where vertices.indices.contains(pin.vertexIndex) {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.0025),
                materials: [UnlitMaterial(color: pin.type.isMark ? UIColor(Color.ds.caution) : UIColor(Color.ds.signal))]
            )
            marker.position = vertices[pin.vertexIndex] + SIMD3(0, 0, 0.002)
            face.addChild(marker)
        }
        let pivot = Entity()
        pivot.addChild(face)
        return pivot
    }
}
