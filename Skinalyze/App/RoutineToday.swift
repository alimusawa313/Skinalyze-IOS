import Foundation
import OSLog
import SkinalyzeKit
import WatchConnectivity

/// Today's routine steps and ticking them off, outside any view: for Siri / Shortcuts and the Apple Watch (P14).
/// Writes the same stores the checklist reads (`routineLog`, the streak's done days), so the app catches up on its own.
@MainActor
enum RoutineToday {
    static let logKey = "routineLog"

    struct Step: Equatable {
        /// "Cleanser" or an extra step's id — the routine log's slot.
        let slot: String
        let title: String
    }

    /// Cleanser and toner, then extra steps, then moisturizer and sunscreen — the checklist's order.
    static func steps(for part: RoutinePart, defaults: UserDefaults = .standard) -> [Step] {
        let slots: [ProductCatalog.Slot] = part == .morning ? [.cleanser, .toner, .moisturizer, .sunscreen]
            : [.cleanser, .toner, .moisturizer]
        func slotStep(_ slot: ProductCatalog.Slot) -> Step? {
            let id = defaults.integer(forKey: slot.storageKey)
            guard id > 0 else { return nil }
            return Step(slot: slot.rawValue, title: ProductCatalog.shared.product(id: id)?.name ?? slot.title)
        }
        let plan = defaults.data(forKey: "routinePlan").flatMap { try? JSONDecoder().decode(RoutinePlan.self, from: $0) } ?? .empty
        let extras = plan[part].map { Step(slot: $0.id, title: RoutineModel.title(of: $0)) }
        let before = slots.filter { $0 == .cleanser || $0 == .toner }.compactMap(slotStep)
        let after = slots.filter { $0 == .moisturizer || $0 == .sunscreen }.compactMap(slotStep)
        return before + extras + after
    }

    static func isDone(_ part: RoutinePart, slot: String, now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        RoutineLog(raw: defaults.string(forKey: logKey) ?? "").isDone(part: part.rawValue, slot: slot, on: now)
    }

    /// Ticks (or unticks) one step today and keeps the streak's done days in step.
    static func set(_ part: RoutinePart, slot: String, done: Bool, now: Date = .now, defaults: UserDefaults = .standard) {
        let log = RoutineLog(raw: defaults.string(forKey: logKey) ?? "")
        guard log.isDone(part: part.rawValue, slot: slot, on: now) != done else { return }
        let updated = log.toggling(part: part.rawValue, slot: slot, on: now)
        defaults.set(updated.raw, forKey: logKey)
        EngagementStore(defaults: defaults).setDone(updated.hasAnyStep(on: now), on: DayStamp(now, calendar: .current))
    }

    /// Ticks every step of a part. Returns how many were ticked now.
    @discardableResult
    static func completeAll(_ part: RoutinePart, now: Date = .now, defaults: UserDefaults = .standard) -> Int {
        let open = steps(for: part, defaults: defaults).filter { !isDone(part, slot: $0.slot, now: now, defaults: defaults) }
        open.forEach { set(part, slot: $0.slot, done: true, now: now, defaults: defaults) }
        return open.count
    }

    static func watchState(now: Date = .now, defaults: UserDefaults = .standard) -> WatchRoutineState {
        func steps(_ part: RoutinePart) -> [WatchRoutineState.Step] {
            self.steps(for: part, defaults: defaults).map {
                .init(id: "\(part.rawValue).\($0.slot)", title: $0.title, done: isDone(part, slot: $0.slot, now: now, defaults: defaults))
            }
        }
        let streak = StreakEngine.routine(doneDays: EngagementStore(defaults: defaults).doneDays,
                                          ledger: EngagementStore(defaults: defaults).ledger,
                                          weekendOff: EngagementStore(defaults: defaults).weekendOff,
                                          now: now, calendar: .current).count
        return WatchRoutineState(day: DayStamp(now, calendar: .current).string, morning: steps(.morning),
                                 evening: steps(.evening), streak: streak)
    }

    /// A tick from the watch. Returns whether it was applied.
    @discardableResult
    static func apply(_ checkOff: WatchCheckOff, now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard checkOff.applies(today: DayStamp(now, calendar: .current).string) else { return false }
        let parts = checkOff.stepID.split(separator: ".", maxSplits: 1).map(String.init)
        guard let part = RoutinePart(rawValue: parts[0]) else { return false }
        set(part, slot: parts[1], done: checkOff.done, now: now, defaults: defaults)
        return true
    }
}

/// The phone's end of the watch link: sends today's steps, applies ticks from the watch.
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Watch")

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the latest steps when a watch app is installed.
    func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(RoutineToday.watchState()) else { return }
        do {
            try WCSession.default.updateApplicationContext([WatchRoutineState.contextKey: data])
        } catch {
            Self.logger.error("Could not update the watch: \(error.localizedDescription)")
        }
    }

    fileprivate func receive(_ payload: [String: Any]) {
        guard let data = payload[WatchCheckOff.messageKey] as? Data,
              let checkOff = try? JSONDecoder().decode(WatchCheckOff.self, from: data) else { return }
        RoutineToday.apply(checkOff)
        push()
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchCheckOff.messageKey] as? Data else { return }
        Task { @MainActor in self.receive([WatchCheckOff.messageKey: data]) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchCheckOff.messageKey] as? Data else { return }
        Task { @MainActor in self.receive([WatchCheckOff.messageKey: data]) }
    }
}
