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
    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(ChallengeModel.self) private var challenges: ChallengeModel?
    @Environment(ProAccess.self) private var access: ProAccess?
    @AppStorage(UserProfile.Key.cleanserID) private var cleanser = 0
    @AppStorage(UserProfile.Key.tonerID) private var toner = 0
    @AppStorage(UserProfile.Key.moisturizerID) private var moisturizer = 0
    @AppStorage(UserProfile.Key.sunscreenID) private var sunscreen = 0
    @State private var part: Part
    @Environment(RoutineModel.self) private var routine: RoutineModel?
    @State private var showsBuilder = false

    /// Opens on the given part of the day, or on the one that fits the time (evening from 15:00).
    init(initialPart: Part? = nil) {
        _part = State(initialValue: initialPart ?? (Calendar.current.component(.hour, from: .now) < Self.eveningFromHour ? .morning : .evening))
    }

    private static let eveningFromHour = 15

    private func productID(_ slot: ProductCatalog.Slot) -> Int {
        switch slot {
        case .cleanser: cleanser
        case .toner: toner
        case .moisturizer: moisturizer
        case .sunscreen: sunscreen
        }
    }

    private var log: RoutineLog { RoutineLog(raw: logRaw) }

    /// One line in today's checklist: a shelf slot or an extra step from the routine builder.
    private struct Line: Identifiable {
        let id: String
        let title: String
        let label: String
    }

    /// Cleanser and toner, then the extra steps, then moisturizer and sunscreen.
    private var lines: [Line] {
        func slotLine(_ slot: ProductCatalog.Slot) -> Line? {
            guard productID(slot) > 0 else { return nil }
            return Line(id: slot.rawValue, title: ProductCatalog.shared.product(id: productID(slot))?.name ?? slot.title, label: slot.title)
        }
        let routinePart: RoutinePart = part == .morning ? .morning : .evening
        let extras = (routine?.plan[routinePart] ?? []).map {
            Line(id: $0.id, title: RoutineModel.title(of: $0), label: RoutineCopy.kind($0.kind))
        }
        let before = part.slots.filter { $0 == .cleanser || $0 == .toner }.compactMap(slotLine)
        let after = part.slots.filter { $0 == .moisturizer || $0 == .sunscreen }.compactMap(slotLine)
        return before + extras + after
    }

    var body: some View {
        let steps = lines
        let warnings = routine?.warnings(for: part == .morning ? .morning : .evening) ?? []
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionTitle("Today")
                Spacer()
                if engagement.routine.count > 0 {
                    Label("\(engagement.routine.count)-day streak", systemImage: "flame.fill").font(.ds.label).foregroundStyle(Color.ds.signal)
                        .contentTransition(.numericText(value: Double(engagement.routine.count)))
                }
                Button("Edit") { showsBuilder = true }
                    .font(.ds.label)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text("Edit routine"))
                    .accessibilityIdentifier("editRoutine")
            }
            Picker("Routine", selection: $part) {
                ForEach(Part.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if steps.isEmpty {
                Text("Add products to your shelf to build your routine.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            if !warnings.isEmpty {
                Button { showsBuilder = true } label: {
                    Label(warnings.count == 1 ? "1 thing to check in this routine" : "\(warnings.count) things to check in this routine",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.caution)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
            ForEach(steps) { line in
                let done = log.isDone(part: part.rawValue, slot: line.id)
                Button {
                    logRaw = log.toggling(part: part.rawValue, slot: line.id).raw
                } label: {
                    HStack {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Color.ds.positive : Color.ds.inkTertiary)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: done)
                        Text(line.title)
                            .font(.ds.callout)
                            .foregroundStyle(done ? Color.ds.inkSecondary : Color.ds.ink)
                            .strikethrough(done, color: Color.ds.inkTertiary)
                        Spacer()
                        Text(line.label).font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
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
        .sheet(isPresented: $showsBuilder) { RoutineBuilderView() }
        .onChange(of: logRaw) { _, raw in
            let anyStepDone = RoutineLog(raw: raw).hasAnyStep()
            engagement.routineChanged(anyStepDoneToday: anyStepDone)
            if anyStepDone { quests?.did(.routine, isPro: access?.policy.hasFullAccess ?? false) }
            quests?.noteRoutineStreak(engagement.routine.count)
            challenges?.routineChanged(RoutineLog(raw: raw))
            WatchBridge.shared.push()
        }
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

    /// Whether at least one step is checked on `date`.
    func hasAnyStep(on date: Date = .now) -> Bool {
        let prefix = Self.formatter.string(from: date) + ":"
        return entries.contains { $0.hasPrefix(prefix) }
    }

    /// Whether at least one step of `part` ("morning" / "evening") is checked on `date`.
    func hasAnyStep(part: String, on date: Date = .now) -> Bool {
        let prefix = Self.formatter.string(from: date) + ":\(part)."
        return entries.contains { $0.hasPrefix(prefix) }
    }
}
