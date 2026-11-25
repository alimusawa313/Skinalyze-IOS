import SwiftData
import SwiftUI
import SkinalyzeKit

/// G9 creator kit: reel looks for people who post their progress, a few tips, and how creator codes work. Creator
/// codes are App Store offer codes the Skinalyze team sets up per creator (no server of our own), so redemptions show
/// in App Store Connect. The looks sit on the sky as pressable rows with a small swatch; tips and codes on the hill.
struct CreatorKitView: View {
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse)
    private var scans: [ScanSession]
    @State private var making: VideoShareSource?
    /// The look last made, ringed in ink so you can see what you picked.
    @State private var picked: ReelTemplate?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let swatch = CGSize(width: 56, height: 90)
        static let face: CGFloat = 26
        static let faceOpacity = 0.25
    }

    var body: some View {
        PlacePage {
            PlaceSection("Reel looks") {
                ForEach(ReelTemplate.allCases) { template in
                    Button {
                        withDSAnimation(.bouncy, reduceMotion: reduceMotion) { picked = template }
                        making = .reel(scans: scans, template: template)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            swatch(template)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(template.title).font(.system(.headline, design: .rounded).weight(.heavy))
                                Text(detail(template))
                                    .font(.ds.footnote.weight(.semibold))
                                    .foregroundStyle(Color.ds.inkSecondary)
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, Spacing.xs)
                        .padding(.trailing, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(ChunkyRowStyle(look: picked == template ? .outlined : .plain, radius: Radius.large))
                    .popOnChange(picked == template)
                    .accessibilityAddTraits(picked == template ? .isSelected : [])
                    .disabled(scans.count < 2)
                    .accessibilityIdentifier("reelTemplate.\(template.rawValue)")
                }
                Text(scans.count < 2 ? "Reels need at least two scans." : "Every look can hide your face, like the normal reel.")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.ink)
                    .padding(.horizontal, Spacing.xxs)
            }
        } ground: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PlaceSection("Tips") {
                    tip("Scan in the same spot and light each time — the reel lines faces up by the eyes.")
                    tip("Hide my face shares the outline and numbers only.")
                    tip("Talk about your routine and habits — skin changes for many reasons.")
                }
                PlaceSection("Creator codes") {
                    tip("Creator codes are App Store offer codes made for you by the Skinalyze team. Your followers type the code in the App Store or in Skinalyze, and every redemption is counted by Apple.")
                }
            }
        }
        .navigationTitle("Creator kit")
        .placeTitle("Creator kit")
        .sensoryFeedback(Haptic.scrub, trigger: picked)
        .sheet(item: $making) { VideoShareSheet(source: $0) }
    }

    private func tip(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.ds.footnote.weight(.semibold))
            .foregroundStyle(Color.ds.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
    }

    /// A tiny phone-shaped preview of the look: its colour, a face, its glyph. Decorative.
    private func swatch(_ template: ReelTemplate) -> some View {
        let (fill, ink) = colors(template)
        return VStack(spacing: Spacing.xxs) {
            Circle().fill(ink.opacity(Metrics.faceOpacity)).frame(width: Metrics.face, height: Metrics.face)
            Image(systemName: symbol(template)).font(.caption.weight(.heavy)).foregroundStyle(ink)
        }
        .frame(width: Metrics.swatch.width, height: Metrics.swatch.height)
        .background(fill, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .accessibilityHidden(true)
    }

    private func colors(_ template: ReelTemplate) -> (fill: Color, ink: Color) {
        switch template {
        case .classic: (Color.ds.band(.mild), Color.ds.ink)
        case .minimal: (Color.ds.ink, Color.ds.canvas)
        case .dayCounter: (Color.ds.band(.calm), Color.ds.ink)
        }
    }

    private func symbol(_ template: ReelTemplate) -> String {
        switch template {
        case .classic: "sparkles.rectangle.stack"
        case .minimal: "circle.lefthalf.filled"
        case .dayCounter: "calendar"
        }
    }

    private func detail(_ template: ReelTemplate) -> String {
        switch template {
        case .classic: String(localized: "Mood colours and your index counting down.")
        case .minimal: String(localized: "Dark and quiet — the face does the talking.")
        case .dayCounter: String(localized: "\"Day 1 → Day 40\" — how long you've kept going.")
        }
    }
}
