import SwiftUI
import SkinalyzeKit

/// Start/stop dates per product, so "did this help?" can compare scans before vs. after (PLAN.md §11.4).
enum RoutineHistory {
    private static let key = "routineHistory"

    struct Entry: Codable, Hashable {
        var startedAt: Date
        var stoppedAt: Date?
    }

    static func all() -> [Int: Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Int: Entry].self, from: data) else { return [:] }
        return decoded
    }

    static func started(_ productID: Int, at date: Date = .now) {
        var history = all()
        history[productID] = Entry(startedAt: date, stoppedAt: nil)
        save(history)
    }

    static func stopped(_ productID: Int, at date: Date = .now) {
        var history = all()
        guard var entry = history[productID] else { return }
        entry.stoppedAt = date
        history[productID] = entry
        save(history)
    }

    private static func save(_ history: [Int: Entry]) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Today's AM/PM check-off with a streak. Completing a step draws it through; no confetti (PLAN.md §7.5).
struct RoutineChecklist: View {
    enum Part: String, CaseIterable, Identifiable {
        case morning, evening
        var id: String { rawValue }
        var title: String { self == .morning ? String(localized: "Morning") : String(localized: "Evening") }
        var slots: [ProductCatalog.Slot] {
            self == .morning ? [.cleanser, .toner, .moisturizer, .sunscreen] : [.cleanser, .toner, .moisturizer]
        }
    }

    @AppStorage("routineLog") private var logRaw = ""
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0
    @State private var part: Part = Calendar.current.component(.hour, from: .now) < 15 ? .morning : .evening

    private func productID(_ slot: ProductCatalog.Slot) -> Int {
        switch slot {
        case .cleanser: cleanser
        case .toner: toner
        case .moisturizer: moisturizer
        case .sunscreen: sunscreen
        }
    }

    private var log: RoutineLog { RoutineLog(raw: logRaw) }

    var body: some View {
        let steps = part.slots.filter { productID($0) > 0 }
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionTitle("Today")
                Spacer()
                if log.streak > 0 {
                    Label("\(log.streak)-day streak", systemImage: "flame").font(.ds.label).foregroundStyle(Color.ds.signal)
                }
            }
            Picker("Routine", selection: $part) {
                ForEach(Part.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if steps.isEmpty {
                Text("Add products to your shelf to build your routine.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            ForEach(steps) { slot in
                let done = log.isDone(part: part.rawValue, slot: slot.rawValue)
                Button {
                    logRaw = log.toggling(part: part.rawValue, slot: slot.rawValue).raw
                } label: {
                    HStack {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Color.ds.positive : Color.ds.inkTertiary)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: done)
                        Text(ProductCatalog.shared.product(id: productID(slot))?.name ?? slot.title)
                            .font(.ds.callout)
                            .foregroundStyle(done ? Color.ds.inkSecondary : Color.ds.ink)
                            .strikethrough(done, color: Color.ds.inkTertiary)
                        Spacer()
                        Text(slot.title).font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(Haptic.toggle, trigger: done)
                .accessibilityValue(done ? Text("Done") : Text("Not done"))
            }
        }
        .dsCard()
    }
}

/// Compact day log: "yyyy-MM-dd:morning.Cleanser|…". Immutable updates.
struct RoutineLog: Equatable {
    let raw: String

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var entries: Set<String> { Set(raw.split(separator: "|").map(String.init)) }

    private static func key(_ date: Date, part: String, slot: String) -> String {
        "\(formatter.string(from: date)):\(part).\(slot)"
    }

    func isDone(part: String, slot: String, on date: Date = .now) -> Bool {
        entries.contains(Self.key(date, part: part, slot: slot))
    }

    func toggling(part: String, slot: String, on date: Date = .now) -> RoutineLog {
        let key = Self.key(date, part: part, slot: slot)
        let updated = entries.contains(key) ? entries.subtracting([key]) : entries.union([key])
        // Keep ~2 months so the stored string stays small.
        let cutoff = Self.formatter.string(from: Calendar.current.date(byAdding: .day, value: -60, to: date) ?? date)
        return RoutineLog(raw: updated.filter { $0 >= cutoff }.sorted().joined(separator: "|"))
    }

    /// Consecutive days (ending today or yesterday) with at least one step checked.
    var streak: Int {
        let days = Set(entries.compactMap { $0.split(separator: ":").first.map(String.init) })
        var count = 0
        var date = Date.now
        if !days.contains(Self.formatter.string(from: date)) {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        while days.contains(Self.formatter.string(from: date)) {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return count
    }
}
