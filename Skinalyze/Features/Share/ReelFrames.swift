import SwiftUI
import UIKit
import SkinalyzeKit

/// One scan as the reel shows it: its numbers and a single flattened picture (the eye-aligned sticker, or its
/// outline when the face is hidden).
struct ReelScan: @unchecked Sendable { // Values and an immutable image only.
    let date: Date
    let index: Int
    let band: BreakoutBand
    let picture: UIImage?
}

/// A single frame of the glow-up reel. A still like every share card: the plan says what is on screen, this draws it.
struct ReelFrameView: View {
    let scans: [ReelScan]
    let frame: ReelPlan.Frame
    /// 0…1 through the whole reel.
    let progress: Double

    private static let format = ShareCardFormat.story
    private static let barHeight: CGFloat = 4
    private static let trackOpacity = 0.15

    private var current: ReelScan { scans[frame.current] }
    private var next: ReelScan? { frame.next.map { scans[$0] } }
    /// The scan the labels describe: they switch halfway through a crossfade.
    private var labelled: ReelScan { frame.blend > 0.5 ? (next ?? current) : current }
    private var labelledNumber: Int { (frame.blend > 0.5 ? (frame.next ?? frame.current) : frame.current) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(labelled.date, format: .dateTime.day().month(.wide).year())
                    .font(CardMetrics.label).textCase(.uppercase)
                Spacer(minLength: Spacing.xs)
                Text(verbatim: "\(labelledNumber)/\(scans.count)").font(CardMetrics.label.monospacedDigit())
            }
            ZStack {
                picture(current)
                if let next { picture(next).opacity(frame.blend) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                Text(ReelPlan.displayedValue(from: current.index, to: next?.index, blend: frame.blend), format: .number)
                    .font(CardMetrics.numeral)
                Text("Breakout index · \(BandCopy.title(labelled.band))").font(CardMetrics.body)
            }
            progressBar
            if ShareCardPolicy.showsWatermark(isPro: false) { ShareWatermark() }
        }
        .padding(Spacing.lg)
        .frame(width: Self.format.pointSize.width, height: Self.format.pointSize.height)
        .foregroundStyle(Color.ds.ink)
        .background {
            ZStack {
                backdrop(current.band)
                if let next { backdrop(next.band).opacity(frame.blend) }
            }
        }
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private func picture(_ scan: ReelScan) -> some View {
        if let image = scan.picture {
            Image(uiImage: image).resizable().scaledToFit()
                .shadow(color: .black.opacity(CardMetrics.shadowOpacity), radius: CardMetrics.shadowRadius, y: CardMetrics.shadowDrop)
        } else {
            Pimpi(mood: .happy).frame(maxWidth: CardMetrics.pimpiMaxSide, maxHeight: CardMetrics.pimpiMaxSide)
        }
    }

    private func backdrop(_ band: BreakoutBand) -> some View {
        ZStack {
            Color.ds.canvas
            LinearGradient(colors: [Color.ds.band(band), Color.ds.band(band).opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var progressBar: some View {
        Capsule().fill(Color.ds.ink.opacity(Self.trackOpacity))
            .frame(height: Self.barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Color.ds.ink).frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
    }
}
