import Metal
import RealityKit
import SwiftUI
import UIKit
import SkinalyzeKit

/// Draws the scanned head offscreen with RealityKit (the same entity the 3D viewer shows, without the spot pins)
/// and hands back one picture per turn angle.
@MainActor
final class HeadRenderer {
    private let renderer: RealityRenderer
    private let head: Entity
    private let texture: MTLTexture
    private let width: Int
    private let height: Int

    private static let fieldOfViewDegrees: Float = 30
    /// The head is fitted to `Face3DView.fittedSize`; this leaves a margin around it at any turn.
    private static let cameraDistance: Float = 5.4

    init(head: Entity, width: Int, height: Int, background: CGColor) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw ReelError.cannotStart }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw ReelError.cannotStart }
        self.texture = texture
        self.width = width
        self.height = height
        self.head = head
        renderer = try RealityRenderer()
        renderer.cameraSettings.colorBackground = .color(background)
        renderer.cameraSettings.isToneMappingEnabled = false
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = Self.fieldOfViewDegrees
        camera.position = [0, 0, Self.cameraDistance]
        renderer.entities.append(head)
        renderer.entities.append(camera)
        renderer.activeCamera = camera
    }

    func image(yaw: Float) async throws -> CGImage {
        head.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: output, onComplete: { _ in continuation.resume() })
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return try readBack()
    }

    private func readBack() throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil,
                                  shouldInterpolate: true, intent: .defaultIntent) else { throw ReelError.cannotRenderFrame }
        return image
    }
}

/// One frame of the turntable video: the turning head on the dark canvas, the date and the mark.
struct TurntableFrameView: View {
    let head: CGImage
    let date: Date
    var showsWatermark = true

    private static let format = ShareCardFormat.story
    static let backgroundToken = Palette.canvas

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(date, format: .dateTime.day().month(.wide).year())
                .font(CardMetrics.label).textCase(.uppercase).opacity(CardMetrics.softText)
            Image(decorative: head, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsWatermark { ShareWatermark() }
        }
        .padding(Spacing.lg)
        .frame(width: Self.format.pointSize.width, height: Self.format.pointSize.height)
        .foregroundStyle(.white)
        .background(Color.ds.canvas)
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, .dark)
    }
}

/// The saved 3D scan, read once on the main actor so no model object is touched during the export.
struct TurntableInput {
    let vertices: [SIMD3<Float>]
    let indices: [UInt16]
    let textureCoordinates: [SIMD2<Float>]
    let textureData: Data?
    let date: Date

    @MainActor
    init?(session: ScanSession) {
        guard let mesh = session.faceMesh, !mesh.vertices.isEmpty else { return nil }
        vertices = mesh.vertices
        indices = mesh.indices
        textureCoordinates = mesh.textureCoordinates
        textureData = mesh.textureData
        date = session.createdAt
    }
}

@MainActor
enum TurntableExporter {
    /// The head is drawn at the video's full width, in the 4:5 shape of the post format.
    private static let headWidth = ShareCardFormat.portrait.pixelWidth
    private static let headHeight = ShareCardFormat.portrait.pixelHeight
    private static let folderName = "ShareCards"

    static func export(_ input: TurntableInput, name: String, showsWatermark: Bool = true,
                       progress: @MainActor (Double) -> Void) async throws -> URL {
        guard let head = Face3DView.headEntity(vertices: input.vertices, textureCoordinates: input.textureCoordinates,
                                               indices: input.indices, textureData: input.textureData, pins: []) else {
            throw ReelError.cannotStart
        }
        let bounds = Face3DView.turnRange(vertices: input.vertices, indices: input.indices)
        let plan = TurntablePlan(range: Double(bounds.lowerBound)...Double(bounds.upperBound))
        let background = UIColor(Color.ds.canvas).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).cgColor
        let renderer = try HeadRenderer(head: head, width: headWidth, height: headHeight, background: background)

        let format = ShareCardFormat.story
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).mp4")
        let writer = try ReelWriter(url: url, width: format.pixelWidth, height: format.pixelHeight)
        do {
            for index in 0..<plan.frameCount {
                try Task.checkCancellation()
                let headImage = try await renderer.image(yaw: Float(plan.yaw(at: index)))
                let frame = ImageRenderer(content: TurntableFrameView(head: headImage, date: input.date, showsWatermark: showsWatermark))
                frame.scale = ShareCardFormat.renderScale
                frame.isOpaque = true
                guard let image = frame.cgImage else { throw ReelError.cannotRenderFrame }
                try await writer.append(image, frame: index)
                progress(Double(index + 1) / Double(plan.frameCount))
                await Task.yield()
            }
            try await writer.finish(frameCount: plan.frameCount)
            return url
        } catch {
            await writer.cancel()
            throw error
        }
    }
}
