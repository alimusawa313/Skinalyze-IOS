import Foundation
import SwiftUI
import SkinalyzeKit

/// Gathers what recaps count from the stores that already exist (routine days, quest ledger, scans, shelf history),
/// and remembers which recaps were seen.
@MainActor
enum RecapData {
    private static let seenKey = "seenRecaps"

    static func history(scans: [ScanSession], quests: QuestModel) -> ActivityHistory {
        ActivityHistory(routineDays: EngagementStore().doneDays, scanDates: scans.map(\.createdAt),
                        quests: quests.ledger.completed)
    }

    static func shelf() -> [ShelfStint] {
        RoutineHistory.all().map { ShelfStint(productID: $0.key, started: $0.value.startedAt, stopped: $0.value.stoppedAt) }
    }

    /// "Today" for deciding which recap is due. Debug builds can pretend with `-recapToday yyyy-MM-dd`.
    static var now: Date {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "recapToday"), let day = DayStamp(string: raw) {
            return day.date(in: .current)
        }
        #endif
        return .now
    }

    /// The recap to offer on the Shelf: Wrapped first, then the month, then the week — only one at a time, and only
    /// when something happened in it and it hasn't been opened or dismissed.
    static func due(history: ActivityHistory, calendar: Calendar = .current) -> RecapPeriod? {
        let now = Self.now
        let candidates = [RecapEngine.dueWrapped(now: now, calendar: calendar),
                          RecapEngine.dueMonth(now: now, calendar: calendar),
                          RecapEngine.dueWeek(now: now, calendar: calendar)].compactMap { $0 }
        let seen = seenIDs
        return candidates.first { period in
            !seen.contains(period.id) && !RecapEngine.recap(period, history: history, calendar: calendar).isEmpty
        }
    }

    static var seenIDs: Set<String> { Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? []) }

    static func markSeen(_ period: RecapPeriod) {
        UserDefaults.standard.set(Array(seenIDs.union([period.id])).sorted(), forKey: seenKey)
    }
}

extension RecapPeriod: @retroactive Identifiable {}

/// Titles and Pimpi's words for a recap. All copy here is about effort.
enum RecapCopy {
    static func title(_ period: RecapPeriod) -> String {
        let calendar = Calendar.current
        let start = period.first.date(in: calendar)
        switch period.kind {
        case .week: return String(localized: "Your week")
        case .month: return String(localized: "Your \(start.formatted(.dateTime.month(.wide)))")
        case .quarter: return String(localized: "Your Skin Wrapped")
        case .year: return String(localized: "Your \(start.formatted(.dateTime.year())) Wrapped")
        }
    }

    static func dates(_ period: RecapPeriod) -> String {
        let calendar = Calendar.current
        let start = period.first.date(in: calendar), end = period.last.date(in: calendar)
        switch period.kind {
        case .week, .quarter:
            return (start..<end).formatted(.interval.day().month(.abbreviated).year())
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .year: return start.formatted(.dateTime.year())
        }
    }

    static func cheer(_ cheer: RecapCheer) -> String {
        switch cheer {
        case .everyDay: String(localized: "Every single day! I'm so proud of you.")
        case .mostDays: String(localized: "You showed up most days. That's how habits stick.")
        case .keptLooking: String(localized: "You kept checking in. Every little bit counts.")
        case .freshStart: String(localized: "A quiet stretch, and that's okay. Let's start fresh together.")
        }
    }

    static func mood(_ cheer: RecapCheer) -> MascotMood {
        switch cheer {
        case .everyDay, .mostDays: .excited
        case .keptLooking: .happy
        case .freshStart: .curious
        }
    }

    static func isWrapped(_ period: RecapPeriod) -> Bool { period.kind == .quarter || period.kind == .year }
}

/// Pimpi beside the words normally; above them at accessibility text sizes, so the words keep the full width.
struct PimpiRow<Content: View>: View {
    var spacing: CGFloat = Spacing.md
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}
