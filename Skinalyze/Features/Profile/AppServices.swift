import LocalAuthentication
import OSLog
import SwiftData
import SwiftUI
import UserNotifications
import SkinalyzeKit

// MARK: - App lock

/// Optional biometric lock for scans. Copy and glyph follow the device: Face ID on most iPhones, **Touch ID on
/// iPhone Duo**, passcode otherwise (CLAUDE.md §1 rule 8).
enum AppLock {
    static let enabledKey = "appLockEnabled"

    static var biometry: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    static var toggleTitle: String {
        switch biometry {
        case .faceID: String(localized: "Lock with Face ID")
        case .touchID: String(localized: "Lock with Touch ID")
        case .opticID: String(localized: "Lock with Optic ID")
        default: String(localized: "Lock with passcode")
        }
    }

    /// "Face ID", "Touch ID" (iPhone Duo), "Optic ID" or "your passcode".
    static var biometryName: String {
        switch biometry {
        case .faceID: String(localized: "Face ID")
        case .touchID: String(localized: "Touch ID")
        case .opticID: String(localized: "Optic ID")
        default: String(localized: "your passcode")
        }
    }

    static var symbolName: String {
        switch biometry {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock"
        }
    }

    static func authenticate() async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: String(localized: "Unlock your skin scans"))
        } catch {
            return false
        }
    }
}

/// Covers the app (and its app-switcher snapshot) until the user authenticates.
struct AppLockGate: ViewModifier {
    @AppStorage(AppLock.enabledKey) private var enabled = false

    private enum Metrics {
        static let pimpi: CGFloat = 120
        static let buttonWidth: CGFloat = 280
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && isLocked {
                    ZStack {
                        Color.ds.canvas.ignoresSafeArea()
                        VStack(spacing: Spacing.md) {
                            Pimpi(mood: .sleepy).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                            Label("Skinalyze is locked", systemImage: AppLock.symbolName)
                                .font(PlaceType.sectionTitle)
                                .foregroundStyle(Color.ds.ink)
                            Button("Unlock") { Task { await unlock() } }
                                .buttonStyle(.chunky)
                                .frame(maxWidth: Metrics.buttonWidth)
                        }
                        .padding(Spacing.lg)
                    }
                    .transition(.opacity)
                }
            }
            .task { if enabled { await unlock() } }
            .onChange(of: scenePhase) { _, phase in
                guard enabled else { return }
                if phase == .background { isLocked = true }
                if phase == .active, isLocked { Task { await unlock() } }
            }
    }

    private func unlock() async {
        isLocked = !(await AppLock.authenticate())
    }
}

extension View {
    func appLockGate() -> some View { modifier(AppLockGate()) }
}

// MARK: - Reminders

/// Pimpi's reminders (local notifications only). The plan comes from `ReminderPlanner`: at most one a day, three in a
/// row at most, then silence until the app is opened again. Wording is about showing up — never about skin condition.
enum PimpiReminders {
    static let enabledKey = "scanRemindersEnabled" // same switch the old scan reminder used
    private static let identifierPrefix = "pimpi-reminder-"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Reminders")
    private static var identifiers: [String] { (0..<ReminderPlanner.maximumSeries).map { "\(identifierPrefix)\($0)" } + ["scan-reminder"] }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks for permission (when turning on) and plans from the current snapshot.
    static func enable() async -> Bool {
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else { return false }
        } catch {
            logger.error("Notification permission failed: \(error.localizedDescription)")
            return false
        }
        await reschedule(snapshot: EngagementShared.load())
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Replaces whatever is pending with a fresh plan. Called whenever streak state changes and on app activation.
    static func reschedule(snapshot: EngagementSnapshot, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let calendar = Calendar.current
        for reminder in ReminderPlanner.plan(snapshot: snapshot, now: now, calendar: calendar, enabled: true) {
            let content = UNMutableNotificationContent()
            (content.title, content.body) = copy(for: reminder)
            content.sound = .default
            content.userInfo = ["url": reminder.kind == .scan ? "skinalyze://scan" : "skinalyze://products"]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let request = UNNotificationRequest(identifier: "\(identifierPrefix)\(reminder.step)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
            } catch {
                logger.error("Scheduling reminder failed: \(error.localizedDescription)")
            }
        }
    }

    /// Pimpi's voice. The third in a row says goodbye, so the silence afterwards is expected.
    static func copy(for reminder: PlannedReminder) -> (title: String, body: String) {
        if reminder.step >= ReminderPlanner.maximumSeries - 1 {
            return (String(localized: "Last nudge from Pimpi"),
                    String(localized: "I'll stop reminding you now. Come back whenever you like."))
        }
        switch reminder.kind {
        case .routine:
            return reminder.step == 0
                ? (String(localized: "Pimpi is keeping your streak warm"),
                   String(localized: "One routine step tonight keeps your \(reminder.streakDays)-day streak."))
                : (String(localized: "Still here with my magnifying glass"),
                   String(localized: "A quick routine check-off keeps the streak going."))
        case .scan:
            return (String(localized: "Scan day"),
                    String(localized: "Daylight makes scans more consistent — face a window for best results."))
        case .comeBack:
            return (String(localized: "Pimpi misses you"),
                    String(localized: "A new streak starts with one step."))
        }
    }
}

struct ReminderSettingsRow: View {
    @AppStorage(PimpiReminders.enabledKey) private var enabled = false

    var body: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders from Pimpi").font(PlaceType.rowTitle).foregroundStyle(Color.ds.ink)
                Text("At most one a day. Pimpi stops after three in a row.")
                    .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .tint(Color.ds.positive)
        .placeSurfaceRow()
        .sensoryFeedback(Haptic.toggle, trigger: enabled)
        .onChange(of: enabled) { _, isOn in
            if isOn {
                Task { if await !PimpiReminders.enable() { enabled = false } }
            } else {
                PimpiReminders.cancel()
            }
        }
    }
}

// MARK: - Export

// The dermatologist visit pack lives in DermPack.swift (P11).
