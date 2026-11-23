import Foundation
import HealthKit
import Observation
import OSLog
import SkinalyzeKit

/// P3: the daily trigger check-in, kept on this phone only. P4 adds Apple Health sleep and period days, read on demand
/// and never stored (Health data never goes to iCloud — FEATURES.md §0 rule 4).
@Observable
@MainActor
final class JournalModel {
    private static let key = "journalEntries"
    private static let healthKey = "journalUsesHealth"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Journal")

    private(set) var entries: [JournalEntry]
    /// The user asked to include Apple Health (Pro). Only the choice is stored, never the data.
    private(set) var usesHealth: Bool
    /// Health-derived entries for this session only.
    private(set) var healthEntries: [JournalEntry] = []
    private let defaults: UserDefaults
    let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        entries = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([JournalEntry].self, from: $0) } ?? []
        usesHealth = defaults.bool(forKey: Self.healthKey)
    }

    var today: DayStamp { DayStamp(.now, calendar: calendar) }

    func tags(on day: DayStamp) -> Set<JournalTag> {
        entries.first { $0.day == day }?.tags ?? []
    }

    func toggle(_ tag: JournalTag, on day: DayStamp? = nil) {
        let day = day ?? today
        var tags = self.tags(on: day)
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
        var updated = entries.filter { $0.day != day }
        if !tags.isEmpty { updated.append(JournalEntry(day: day, tags: tags)) }
        entries = updated.sorted { $0.day < $1.day }
        defaults.set(try? JSONEncoder().encode(entries), forKey: Self.key)
    }

    /// Journal plus (when on and allowed) Health-derived days.
    func allEntries(includeHealth: Bool) -> [JournalEntry] {
        includeHealth ? entries + healthEntries : entries
    }

    // MARK: Apple Health (P4)

    private let store = HKHealthStore()
    private static let lookBackDays = 120

    func setUsesHealth(_ on: Bool) async {
        usesHealth = on
        defaults.set(on, forKey: Self.healthKey)
        if on { await loadHealth() } else { healthEntries = [] }
    }

    func loadHealth() async {
        guard usesHealth, HKHealthStore.isHealthDataAvailable(),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: [sleep, flow])
            let start = calendar.date(byAdding: .day, value: -Self.lookBackDays, to: .now) ?? .now
            async let sleepSamples = samples(sleep, since: start)
            async let flowSamples = samples(flow, since: start)
            healthEntries = TriggerEngine.healthEntries(sleepHours: Self.sleepHours(try await sleepSamples, calendar: calendar),
                                                        periodDays: Self.periodDays(try await flowSamples, calendar: calendar))
        } catch {
            Self.logger.error("Apple Health read failed: \(error.localizedDescription)")
            healthEntries = []
        }
    }

    private func samples(_ type: HKCategoryType, since start: Date) async throws -> [HKCategorySample] {
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: HKQuery.predicateForSamples(
            withStart: start, end: .now))], sortDescriptors: [])
        return try await descriptor.result(for: store)
    }

    /// Hours asleep per night, credited to the morning the night ended.
    static func sleepHours(_ samples: [HKCategorySample], calendar: Calendar) -> [DayStamp: Double] {
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        return samples.filter { asleep.contains($0.value) }.reduce(into: [:]) { hours, sample in
            hours[DayStamp(sample.endDate, calendar: calendar), default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
    }

    static func periodDays(_ samples: [HKCategorySample], calendar: Calendar) -> Set<DayStamp> {
        Set(samples.filter { $0.value != HKCategoryValueVaginalBleeding.none.rawValue }.map { DayStamp($0.startDate, calendar: calendar) })
    }
}
