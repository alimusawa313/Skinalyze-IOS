import Observation
import SwiftUI
import WatchConnectivity

/// P14: tick off the morning and evening routine from the wrist. The phone stays the source of truth; the watch
/// shows what it last heard and sends ticks back (queued if the phone is away).
@main
struct SkinalyzeWatchApp: App {
    @State private var model = WatchRoutineModel()

    var body: some Scene {
        WindowGroup {
            WatchRoutineView()
                .environment(model)
                .task { model.start() }
        }
    }
}

@Observable
@MainActor
final class WatchRoutineModel: NSObject {
    private(set) var state: WatchRoutineState?
    private static let cacheKey = "lastRoutineState"

    override init() {
        super.init()
        state = UserDefaults.standard.data(forKey: Self.cacheKey).flatMap { try? JSONDecoder().decode(WatchRoutineState.self, from: $0) }
    }

    /// Steps shown only when they're for today (an old copy from yesterday would mislead).
    var today: WatchRoutineState? {
        guard let state, state.day == Self.todayString else { return nil }
        return state
    }

    static var todayString: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 1, parts.day ?? 1)
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Ticks locally right away, then tells the phone.
    func toggle(_ step: WatchRoutineState.Step) {
        guard let current = today else { return }
        let flip = { (steps: [WatchRoutineState.Step]) in
            steps.map { $0.id == step.id ? WatchRoutineState.Step(id: $0.id, title: $0.title, done: !$0.done) : $0 }
        }
        apply(WatchRoutineState(day: current.day, morning: flip(current.morning), evening: flip(current.evening), streak: current.streak))
        let checkOff = WatchCheckOff(day: current.day, stepID: step.id, done: !step.done)
        guard let data = try? JSONEncoder().encode(checkOff) else { return }
        let payload = [WatchCheckOff.messageKey: data]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    fileprivate func apply(_ updated: WatchRoutineState) {
        state = updated
        UserDefaults.standard.set(try? JSONEncoder().encode(updated), forKey: Self.cacheKey)
    }
}

extension WatchRoutineModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WatchRoutineState.contextKey] as? Data
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchRoutineState.contextKey] as? Data
        Task { @MainActor in self.receive(data) }
    }

    private func receive(_ data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(WatchRoutineState.self, from: data) else { return }
        apply(decoded)
    }
}

/// The watch has no SkinalyzeKit, so it carries the few Pimpi's Place colours it needs (the dusk values of
/// `Palette`: pimpiBody, ink, canvas, positive, inkTertiary). Black is the watch's own background.
private enum WatchPalette {
    static let pink = Color(red: 1, green: 0x8A / 255, blue: 0x94 / 255)
    static let row = Color(red: 0x23 / 255, green: 0x22 / 255, blue: 0x4F / 255)
    static let cream = Color(red: 1, green: 0xF3 / 255, blue: 0xE4 / 255)
    static let done = Color(red: 0x4C / 255, green: 0xD4 / 255, blue: 0x9A / 255)
    static let idle = Color(red: 0x9A / 255, green: 0x93 / 255, blue: 0xB5 / 255)
}

private enum WatchMetrics {
    static let spacing: CGFloat = 6
    static let rowHeight: CGFloat = 44
    static let check: CGFloat = 26
    static let checkRing: CGFloat = 2.5
    static let pillPadding: CGFloat = 3
    static let checkPop: CGFloat = 1.25
    static let popUp = 0.12
    static let springDuration = 0.42
    static let springBounce = 0.45
}

struct WatchRoutineView: View {
    @Environment(WatchRoutineModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill
    @State private var evening = Calendar.current.component(.hour, from: .now) >= 15

    var body: some View {
        Group {
            if let state = model.today {
                let steps = evening ? state.evening : state.morning
                ScrollView {
                    VStack(alignment: .leading, spacing: WatchMetrics.spacing) {
                        header(streak: state.streak)
                        picker
                        if steps.isEmpty {
                            Text("Add products to your shelf on your iPhone.")
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .foregroundStyle(WatchPalette.cream)
                        }
                        ForEach(steps) { step in
                            stepRow(step)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Open Skinalyze on your iPhone", systemImage: "iphone",
                                       description: Text("Your routine shows here once your iPhone has sent today's steps."))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .tint(WatchPalette.pink)
    }

    /// Bouncy on the way in; Reduce Motion gets a plain fade-speed change.
    private var spring: Animation {
        reduceMotion ? .easeInOut : .spring(duration: WatchMetrics.springDuration, bounce: WatchMetrics.springBounce)
    }

    private func header(streak: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Routine")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(WatchPalette.pink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: WatchMetrics.spacing)
            if streak > 0 {
                Text("\(streak)-day streak")
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(WatchPalette.cream)
            }
        }
        .padding(.horizontal, WatchMetrics.spacing)
    }

    /// Morning or evening, as a pill that slides.
    private var picker: some View {
        HStack(spacing: 0) {
            pickerOption("Morning", isEvening: false)
            pickerOption("Evening", isEvening: true)
        }
        .padding(WatchMetrics.pillPadding)
        .background(WatchPalette.row, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Routine")
        .sensoryFeedback(.selection, trigger: evening)
    }

    private func pickerOption(_ title: LocalizedStringKey, isEvening: Bool) -> some View {
        let selected = evening == isEvening
        return Button {
            withAnimation(spring) { evening = isEvening }
        } label: {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(selected ? Color.black : WatchPalette.cream)
                .frame(maxWidth: .infinity, minHeight: WatchMetrics.rowHeight - WatchMetrics.pillPadding * 2)
                .background {
                    if selected { Capsule().fill(WatchPalette.pink).matchedGeometryEffect(id: "pill", in: pill) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func stepRow(_ step: WatchRoutineState.Step) -> some View {
        Button { model.toggle(step) } label: {
            HStack(spacing: WatchMetrics.spacing * 2) {
                ZStack {
                    Circle()
                        .strokeBorder(step.done ? WatchPalette.done : WatchPalette.idle, lineWidth: WatchMetrics.checkRing)
                        .background(Circle().fill(step.done ? WatchPalette.done : Color.clear))
                    if step.done {
                        Image(systemName: "checkmark")
                            .font(.system(.caption2, design: .rounded).weight(.black))
                            .foregroundStyle(WatchPalette.row)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: WatchMetrics.check, height: WatchMetrics.check)
                .animation(spring, value: step.done)
                .keyframeAnimator(initialValue: CGFloat(1), trigger: step.done) { view, scale in
                    view.scaleEffect(reduceMotion ? 1 : scale)
                } keyframes: { _ in
                    SpringKeyframe(WatchMetrics.checkPop, duration: WatchMetrics.popUp)
                    SpringKeyframe(1, spring: .bouncy)
                }
                Text(step.title)
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .foregroundStyle(WatchPalette.cream)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, WatchMetrics.spacing + 2)
            .padding(.trailing, WatchMetrics.spacing * 2)
            .padding(.vertical, WatchMetrics.spacing)
            .frame(minHeight: WatchMetrics.rowHeight)
            .background(WatchPalette.row, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: step.done) { _, done in done ? .success : .selection }
        .accessibilityValue(step.done ? Text("Done") : Text("Not done"))
    }
}
