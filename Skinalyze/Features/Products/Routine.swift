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
    @State private var ownPart: Part
    /// Set when a Morning/Evening picker elsewhere on the page drives this list (the Shelf's, above the plank).
    private let sharedPart: Binding<Part>?
    @Environment(RoutineModel.self) private var routine: RoutineModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBuilder = false

    /// Opens on the given part of the day, or on the one that fits the time (evening from 15:00).
    init(initialPart: Part? = nil) {
        _ownPart = State(initialValue: initialPart ?? Self.partNow)
        sharedPart = nil
    }

    /// Follows a picker the page already shows, so this list doesn't repeat it.
    init(part: Binding<Part>) {
        _ownPart = State(initialValue: part.wrappedValue)
        sharedPart = part
    }

    /// The part of the day that fits the time (evening from 15:00).
    static var partNow: Part {
        Calendar.current.component(.hour, from: .now) < eveningFromHour ? .morning : .evening
    }

    private static let eveningFromHour = 15

    private var part: Part { sharedPart?.wrappedValue ?? ownPart }
    private var partBinding: Binding<Part> { sharedPart ?? $ownPart }

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
            HStack(spacing: Spacing.sm) {
                SectionTitle("Today")
                if sharedPart != nil {
                    Text(part.title)
                        .font(.ds.titleSmall)
                        .foregroundStyle(Color.ds.inkSecondary)
                        .contentTransition(.opacity)
                }
                if engagement.routine.count > 0 {
                    Label("\(engagement.routine.count)-day streak", systemImage: "flame.fill")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                        .labelStyle(StreakLabelStyle())
                        .contentTransition(.numericText(value: Double(engagement.routine.count)))
                }
                Spacer(minLength: 0)
                Button("Edit") { showsBuilder = true }
                    .buttonStyle(.chunky(.plain, fullWidth: false))
                    .accessibilityLabel(Text("Edit routine"))
                    .accessibilityIdentifier("editRoutine")
            }
            if sharedPart == nil {
                PillPicker(Part.allCases.map { (value: $0, title: $0.title) }, selection: partBinding)
            }
            if steps.isEmpty {
                Text("Add products to your shelf to build your routine.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
            }
            if !warnings.isEmpty {
                Button { showsBuilder = true } label: {
                    Label(warnings.count == 1 ? "1 thing to check in this routine" : "\(warnings.count) things to check in this routine",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.callout, design: .rounded).weight(.heavy))
                        .labelStyle(TintedIconLabelStyle(tint: Color.ds.caution))
                }
                .buttonStyle(.shelfRow)
            }
            ForEach(steps) { line in
                let done = log.isDone(part: part.rawValue, slot: line.id)
                Button {
                    logRaw = log.toggling(part: part.rawValue, slot: line.id).raw
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(done ? Color.ds.positive : Color.ds.hairline)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: done)
                        Text(line.title)
                            .font(.system(.callout, design: .rounded).weight(.heavy))
                            .foregroundStyle(done ? Color.ds.inkSecondary : Color.ds.ink)
                            .strikethrough(done, color: Color.ds.inkSecondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Spacing.xs)
                        Text(line.label)
                            .font(.ds.caption.weight(.semibold))
                            .foregroundStyle(Color.ds.inkSecondary)
                    }
                }
                .buttonStyle(.shelfRow)
                .sensoryFeedback(Haptic.toggle, trigger: done)
                .accessibilityValue(done ? Text("Done") : Text("Not done"))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .dsAnimation(.bouncy, value: part)
        .dsAnimation(.bouncy, value: logRaw)
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

/// The streak as a small white pill with a flame.
private struct StreakLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xxs) {
            configuration.icon.foregroundStyle(Color.ds.signal)
            configuration.title
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .dsSurface(radius: Radius.small)
    }
}

/// A label whose icon carries a colour and whose words stay in ink.
struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            configuration.icon.foregroundStyle(tint)
            configuration.title.foregroundStyle(Color.ds.ink).multilineTextAlignment(.leading)
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
