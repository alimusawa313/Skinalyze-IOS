import AppIntents
import Foundation
import SkinalyzeKit

/// Shared by the app and the widget extension (Control Center control).
struct StartScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a skin scan"
    static let description = IntentDescription("Opens Skinalyze straight into a three-angle face scan.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "skinalyze://scan")!))
    }
}

#if !WIDGET_EXTENSION
/// "Is this good for my skin?" from Shortcuts or Siri with any ingredient list.
struct CheckIngredientsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check ingredients"
    static let description = IntentDescription("Checks an ingredient list against your skin profile and recent scans.")

    @Parameter(title: "Ingredients", inputOptions: String.IntentInputOptions(multiline: true))
    var ingredients: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let context = SharedContext.load() else {
            return .result(value: "", dialog: "Open Skinalyze once to set up your skin profile.")
        }
        let result = context.verdict(forIngredientText: ingredients)
        let reasons = result.reasons.prefix(2).map(\.text).joined(separator: " ")
        let summary = "\(result.verdict.title). \(reasons)"
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

/// "How's my skin?" — latest index and change, read from the shared widget snapshot.
struct ShowTrendIntent: AppIntent {
    static let title: LocalizedStringResource = "Show my skin trend"
    static let description = IntentDescription("Tells you your latest breakout index and how it changed.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = WidgetSummary.load()
        guard let index = snapshot.breakoutIndex, let band = snapshot.bandRaw.flatMap(BreakoutBand.init(rawValue:)) else {
            return .result(dialog: "No scans yet. Say “Start a skin scan in Skinalyze” to begin.")
        }
        let change = snapshot.delta.map { $0 < 0 ? "down \(abs($0))" : ($0 > 0 ? "up \($0)" : "unchanged") } ?? "your first scan"
        return .result(dialog: "Your latest breakout index is \(index) (\(BandCopy.title(band))), \(change) from the scan before.")
    }
}

enum RoutinePartOption: String, AppEnum {
    case morning, evening

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Routine"
    static let caseDisplayRepresentations: [RoutinePartOption: DisplayRepresentation] = [
        .morning: "Morning", .evening: "Evening",
    ]
}

/// "Check off my evening routine" — ticks every step of that routine for today (P14).
struct LogRoutineIntent: AppIntent {
    static let title: LocalizedStringResource = "Check off my routine"
    static let description = IntentDescription("Ticks every step of your morning or evening routine for today.")

    @Parameter(title: "Routine")
    var part: RoutinePartOption

    init() {}

    init(part: RoutinePartOption) {
        self.part = part
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let routinePart: RoutinePart = part == .morning ? .morning : .evening
        guard !RoutineToday.steps(for: routinePart).isEmpty else {
            return .result(dialog: "Add products to your shelf in Skinalyze first.")
        }
        let ticked = RoutineToday.completeAll(routinePart)
        WatchBridge.shared.push()
        return .result(dialog: ticked > 0 ? "Done! Pimpi ticked off your routine." : "That routine was already done today.")
    }
}

struct SkinalyzeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartScanIntent(), phrases: ["Start a skin scan in \(.applicationName)", "Scan my skin with \(.applicationName)"],
                    shortTitle: "Scan my skin", systemImageName: "viewfinder")
        AppShortcut(intent: ShowTrendIntent(), phrases: ["How's my skin in \(.applicationName)", "Show my \(.applicationName) trend"],
                    shortTitle: "My skin trend", systemImageName: "chart.line.downtrend.xyaxis")
        AppShortcut(intent: CheckIngredientsIntent(), phrases: ["Check ingredients with \(.applicationName)"],
                    shortTitle: "Check ingredients", systemImageName: "drop")
        AppShortcut(intent: LogRoutineIntent(), phrases: ["Check off my \(\.$part) routine in \(.applicationName)",
                                                         "Log my \(\.$part) routine in \(.applicationName)"],
                    shortTitle: "Check off routine", systemImageName: "checklist")
    }
}
#endif
