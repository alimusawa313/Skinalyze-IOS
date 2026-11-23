import SwiftUI
import SkinalyzeKit

// Share cards for recaps and finished challenges. Neither carries a photo or a skin result (FEATURES.md §0 rule 3).

struct RecapShare {
    let title: String
    let dates: String
    let cheer: String
    let mood: MascotMood
    let tiles: [RecapTile]
}

struct ChallengeShare {
    let kind: ChallengeKind
    let finished: Date
}

/// Names and words for each challenge.
enum ChallengeCopy {
    static func title(_ kind: ChallengeKind) -> String {
        switch kind {
        case .sunscreen: String(localized: "30 days of sunscreen")
        case .morningAndEvening: String(localized: "30 days of morning and evening")
        case .handsOff: String(localized: "30 days of hands off")
        }
    }

    static func detail(_ kind: ChallengeKind) -> String {
        switch kind {
        case .sunscreen: String(localized: "Tick the sunscreen step in your morning routine.")
        case .morningAndEvening: String(localized: "Tick at least one step in the morning and one in the evening.")
        case .handsOff: String(localized: "Each evening, tap if you kept your hands off your face.")
        }
    }

    static func symbol(_ kind: ChallengeKind) -> String {
        switch kind {
        case .sunscreen: "sun.max.fill"
        case .morningAndEvening: "sunrise.fill"
        case .handsOff: "hand.raised.fill"
        }
    }
}

struct RecapShareCard: View {
    let share: RecapShare
    let format: ShareCardFormat

    private var isSquare: Bool { format == .square }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(share.dates).font(CardMetrics.label).opacity(CardMetrics.softText)
                Text(share.title).font(CardMetrics.title).lineLimit(1).minimumScaleFactor(0.7)
            }
            if format == .story {
                Pimpi(mood: share.mood).frame(maxWidth: CardMetrics.pimpiMaxSide, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
            }
            Text(share.cheer).font(CardMetrics.body).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Grid(horizontalSpacing: Spacing.xs, verticalSpacing: Spacing.xs) {
                let tiles = Array(share.tiles.prefix(isSquare ? 4 : 6))
                ForEach(Array(stride(from: 0, to: tiles.count, by: 2)), id: \.self) { row in
                    GridRow {
                        ForEach(tiles[row..<min(row + 2, tiles.count)], id: \.self) { tile($0) }
                    }
                }
            }
            if format != .story { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ tile: RecapTile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: tile.symbol).font(CardMetrics.label).foregroundStyle(Color.ds.signal)
                Text(tile.value, format: .number).font(CardMetrics.heading.monospacedDigit())
            }
            Text(tile.label).font(CardMetrics.note).opacity(CardMetrics.softText).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }
}

struct ChallengeShareCard: View {
    let share: ChallengeShare

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Pimpi(mood: .excited)
                .frame(maxWidth: CardMetrics.pimpiMaxSide, maxHeight: .infinity)
            Label {
                Text(verbatim: "30")
            } icon: {
                Image(systemName: ChallengeCopy.symbol(share.kind)).font(CardMetrics.numeralSmall)
                    .foregroundStyle(Color.ds.signal)
            }
            .font(CardMetrics.numeral)
            Text(ChallengeCopy.title(share.kind)).font(CardMetrics.heading).multilineTextAlignment(.center)
            Text("Challenge finished \(share.finished.formatted(.dateTime.day().month().year()))")
                .font(CardMetrics.body).opacity(CardMetrics.softText)
        }
        .frame(maxWidth: .infinity)
    }
}
