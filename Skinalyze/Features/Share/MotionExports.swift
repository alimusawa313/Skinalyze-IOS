import SwiftUI
import UIKit
import SkinalyzeKit

/// Short looping videos made from share cards: the before/after slider (G5) and the shimmering skin card (G2).
/// Frames are SwiftUI views drawn by `ImageRenderer`; the encoder (`ReelWriter`) runs off the main actor.
@MainActor
enum MotionVideoExporter {
    private static let folderName = "ShareCards"

    static func export(name: String, frameCount: Int, progress: @MainActor (Double) -> Void,
                       frame: @MainActor (Int) -> AnyView) async throws -> URL {
        let format = ShareCardFormat.story
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).mp4")
        let writer = try ReelWriter(url: url, width: format.pixelWidth, height: format.pixelHeight)
        do {
            for index in 0..<frameCount {
                try Task.checkCancellation()
                let renderer = ImageRenderer(content: frame(index))
                renderer.scale = ShareCardFormat.renderScale
                renderer.isOpaque = true
                guard let image = renderer.cgImage else { throw ReelError.cannotRenderFrame }
                try await writer.append(image, frame: index)
                progress(Double(index + 1) / Double(frameCount))
                await Task.yield()
            }
            try await writer.finish(frameCount: frameCount)
            return url
        } catch {
            await writer.cancel()
            throw error
        }
    }
}

/// A holo sheen band, drawn across whatever it is masked to.
struct SheenBand: View {
    /// Band centre across the width (0…1, may run past either edge).
    let position: Double
    /// Over a white shape (the face-hidden outline) the sheen tints instead of brightening, so it stays visible.
    var overWhite = false

    private static let bandShare: CGFloat = 0.38
    private static let tilt: Double = 18

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(colors: [.clear, Color.ds.pimpiHighlight.opacity(0.45), .white.opacity(0.85),
                                    Color.ds.band(.calm).opacity(0.5), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width * Self.bandShare, height: proxy.size.height * 1.6)
                .rotationEffect(.degrees(Self.tilt))
                .position(x: width * position, y: proxy.size.height / 2)
        }
        .blendMode(overWhite ? .multiply : .screen)
        .allowsHitTesting(false)
    }
}

/// One frame of the before/after slider video.
struct WipeFrameView: View {
    let share: CompareShare
    /// Share of the width showing the earlier photo.
    let split: Double
    var showsWatermark = true

    private static let format = ShareCardFormat.story
    private static let lineWidth: CGFloat = 3
    private static let knob: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GeometryReader { proxy in
                let width = proxy.size.width, height = proxy.size.height
                ZStack(alignment: .leading) {
                    Image(uiImage: share.later).resizable().scaledToFill()
                        .frame(width: width, height: height).clipped()
                    Image(uiImage: share.earlier).resizable().scaledToFill()
                        .frame(width: width, height: height).clipped()
                        .mask(alignment: .leading) { Rectangle().frame(width: width * split) }
                    Capsule().fill(.white).frame(width: Self.lineWidth)
                        .overlay {
                            Image(systemName: "chevron.left.chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.ds.ink)
                                .frame(width: Self.knob, height: Self.knob)
                                .background(Circle().fill(.white))
                        }
                        .offset(x: width * split - Self.lineWidth / 2)
                }
                .overlay(alignment: .topLeading) { tag("Earlier", share.earlierDate) }
                .overlay(alignment: .topTrailing) { tag("Later", share.laterDate) }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            HStack(alignment: .firstTextBaseline) {
                Text("Breakout index").font(CardMetrics.body).opacity(CardMetrics.softText)
                Spacer(minLength: Spacing.xs)
                Text(verbatim: "\(share.earlierIndex) → \(share.laterIndex)").font(CardMetrics.numeralCompact)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            Label("Lined up by your eyes", systemImage: "eye").font(CardMetrics.note).opacity(CardMetrics.softText)
            if showsWatermark { ShareWatermark() }
        }
        .padding(Spacing.lg)
        .frame(width: Self.format.pointSize.width, height: Self.format.pointSize.height)
        .foregroundStyle(.white)
        .background(Color.ds.canvas)
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, .dark)
    }

    private func tag(_ title: LocalizedStringKey, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(CardMetrics.label).textCase(.uppercase)
            Text(date, format: .dateTime.day().month().year()).font(CardMetrics.note)
        }
        .padding(Spacing.xs)
        .background(.black.opacity(CardMetrics.scrim), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .padding(Spacing.sm)
    }
}

extension VideoShareSource {
    /// The skin card with a holo sheen sweeping across the sticker. Hide-my-face keeps working (outline only).
    @MainActor
    static func shimmer(_ session: ScanSession, streakDays: Int) -> VideoShareSource {
        let card = ShareCardSource.skin(session, streakDays: streakDays)
        return VideoShareSource(title: "Shimmer video", offersHideFace: true) { hidesFace, showsWatermark, progress in
            guard let content = await card.content(hidesFace) else { throw ReelError.cannotStart }
            let plan = ShimmerPlan()
            return try await MotionVideoExporter.export(name: hidesFace ? "skinalyze-shimmer-private" : "skinalyze-shimmer",
                                                        frameCount: plan.frameCount, progress: progress) { index in
                AnyView(ShareCardView(content: content, format: .story, showsWatermark: showsWatermark,
                                      sheen: plan.sheen(at: index)))
            }
        }
    }

    /// Earlier → later with the slider sweeping across the eye-aligned photos.
    static func wipe(_ share: CompareShare) -> VideoShareSource {
        VideoShareSource(title: "Slider video", offersHideFace: false) { _, showsWatermark, progress in
            let plan = WipePlan()
            return try await MotionVideoExporter.export(name: "skinalyze-before-after", frameCount: plan.frameCount,
                                                        progress: progress) { index in
                AnyView(WipeFrameView(share: share, split: plan.split(at: index), showsWatermark: showsWatermark))
            }
        }
    }
}
