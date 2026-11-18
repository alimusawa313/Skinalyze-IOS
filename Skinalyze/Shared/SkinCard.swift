import SwiftUI
import UIKit
import SkinalyzeKit

/// The signature object: your face as a die-cut holo sticker stuck on your mood colour, glowing where spots were found.
struct SkinCard: View {
    let session: ScanSession
    var size: Size = .hero

    enum Size { case hero, deck, compact }

    @State private var sticker: StickerArt?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 72

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color.ds.band(session.band), Color.ds.band(session.band).opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let sticker {
                StickerImage(art: sticker, tilts: size != .compact, shadowRadius: size == .compact ? 3 : 6)
                    .padding(size == .compact ? Spacing.xs : Spacing.md)
                    .padding(.top, size == .compact ? 0 : Spacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .overlay { zoneGlows }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if size != .compact {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Group {
                        if size == .deck {
                            Text(session.createdAt, format: .dateTime.weekday(.wide).day().month(.wide))
                        } else {
                            Text("Latest scan")
                        }
                    }
                    .font(.ds.label).textCase(.uppercase)
                    Text(session.breakoutIndex, format: .number)
                        .font(.system(size: heroNumberSize, weight: .heavy, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(value: Double(session.breakoutIndex)))
                    Text("Breakout index · \(BandCopy.title(session.band))").font(.ds.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
                .padding(Spacing.lg)
            } else {
                Text(session.createdAt, format: .dateTime.day().month(.abbreviated))
                    .font(.ds.label)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .padding(Spacing.sm)
            }
        }
        .aspectRatio(size == .compact ? 0.72 : 0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: size == .compact ? Radius.medium : Radius.large, style: .continuous))
        .shadow(color: Color.ds.band(session.band).opacity(0.45), radius: size == .compact ? 10 : 24, y: size == .compact ? 6 : 14)
        .task(id: session.id) {
            let art = await PortraitCutout.shared.art(for: session.id, photo: session.sortedCaptures.first?.imageData)
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { sticker = art }
            glowing = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Scan from \(session.createdAt.formatted(date: .abbreviated, time: .omitted)), breakout index \(session.breakoutIndex), \(BandCopy.title(session.band))"))
    }

    /// Soft pulsing glows at canonical zone positions (the card is a portrait, not a measurement).
    private var zoneGlows: some View {
        GeometryReader { proxy in
            ForEach(FaceZone.allCases.filter { session.zoneIndex($0) > 0 }, id: \.self) { zone in
                let p = position(zone)
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.95), Color.ds.signal.opacity(0.6), .clear],
                                         center: .center, startRadius: 0, endRadius: 22))
                    .frame(width: 44, height: 44)
                    .scaleEffect(glowing && !reduceMotion ? 1.12 : 0.9)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowing)
                    .position(x: p.x * proxy.size.width, y: p.y * proxy.size.height)
                    .blendMode(.plusLighter)
            }
        }
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
