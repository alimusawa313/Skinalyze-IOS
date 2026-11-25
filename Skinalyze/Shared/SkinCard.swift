import SwiftUI
import UIKit
import SkinalyzeKit

/// The signature object: a white card with a hard bottom edge holding a flat band-coloured panel with your face
/// sticker on it, the big breakout index, the band and the date. Spots found show as small dots on the sticker.
struct SkinCard: View {
    let session: ScanSession
    var size: Size = .hero

    enum Size { case hero, deck, compact }

    /// How far the band panel sits inside the white card (overlays on the panel line up with this).
    static let panelInset: CGFloat = Spacing.sm

    private enum Metrics {
        static let aspect: CGFloat = 0.82
        static let aspectCompact: CGFloat = 0.72
        static let heroNumber: CGFloat = 72
        static let spotDot: CGFloat = 14
        static let spotRing: CGFloat = 3
        static let spotPulse: CGFloat = 1.15
        static let spotPulseSeconds: Double = 1.6
        static let stickerTilt: Double = 4
        static let numberMinScale: CGFloat = 0.5
        static let captionMinScale: CGFloat = 0.8
    }

    @State private var sticker: StickerArt?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = Metrics.heroNumber

    private var isCompact: Bool { size == .compact }
    private var radius: CGFloat { isCompact ? Radius.medium : Radius.large }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? Spacing.xxs : Spacing.sm) {
            panel
            if isCompact {
                Text(session.createdAt, format: .dateTime.day().month(.abbreviated))
                    .font(.ds.label)
                    .foregroundStyle(Color.ds.ink)
                    .padding(.horizontal, Spacing.xxs)
            } else {
                facts.padding(.horizontal, Spacing.xs)
            }
        }
        .padding(Self.panelInset)
        .padding(.bottom, isCompact ? 0 : Spacing.xxs)
        .aspectRatio(isCompact ? Metrics.aspectCompact : Metrics.aspect, contentMode: .fit)
        .dsSurface(radius: radius)
        .task(id: session.id) {
            let art = await PortraitCutout.shared.art(for: session.id, photo: session.sortedCaptures.first?.imageData)
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { sticker = art }
            pulsing = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Scan from \(session.createdAt.formatted(date: .abbreviated, time: .omitted)), breakout index \(session.breakoutIndex), \(BandCopy.title(session.band))"))
    }

    /// The flat band-colour panel with the face sticker standing on it.
    private var panel: some View {
        RoundedRectangle(cornerRadius: radius - Self.panelInset, style: .continuous)
            .fill(Color.ds.band(session.band))
            .overlay {
                if let sticker {
                    StickerImage(art: sticker, tilts: !isCompact, shadowRadius: 0)
                        .overlay { spots }
                        .rotationEffect(.degrees(isCompact ? 0 : Metrics.stickerTilt))
                        .padding(isCompact ? Spacing.xs : Spacing.md)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius - Self.panelInset, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Big index on the left; date and "Breakout index · band" on the right. Stacks when the text is large.
    private var facts: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                number
                Spacer(minLength: 0)
                caption(alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 0) {
                number
                caption(alignment: .leading)
            }
        }
        .foregroundStyle(Color.ds.ink)
    }

    private var number: some View {
        Text(session.breakoutIndex, format: .number)
            .font(.system(size: heroNumberSize, weight: .heavy, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(Metrics.numberMinScale)
            .contentTransition(.numericText(value: Double(session.breakoutIndex)))
    }

    private func caption(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.xxs) {
            Group {
                if size == .deck {
                    Text(session.createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                } else {
                    Text("Latest scan")
                }
            }
            .font(.system(.headline, design: .rounded).weight(.heavy))
            Text("Breakout index · \(BandCopy.title(session.band))")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.inkSecondary)
        }
        .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        .lineLimit(2)
        .minimumScaleFactor(Metrics.captionMinScale)
    }

    /// Small flat dots at canonical zone positions (the card is a portrait, not a measurement).
    private var spots: some View {
        GeometryReader { proxy in
            ForEach(FaceZone.allCases.filter { session.zoneIndex($0) > 0 }, id: \.self) { zone in
                let p = position(zone)
                Circle()
                    .fill(Color.ds.pimpiBodyDeep)
                    .stroke(Color.ds.pimpiCheek, lineWidth: Metrics.spotRing)
                    .frame(width: Metrics.spotDot, height: Metrics.spotDot)
                    .scaleEffect(pulsing && !reduceMotion ? Metrics.spotPulse : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: Metrics.spotPulseSeconds).repeatForever(autoreverses: true),
                               value: pulsing)
                    .position(x: p.x * proxy.size.width, y: p.y * proxy.size.height)
            }
        }
        .opacity(isCompact ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func position(_ zone: FaceZone) -> CGPoint {
        switch zone {
        case .forehead: CGPoint(x: 0.5, y: 0.2)
        case .nose: CGPoint(x: 0.5, y: 0.4)
        case .rightCheek: CGPoint(x: 0.34, y: 0.45)
        case .leftCheek: CGPoint(x: 0.66, y: 0.45)
        case .chin: CGPoint(x: 0.5, y: 0.66)
        case .rightJaw: CGPoint(x: 0.36, y: 0.6)
        case .leftJaw: CGPoint(x: 0.64, y: 0.6)
        }
    }
}
