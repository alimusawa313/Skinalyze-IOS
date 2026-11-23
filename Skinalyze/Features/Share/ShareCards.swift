import SwiftUI
import UIKit
import SkinalyzeKit

// The pictures people share. Each card is a still: plain values in, no loading, no motion — so the same view renders
// identically in the preview and in the exported file. Sizes are fixed (an export is an image, not a screen), which
// is why large text settings cannot break a card.

struct SkinShare {
    let index: Int
    let band: BreakoutBand
    let date: Date
    let portrait: SharePortrait
    let streakDays: Int
}

struct VerdictShare {
    let brand: String
    let name: String
    let result: VerdictResult
}

struct CompareShare {
    let earlier: UIImage
    let later: UIImage
    let earlierDate: Date
    let laterDate: Date
    let earlierIndex: Int
    let laterIndex: Int
}

enum ShareCardContent: @unchecked Sendable { // Values and immutable images only.
    case skin(SkinShare)
    case verdict(VerdictShare)
    case compare(CompareShare)
    case streak(days: Int)
    case recap(RecapShare)
    case challenge(ChallengeShare)
}

/// Fixed type and sizes for exports (cards and reel frames).
enum CardMetrics {
    static let numeral = Font.system(size: 92, weight: .heavy, design: .rounded).monospacedDigit()
    static let numeralCompact = Font.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit()
    static let numeralSmall = Font.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit()
    static let title = Font.system(size: 28, weight: .heavy, design: .rounded)
    static let heading = Font.system(size: 20, weight: .bold, design: .rounded)
    static let body = Font.system(size: 15, weight: .medium)
    static let label = Font.system(size: 12, weight: .bold, design: .rounded)
    static let note = Font.system(size: 11, weight: .medium)
    static let mark = Font.system(size: 17, weight: .heavy, design: .rounded)

    static let markSide: CGFloat = 32
    static let pimpiMaxSide: CGFloat = 230
    static let photoRatio: CGFloat = 3 / 4
    static let softText = 0.82
    static let shadowOpacity = 0.28
    static let shadowRadius: CGFloat = 14
    static let shadowDrop: CGFloat = 8
    static let scrim = 0.55
}

struct ShareCardView: View {
    let content: ShareCardContent
    let format: ShareCardFormat
    var showsWatermark = true
    /// Shimmer video only: where the holo sheen crosses the sticker (nil: no sheen).
    var sheen: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            card.frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsWatermark { ShareWatermark() }
        }
        .padding(Spacing.lg)
        .frame(width: format.pointSize.width, height: format.pointSize.height)
        .foregroundStyle(ink)
        .background(background)
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, scheme)
    }

    @ViewBuilder private var card: some View {
        switch content {
        case let .skin(share): SkinShareCard(share: share, format: format, sheen: sheen)
        case let .verdict(share): VerdictShareCard(share: share, format: format)
        case let .compare(share): CompareShareCard(share: share, format: format)
        case let .streak(days): StreakShareCard(days: days)
        case let .recap(share): RecapShareCard(share: share, format: format)
        case let .challenge(share): ChallengeShareCard(share: share)
        }
    }

    /// The skin card's mood colours are pastels, so its text is ink; every other card carries white text.
    private var ink: Color {
        if case .skin = content { Color.ds.ink } else { .white }
    }

    /// Coloured cards use the light palette; photo and mascot cards sit on the dark canvas.
    private var scheme: ColorScheme {
        switch content {
        case .skin, .verdict: .light
        case .compare, .streak, .recap, .challenge: .dark
        }
    }

    private var background: some View {
        let colors: [Color] = switch content {
        case let .skin(share): [Color.ds.band(share.band), Color.ds.band(share.band).opacity(0.7)]
        case let .verdict(share): [share.result.verdict.shareTint, share.result.verdict.shareTint.opacity(0.78)]
        case .compare, .streak, .recap, .challenge: [Color.ds.surfaceRaised, Color.ds.canvas]
        }
        return ZStack {
            Color.ds.canvas
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension ProductVerdict {
    var shareTint: Color {
        switch self {
        case .goodMatch: .ds.positive
        case .useWithCaution: .ds.caution
        case .probablyNotForYou: .ds.signal
        case .notEnoughInfo: .ds.inkSecondary
        }
    }
}

/// Pimpi and the name — the single mark on every export.
struct ShareWatermark: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Pimpi(mood: .happy)
                .padding(Spacing.xxs)
                .frame(width: CardMetrics.markSide, height: CardMetrics.markSide)
                .background(.white, in: Circle())
            Text(verbatim: "Skinalyze").font(CardMetrics.mark)
            Spacer(minLength: 0)
        }
    }
}

private struct StreakChip: View {
    let days: Int

    var body: some View {
        Label {
            Text(days, format: .number)
        } icon: {
            Image(systemName: "flame.fill")
        }
        .font(CardMetrics.label)
        .foregroundStyle(Color.ds.signal)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(.white, in: Capsule())
    }
}

// MARK: - Skin card

private struct SkinShareCard: View {
    let share: SkinShare
    let format: ShareCardFormat
    var sheen: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(share.date, format: .dateTime.day().month(.wide).year())
                    .font(CardMetrics.label).textCase(.uppercase)
                Spacer(minLength: Spacing.xs)
                if share.streakDays > 0 { StreakChip(days: share.streakDays) }
            }
            // Square has no height to spare: the number sits beside the sticker instead of under it.
            let layout = format == .square
                ? AnyLayout(HStackLayout(alignment: .bottom, spacing: Spacing.md))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            layout {
                portrait.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 0) {
                    Text(share.index, format: .number)
                        .font(format == .square ? CardMetrics.numeralCompact : CardMetrics.numeral)
                    Text("Breakout index · \(BandCopy.title(share.band))").font(CardMetrics.body)
                }
                .fixedSize()
            }
        }
    }

    @ViewBuilder private var portrait: some View {
        switch share.portrait {
        case let .sticker(art):
            ZStack {
                Image(uiImage: art.backing).resizable().scaledToFit()
                Image(uiImage: art.subject).resizable().scaledToFit()
                if let sheen {
                    SheenBand(position: sheen).mask { Image(uiImage: art.backing).resizable().scaledToFit() }
                }
            }
            .shadow(color: .black.opacity(CardMetrics.shadowOpacity), radius: CardMetrics.shadowRadius, y: CardMetrics.shadowDrop)
        case let .silhouette(shape):
            Image(uiImage: shape).resizable().scaledToFit()
                .overlay {
                    if let sheen {
                        SheenBand(position: sheen, overWhite: true).mask { Image(uiImage: shape).resizable().scaledToFit() }
                    }
                }
                .shadow(color: .black.opacity(CardMetrics.shadowOpacity), radius: CardMetrics.shadowRadius, y: CardMetrics.shadowDrop)
        case .none:
            Pimpi(mood: .happy).frame(maxWidth: CardMetrics.pimpiMaxSide, maxHeight: CardMetrics.pimpiMaxSide)
        }
    }
}

// MARK: - Product verdict card

private struct VerdictShareCard: View {
    let share: VerdictShare
    let format: ShareCardFormat

    private var reasonLimit: Int { format == .square ? 2 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Is it good for me?").font(CardMetrics.label).textCase(.uppercase).opacity(CardMetrics.softText)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: share.brand).font(CardMetrics.body).opacity(CardMetrics.softText)
                Text(verbatim: share.name).font(format == .square ? CardMetrics.heading : CardMetrics.title)
                    .lineLimit(format == .square ? 2 : 3).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(share.result.verdict.title, systemImage: share.result.verdict.systemImage)
                    .font(CardMetrics.heading)
                    .foregroundStyle(share.result.verdict.shareTint)
                ForEach(share.result.reasons.prefix(reasonLimit)) { reason in
                    Label(reason.text, systemImage: icon(for: reason.kind))
                        .font(CardMetrics.body)
                        .foregroundStyle(Color.ds.ink)
                        .lineLimit(format == .square ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            // Compliance wording: never truncated, whatever else has to give way.
            Text("Based on my skin profile. General information, not medical advice.")
                .font(CardMetrics.note).opacity(CardMetrics.softText)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }

    private func icon(for kind: VerdictReason.Kind) -> String {
        switch kind {
        case .positive: "checkmark.circle"
        case .caution: "exclamationmark.circle"
        case .negative: "xmark.circle"
        }
    }
}

// MARK: - Earlier / later card

private struct CompareShareCard: View {
    let share: CompareShare
    let format: ShareCardFormat

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                photo(share.earlier, title: "Earlier", date: share.earlierDate)
                photo(share.later, title: "Later", date: share.laterDate)
            }
            .frame(maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("Breakout index").font(CardMetrics.body).opacity(CardMetrics.softText).fixedSize()
                Spacer(minLength: Spacing.xs)
                Text(verbatim: "\(share.earlierIndex) → \(share.laterIndex)")
                    .font(format == .story ? CardMetrics.numeralCompact : CardMetrics.numeralSmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Label("Lined up by your eyes", systemImage: "eye")
                .font(CardMetrics.note).opacity(CardMetrics.softText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func photo(_ image: UIImage, title: LocalizedStringKey, date: Date) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(CardMetrics.photoRatio, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(CardMetrics.label).textCase(.uppercase)
                    Text(date, format: .dateTime.day().month().year()).font(CardMetrics.note)
                }
                .padding(Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(CardMetrics.scrim)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

// MARK: - Streak card

private struct StreakShareCard: View {
    let days: Int

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Pimpi(mood: .excited)
                .frame(maxWidth: CardMetrics.pimpiMaxSide, maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: "flame.fill").font(CardMetrics.numeralSmall).foregroundStyle(Color.ds.signal)
                Text(days, format: .number).font(CardMetrics.numeral)
            }
            Text("\(days) days in a row!").font(CardMetrics.heading)
        }
        .frame(maxWidth: .infinity)
    }
}
