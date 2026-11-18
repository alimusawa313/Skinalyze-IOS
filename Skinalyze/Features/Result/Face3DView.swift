import RealityKit
import SwiftUI
import UIKit
import SkinalyzeKit

/// Your real TrueDepth face scan, textured with your front photo, with tappable lesion pins (Face ID iPhones only).
/// Drag to turn (slow, damped, limited so the open back of a single-view scan never shows), pinch to zoom, double-tap
/// to reset; tap a pin for what it is. The model auto-fits its frame. VoiceOver users get the zone list instead.
struct Face3DView: View {
    let mesh: FaceMeshRecord

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var yaw: Float = Face3DView.debugStartYaw
    @State private var pitch: Float = 0
    @State private var scale: Float = 1
    @State private var dragStart: (yaw: Float, pitch: Float)?
    @State private var selectedPin: Int?

    /// A front-only scan holds together up to about this turn (checked on real scans); further tears the cheeks.
    private static let maxYaw: Float = 32 * .pi / 180
    private static let maxPitch: Float = 15 * .pi / 180
    /// Radians per point of drag — slow enough to inspect.
    private static let dragSensitivity: Float = 0.0045
    /// The drawn mesh.s largest extent is scaled to this (about half the screen width in the default RealityView camera).
    private static let fittedSize: Float = 1.9
    private static let pinPrefix = "pin-"
    /// DEBUG `-debugYaw <degrees>`: open already turned, for renderer checks in the Simulator.
    private static var debugStartYaw: Float {
        #if DEBUG
        UserDefaults.standard.float(forKey: "debugYaw") * .pi / 180
        #else
        0
        #endif
    }

    var body: some View {
        RealityView { content in
            guard let face = makeFaceEntity() else { return }
            face.name = "face"
            content.add(face)
        } update: { content in
            guard let face = content.entities.first(where: { $0.name == "face" }) else { return }
            face.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
            face.transform.scale = SIMD3(repeating: scale)
            for (index, _) in mesh.pins.enumerated() {
                face.findEntity(named: "\(Self.pinPrefix)\(index)")?.transform.scale =
                    SIMD3(repeating: index == selectedPin ? 1.9 : 1)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let start = dragStart ?? (yaw, pitch)
                    dragStart = start
                    let targetYaw = start.yaw + Float(value.translation.width) * Self.dragSensitivity
                    let targetPitch = start.pitch + Float(value.translation.height) * Self.dragSensitivity
                    yaw = Self.softClamp(targetYaw, limit: Self.maxYaw)
                    pitch = Self.softClamp(targetPitch, limit: Self.maxPitch)
                }
                .onEnded { _ in dragStart = nil }
        )
        .simultaneousGesture(MagnifyGesture().onChanged { scale = min(max(Float($0.magnification), 0.7), 2.2) })
        .simultaneousGesture(
            SpatialTapGesture().targetedToAnyEntity().onEnded { value in
                guard let name = Self.pinName(from: value.entity),
                      let index = Int(name.dropFirst(Self.pinPrefix.count)) else { return }
                withAnimation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation) {
                    selectedPin = selectedPin == index ? nil : index
                }
            }
        )
        .onTapGesture(count: 2) {
            withDSAnimation(.gentle, reduceMotion: reduceMotion) {
                yaw = 0
                pitch = 0
                scale = 1
                selectedPin = nil
            }
        }
        .overlay(alignment: .bottom) { pinCard }
        .sensoryFeedback(.selection, trigger: selectedPin)
        .frame(minHeight: 340)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var pinCard: some View {
        if let selectedPin, mesh.pins.indices.contains(selectedPin) {
            HStack(alignment: .top) {
                SpotDetail(type: mesh.pins[selectedPin].type, zone: nil)
                Button { self.selectedPin = nil } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close")
                .padding(Spacing.xs)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .padding(Spacing.sm)
            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
    }

    /// Past the limit the turn resists (rubber band) instead of stopping dead.
    private static func softClamp(_ value: Float, limit: Float) -> Float {
        guard abs(value) > limit else { return value }
        let over = abs(value) - limit
        return (limit + over * 0.15) * (value < 0 ? -1 : 1)
    }

    private static func pinName(from entity: Entity) -> String? {
        var current: Entity? = entity
        while let node = current {
            if node.name.hasPrefix(pinPrefix) { return node.name }
            current = node.parent
        }
        return nil
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

        for (index, pin) in mesh.pins.enumerated() where vertices.indices.contains(pin.vertexIndex) {
            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.003),
                materials: [UnlitMaterial(color: pin.type.isMark ? UIColor(Color.ds.caution) : UIColor(Color.ds.signal))]
            )
            marker.name = "\(Self.pinPrefix)\(index)"
            marker.position = vertices[pin.vertexIndex] + SIMD3(0, 0, 0.002)
            // A generous invisible hit area so pins are easy to tap.
            marker.components.set(InputTargetComponent())
            marker.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.009)]))
            face.addChild(marker)
        }

        // Auto-fit: centre the scan on the bounds of what is actually drawn (vertices used by triangles) and scale
        // its largest extent to `fittedSize`.
        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude), upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for index in indices where vertices.indices.contains(Int(index)) {
            lower = simd_min(lower, vertices[Int(index)])
            upper = simd_max(upper, vertices[Int(index)])
        }
        let extent = max(upper.x - lower.x, upper.y - lower.y, 0.01)
        let fit = Entity()
        fit.scale = SIMD3(repeating: Self.fittedSize / extent)
        face.position = -(lower + upper) / 2
        fit.addChild(face)

        let pivot = Entity()
        pivot.addChild(fit)
        return pivot
    }
}
