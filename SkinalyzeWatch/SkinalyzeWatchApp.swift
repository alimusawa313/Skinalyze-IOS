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

struct WatchRoutineView: View {
    @Environment(WatchRoutineModel.self) private var model
    @State private var evening = Calendar.current.component(.hour, from: .now) >= 15

    var body: some View {
        NavigationStack {
            Group {
                if let state = model.today {
                    let steps = evening ? state.evening : state.morning
                    List {
                        if state.streak > 0 {
                            Label("\(state.streak)-day streak", systemImage: "flame.fill")
                                .foregroundStyle(.pink)
                                .listRowBackground(Color.clear)
                        }
                        Picker("Routine", selection: $evening) {
                            Text("Morning").tag(false)
                            Text("Evening").tag(true)
                        }
                        if steps.isEmpty {
                            Text("Add products to your shelf on your iPhone.").font(.footnote)
                        }
                        ForEach(steps) { step in
                            Button { model.toggle(step) } label: {
                                HStack {
                                    Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(step.done ? .green : .secondary)
                                    Text(step.title).lineLimit(2)
                                }
                            }
                            .accessibilityValue(step.done ? Text("Done") : Text("Not done"))
                        }
                    }
                } else {
                    ContentUnavailableView("Open Skinalyze on your iPhone", systemImage: "iphone",
                                           description: Text("Your routine shows here once your iPhone has sent today's steps."))
                }
            }
            .navigationTitle("Routine")
        }
    }
}
