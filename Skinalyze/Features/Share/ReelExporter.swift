import AVFoundation
import SwiftUI
import UIKit
import SkinalyzeKit

enum ReelError: Error {
    case notEnoughScans
    case cannotStart
    case cannotRenderFrame
    case writeFailed
}

/// Writes rendered frames into an H.264 MP4. Encoding happens off the main actor.
actor ReelWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let width: Int
    private let height: Int
    private static let retryDelay = Duration.milliseconds(4)

    init(url: URL, width: Int, height: Int) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        self.width = width
        self.height = height
        guard writer.canAdd(input) else { throw ReelError.cannotStart }
        writer.add(input)
        guard writer.startWriting() else { throw ReelError.cannotStart }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage, frame: Int) async throws {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(for: Self.retryDelay)
        }
        guard let pool = adaptor.pixelBufferPool else { throw ReelError.writeFailed }
        var created: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        guard let buffer = created else { throw ReelError.writeFailed }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw ReelError.writeFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(ReelPlan.framesPerSecond))
        guard adaptor.append(buffer, withPresentationTime: time) else { throw ReelError.writeFailed }
    }

    func finish(frameCount: Int) async throws {
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(ReelPlan.framesPerSecond)))
        await writer.finishWriting()
        guard writer.status == .completed else { throw ReelError.writeFailed }
    }

    func cancel() {
        writer.cancelWriting()
    }
}

/// Builds the glow-up reel: eye-aligned stickers oldest → newest, drawn frame by frame, written to a file for the
/// system share sheet. Nothing is uploaded by the app.
@MainActor
enum ReelExporter {
    /// What is read from a scan up front, so no model object is touched while the reel is being made.
    struct Input: @unchecked Sendable {
        let id: UUID
        let photo: UIImage?
        let date: Date
        let index: Int
        let band: BreakoutBand
    }

    private static let pictureMaxSide: CGFloat = 900
    private static let folderName = "ShareCards"

    /// Oldest first, thinned to an even sample when there are many.
    static func inputs(from scans: [ScanSession]) -> [Input] {
        let ordered = scans.sorted { $0.createdAt < $1.createdAt }
        return ReelPlan.selection(count: ordered.count).map { position in
            let scan = ordered[position]
            return Input(id: scan.id, photo: scan.uiImage(at: 0), date: scan.createdAt, index: scan.breakoutIndex, band: scan.band)
        }
    }

    /// Lines every face up by the eyes, cuts it out as a sticker on the shared canvas (so stickers stay registered
    /// from frame to frame) and flattens it to one small picture. With `hidesFace` only the outline is kept.
    static func prepare(_ inputs: [Input], hidesFace: Bool) async throws -> [ReelScan] {
        var result: [ReelScan] = []
        for input in inputs {
            try Task.checkCancellation()
            var picture: UIImage?
            if let photo = input.photo {
                let aligned = await FaceAligner.shared.aligned(photo, key: "reel-\(input.id)")?.image ?? photo
                let art = await PortraitCutout.shared.liftArt(from: aligned)?.full
                picture = flatten(SharePortrait.make(from: art, hidesFace: hidesFace))
            }
            result.append(ReelScan(date: input.date, index: input.index, band: input.band, picture: picture))
        }
        return result
    }

    static func export(_ scans: [ReelScan], name: String, progress: @MainActor (Double) -> Void) async throws -> URL {
        guard let plan = ReelPlan(scanCount: scans.count) else { throw ReelError.notEnoughScans }
        let format = ShareCardFormat.story
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).mp4")
        let writer = try ReelWriter(url: url, width: format.pixelWidth, height: format.pixelHeight)
        do {
            for index in 0..<plan.frameCount {
                try Task.checkCancellation()
                let view = ReelFrameView(scans: scans, frame: plan.frame(at: index),
                                         progress: Double(index + 1) / Double(plan.frameCount))
                let renderer = ImageRenderer(content: view)
                renderer.scale = ShareCardFormat.renderScale
                renderer.isOpaque = true
                guard let image = renderer.cgImage else { throw ReelError.cannotRenderFrame }
                try await writer.append(image, frame: index)
                progress(Double(index + 1) / Double(plan.frameCount))
                await Task.yield() // keep the screen responsive between frames
            }
            try await writer.finish(frameCount: plan.frameCount)
            return url
        } catch {
            await writer.cancel()
            throw error
        }
    }

    private static func flatten(_ portrait: SharePortrait) -> UIImage? {
        let layers: [UIImage]
        switch portrait {
        case let .sticker(art): layers = [art.backing, art.subject]
        case let .silhouette(shape): layers = [shape]
        case .none: return nil
        }
        guard let first = layers.first, first.size.width > 0, first.size.height > 0 else { return nil }
        let scale = min(1, pictureMaxSide / max(first.size.width, first.size.height))
        let size = CGSize(width: (first.size.width * scale).rounded(), height: (first.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            layers.forEach { $0.draw(in: CGRect(origin: .zero, size: size)) }
        }
    }
}
