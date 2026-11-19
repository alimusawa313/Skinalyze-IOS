import SwiftUI
import WidgetKit
import SkinalyzeKit

/// What the Pimpi widget draws for each family. It lives in the shared sources so the app can show the very same
/// view in a debug gallery — the widget is checked with the code that ships.
struct PimpiWidgetView: View {
    let state: EngagementSnapshot.State
    let family: WidgetFamily

    private var days: Int { state.routine.count }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                Text(days, format: .number).font(.system(.title3, design: .rounded).weight(.heavy))
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Routine streak: \(days) days"))
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("\(days)-day streak", systemImage: "flame.fill").font(.headline)
                Text(line).font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(spacing: Spacing.xxs) {
                Pimpi(mood: state.mood)
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.ds.signal)
                    Text(days, format: .number)
                        .font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(Color.ds.ink)
                }
                Text(line).font(.caption2).foregroundStyle(Color.ds.inkSecondary)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var line: String {
        switch state.routine.status {
        case .doneToday: String(localized: "Done for today")
        case .due: String(localized: "Routine waiting")
        case .atRisk: String(localized: "Keep your streak tonight")
        case .broken, .none: String(localized: "Start a streak today")
        }
    }
}

#if DEBUG
/// Every widget family in light and dark at home-screen sizes — open with `-pimpiWidgetGallery YES`.
struct PimpiWidgetGallery: View {
    private static let smallSide: CGFloat = 158
    private static let previewScale: CGFloat = 0.75
    private static let circularSide: CGFloat = 72
    private static let rectangularSize = CGSize(width: 160, height: 72)
    private static let lockScreenTint = 0.3

    private static let states: [EngagementSnapshot.State] = [
        .init(routine: RoutineStreak(count: 5, status: .doneToday, milestone: nil),
              scan: ScanStreak(weeks: 3, status: .doneThisWeek, milestone: nil), mood: .happy),
        .init(routine: RoutineStreak(count: 128, status: .atRisk, milestone: nil),
              scan: ScanStreak(weeks: 3, status: .doneThisWeek, milestone: nil), mood: .worried),
        .init(routine: RoutineStreak(count: 0, status: .broken(previous: 12), milestone: nil),
              scan: ScanStreak(weeks: 0, status: .none, milestone: nil), mood: .sad)
    ]

    var body: some View {
        VStack(spacing: 0) {
            sheet.environment(\.colorScheme, .light)
            sheet.environment(\.colorScheme, .dark)
        }
        .ignoresSafeArea()
    }

    private var sheet: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(Self.states, id: \.self) { state in
                    PimpiWidgetView(state: state, family: .systemSmall)
                        .padding(Spacing.md)
                        .frame(width: Self.smallSide, height: Self.smallSide)
                        .background(Color.ds.canvas, in: .rect(cornerRadius: Radius.medium))
                        .scaleEffect(Self.previewScale)
                        .frame(width: Self.smallSide * Self.previewScale, height: Self.smallSide * Self.previewScale)
                }
            }
            HStack(spacing: Spacing.sm) {
                PimpiWidgetView(state: Self.states[1], family: .accessoryCircular)
                    .frame(width: Self.circularSide, height: Self.circularSide)
                    .background(.gray.opacity(Self.lockScreenTint), in: .circle)
                PimpiWidgetView(state: Self.states[1], family: .accessoryRectangular)
                    .frame(width: Self.rectangularSize.width, height: Self.rectangularSize.height)
                    .background(.gray.opacity(Self.lockScreenTint), in: .rect(cornerRadius: Radius.small))
            }
            .foregroundStyle(Color.ds.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.inkSecondary.opacity(Self.lockScreenTint))
    }
}
#endif
