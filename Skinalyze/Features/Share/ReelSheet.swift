import AVKit
import SwiftData
import SwiftUI
import SkinalyzeKit

/// A video that can be made and shared: the glow-up reel or the 3D turntable.
struct VideoShareSource: Identifiable {
    typealias Progress = @MainActor (Double) -> Void

    let id = UUID()
    let title: LocalizedStringKey
    let offersHideFace: Bool
    let make: @MainActor (_ hidesFace: Bool, _ showsWatermark: Bool, _ progress: @escaping Progress) async throws -> URL
}

extension VideoShareSource {
    /// Every scan oldest → newest as eye-aligned stickers.
    @MainActor
    static func reel(scans: [ScanSession], template: ReelTemplate = .classic) -> VideoShareSource {
        let inputs = ReelExporter.inputs(from: scans)
        return VideoShareSource(title: "Glow-up reel", offersHideFace: true) { hidesFace, showsWatermark, progress in
            let prepared = try await ReelExporter.prepare(inputs, hidesFace: hidesFace)
            return try await ReelExporter.export(prepared, name: hidesFace ? "skinalyze-reel-private" : "skinalyze-reel",
                                                 showsWatermark: showsWatermark, template: template, progress: progress)
        }
    }

    /// The scanned head turning as far as each side was captured.
    static func turntable(_ input: TurntableInput) -> VideoShareSource {
        VideoShareSource(title: "3D turntable", offersHideFace: false) { _, showsWatermark, progress in
            try await TurntableExporter.export(input, name: "skinalyze-3d", showsWatermark: showsWatermark, progress: progress)
        }
    }
}

/// Makes the video with visible progress, plays it back, and hands it to the system share sheet. Closing the sheet
/// cancels the work. "Hide my face" is asked every time and remakes the video.
struct VideoShareSheet: View {
    let source: VideoShareSource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(QuestModel.self) private var quests: QuestModel?
    @State private var hidesFace = false
    @State private var phase = Phase.working(0)
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    private enum Phase: Equatable {
        case working(Double)
        case done(URL)
        case failed
    }

    private enum Metrics {
        static let videoRatio: CGFloat = 9 / 16
        static let pimpiSide: CGFloat = 120
        static let progressWidth: CGFloat = 280
        /// The white edge round the video.
        static let videoBorder: CGFloat = 6
    }

    var body: some View {
        NavigationStack {
            Group {
                // Landscape (and iPhone Duo closed, landscape): the video beside the controls instead of above them.
                if verticalSizeClass == .compact {
                    HStack(spacing: Spacing.lg) {
                        stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                        ScrollView { controls.padding(.vertical, Spacing.md) }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(maxWidth: ShareSheetMetrics.controlsWidth)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .dsHill(crest: ShareSheetMetrics.wideCrest, rise: ShareSheetMetrics.hillRise)
                } else {
                    VStack(spacing: 0) {
                        stage
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls.shareSheetHill()
                    }
                    .background(Color.ds.canvas.ignoresSafeArea())
                }
            }
            .navigationTitle(source.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .task(id: hidesFace) { await make() }
        .onDisappear { player?.pause() }
        .sensoryFeedback(Haptic.toggle, trigger: hidesFace)
        .sensoryFeedback(Haptic.success, trigger: phase) { _, phase in
            if case .done = phase { true } else { false }
        }
        .animation(MotionToken.snappy.resolved(reduceMotion: reduceMotion).animation, value: phase)
    }

    @ViewBuilder private var stage: some View {
        switch phase {
        case let .working(progress):
            VStack(spacing: Spacing.md) {
                Pimpi(mood: .curious).frame(width: Metrics.pimpiSide, height: Metrics.pimpiSide)
                ProgressView(value: progress) {
                    Text("Making your video…")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                }
                .tint(Color.ds.ink)
                .frame(maxWidth: Metrics.progressWidth)
            }
        case .done:
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(Metrics.videoRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .accessibilityLabel(hidesFace ? Text("Your video with your face hidden") : Text("Your video"))
                    .accessibilityIdentifier("videoSharePlayer")
                    .padding(Metrics.videoBorder)
                    .dsSurface(radius: Radius.large)
            }
        case .failed:
            ContentUnavailableView("Couldn't make the video", systemImage: "film",
                                   description: Text("Close this and try again."))
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.md) {
            if source.offersHideFace {
                HideFaceRow(isOn: $hidesFace, identifier: "videoShareHideFace")
            }
            Text("Skinalyze uploads nothing. The video goes only where you send it.")
                .font(.ds.footnote.weight(.semibold))
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            shareButton
        }
    }

    @ViewBuilder private var shareButton: some View {
        let label = Label("Share", systemImage: "square.and.arrow.up")
        if case let .done(url) = phase {
            ShareLink(item: url) { label }
                .simultaneousGesture(TapGesture().onEnded { quests?.did(.share, isPro: access?.policy.hasFullAccess ?? false) })
                .buttonStyle(.chunky)
                .accessibilityIdentifier("videoShareButton")
        } else {
            Button {} label: { label }
                .buttonStyle(.chunky)
                .disabled(true)
        }
    }

    private func make() async {
        // Nothing stale may be shared or shown: the old video goes before the new one is made.
        player?.pause()
        player = nil
        looper = nil
        phase = .working(0)
        do {
            let watermark = ShareCardPolicy.showsWatermark(isPro: access?.policy.hasFullAccess ?? false)
            let url = try await source.make(hidesFace, watermark) { phase = .working($0) }
            try Task.checkCancellation()
            let queue = AVQueuePlayer()
            queue.isMuted = true
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
            player = queue
            phase = .done(url)
            if !reduceMotion { queue.play() }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}

#if DEBUG
/// `-reelDump <folder>`: writes the reel (and the face-hidden one) from the demo data, to be checked frame by frame.
@MainActor
enum ReelDump {
    static func run(into folder: String, scans: [ScanSession]) async {
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let inputs = ReelExporter.inputs(from: scans)
        for (name, hidesFace) in [("reel", false), ("reel-hidden", true)] {
            let started = Date()
            guard let prepared = try? await ReelExporter.prepare(inputs, hidesFace: hidesFace),
                  let url = try? await ReelExporter.export(prepared, name: "dump-\(name)",
                                                          template: ReelTemplate(rawValue: UserDefaults.standard.string(forKey: "reelTemplate") ?? "") ?? .classic,
                                                          progress: { _ in }) else { continue }
            let target = directory.appendingPathComponent("\(name).mp4")
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: url, to: target)
            let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
            try? "\(inputs.count) scans, made in \(seconds) s\n".write(to: directory.appendingPathComponent("\(name).txt"),
                                                                     atomically: true, encoding: .utf8)
        }
    }
}
#endif
