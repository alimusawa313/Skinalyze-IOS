import Foundation
import Observation
import OSLog
import SkinalyzeKit
import UserNotifications

/// The routine builder's state (P5): extra steps per part and the morning/evening reminders the user chose.
/// The four shelf slots stay where they always were (`UserProfile` keys); extra steps live here.
@Observable
@MainActor
final class RoutineModel {
    private enum Key {
        static let plan = "routinePlan"
        static let reminders = "routineReminders"
    }

    struct Reminders: Codable, Equatable {
        var morningOn = false
        var eveningOn = false
        /// Minutes after midnight.
        var morningAt = 7 * 60 + 30
        var eveningAt = 21 * 60
    }

    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Routine")

    private(set) var plan: RoutinePlan
    private(set) var reminders: Reminders
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        plan = defaults.data(forKey: Key.plan).flatMap { try? JSONDecoder().decode(RoutinePlan.self, from: $0) } ?? .empty
        reminders = defaults.data(forKey: Key.reminders).flatMap { try? JSONDecoder().decode(Reminders.self, from: $0) } ?? Reminders()
    }

    // MARK: Steps

    func add(_ step: RoutineStep, to part: RoutinePart) {
        var updated = plan
        updated[part] = plan[part] + [step]
        save(updated)
    }

    func remove(_ step: RoutineStep, from part: RoutinePart) {
        var updated = plan
        updated[part] = plan[part].filter { $0.id != step.id }
        save(updated)
    }

    func move(in part: RoutinePart, from source: IndexSet, to destination: Int) {
        var steps = plan[part]
        steps.move(fromOffsets: source, toOffset: destination)
        var updated = plan
        updated[part] = steps
        save(updated)
    }

    private func save(_ updated: RoutinePlan) {
        guard updated != plan else { return }
        plan = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Key.plan)
    }

    // MARK: Warnings

    /// The shelf slots in use for a part, plus its extra steps, as the advisor sees them.
    func items(for part: RoutinePart) -> [RoutineItem] {
        let slots: [ProductCatalog.Slot] = part == .morning ? [.cleanser, .toner, .moisturizer, .sunscreen]
            : [.cleanser, .toner, .moisturizer]
        let base = slots.compactMap { slot -> RoutineItem? in
            let id = defaults.integer(forKey: slot.storageKey)
            guard id > 0, let product = ProductCatalog.shared.product(id: id) else { return nil }
            return RoutineItem(label: product.name, categories: Self.categories(of: product), isSunscreen: slot == .sunscreen)
        }
        let extra = plan[part].map { step in
            RoutineItem(label: Self.title(of: step),
                        categories: step.actives.union(step.productID.flatMap { ProductCatalog.shared.product(id: $0) }
                            .map(Self.categories(of:)) ?? []))
        }
        return base + extra
    }

    func warnings(for part: RoutinePart) -> [RoutineWarning] {
        RoutineAdvisor.warnings(for: items(for: part), part: part)
    }

    static func categories(of product: CatalogProduct) -> Set<IngredientCategory> {
        ProductVerdictEngine.categories(of: product.ingredientList.map { $0.lowercased() })
    }

    static func title(of step: RoutineStep) -> String {
        step.productID.flatMap { ProductCatalog.shared.product(id: $0)?.name }
            ?? step.customName.flatMap { $0.isEmpty ? nil : $0 }
            ?? RoutineCopy.kind(step.kind)
    }

    // MARK: Reminders

    /// Morning and evening reminders the user turned on. They repeat daily until turned off.
    func setReminders(_ updated: Reminders) async {
        reminders = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Key.reminders)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["routine-morning", "routine-evening"])
        guard updated.morningOn || updated.eveningOn else { return }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
        } catch {
            Self.logger.error("Notification permission failed: \(error.localizedDescription)")
            return
        }
        for (on, minutes, id, part) in [(updated.morningOn, updated.morningAt, "routine-morning", RoutinePart.morning),
                                         (updated.eveningOn, updated.eveningAt, "routine-evening", RoutinePart.evening)] where on {
            let content = UNMutableNotificationContent()
            content.title = RoutineCopy.reminderTitle(part)
            content.body = String(localized: "A minute for your skin. Pimpi's ready when you are.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
                                                        repeats: true)
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            } catch {
                Self.logger.error("Could not schedule the routine reminder: \(error.localizedDescription)")
            }
        }
    }
}

enum RoutineCopy {
    static func kind(_ kind: ExtraStepKind) -> String {
        switch kind {
        case .serum: String(localized: "Serum")
        case .treatment: String(localized: "Active")
        case .exfoliant: String(localized: "Exfoliant")
        case .eyeCream: String(localized: "Eye cream")
        case .mask: String(localized: "Mask")
        case .spotTreatment: String(localized: "Spot care")
        }
    }

    static func active(_ category: IngredientCategory) -> String? {
        switch category {
        case .retinoid: String(localized: "Retinoid (retinol, adapalene)")
        case .exfoliantAHA: String(localized: "AHA (glycolic, lactic acid)")
        case .exfoliantBHA: String(localized: "BHA (salicylic acid)")
        case .benzoylPeroxide: String(localized: "Benzoyl peroxide")
        case .vitaminC: String(localized: "Vitamin C")
        case .niacinamide: String(localized: "Niacinamide")
        case .azelaicAcid: String(localized: "Azelaic acid")
        default: nil
        }
    }

    static let pickableActives: [IngredientCategory] = [.retinoid, .exfoliantAHA, .exfoliantBHA, .benzoylPeroxide, .vitaminC,
                                                         .niacinamide, .azelaicAcid]

    static func reminderTitle(_ part: RoutinePart) -> String {
        part == .morning ? String(localized: "Morning routine time") : String(localized: "Evening routine time")
    }

    static func warning(_ warning: RoutineWarning) -> String {
        let names = warning.items.formatted(.list(type: .and))
        return switch warning.kind {
        case .retinoidWithAcid:
            String(localized: "\(names): a retinoid and an exfoliating acid together can be a lot for skin. Many people use them on different nights.")
        case .retinoidWithBenzoyl:
            String(localized: "\(names): benzoyl peroxide can make some retinoids less effective and adds dryness. Try them at different times.")
        case .vitaminCWithAcidOrBenzoyl:
            String(localized: "\(names): vitamin C with acids or benzoyl peroxide can sting. Try vitamin C in the morning and the others at night.")
        case .doubleExfoliation:
            String(localized: "\(names): two exfoliating products in one routine can over-exfoliate. One is usually enough.")
        case .retinoidInMorning:
            String(localized: "\(names): retinoids are usually an evening step, since sunlight breaks some of them down.")
        case .morningWithoutSunscreen:
            String(localized: "\(names): acids and retinoids make skin more sensitive to sun. Add a sunscreen to this morning routine.")
        }
    }
}
