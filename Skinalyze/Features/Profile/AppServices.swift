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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled && isLocked {
                    ZStack {
                        Color.ds.canvas.ignoresSafeArea()
                        VStack(spacing: Spacing.md) {
                            Image(systemName: AppLock.symbolName).font(.largeTitle).foregroundStyle(Color.ds.signal)
                            Text("Skinalyze is locked").font(.ds.title)
                            Button("Unlock") { Task { await unlock() } }.buttonStyle(.dsPrimary).frame(maxWidth: 280)
                        }
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
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders from Pimpi")
                    Text("At most one a day. Pimpi stops after three in a row.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
            } icon: {
                Image(systemName: "bell")
            }
        }
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

/// A clean, shareable PDF for a dermatologist: trend, zones, products. Clearly labelled as non-medical.
struct ExportView: View {
    @Query(sort: \ScanSession.createdAt, order: .reverse) private var scans: [ScanSession]
    @State private var pdfURL: URL?

    var body: some View {
        Form {
            Section {
                Text("Creates a PDF of your last \(min(scans.count, 12)) scans — the trend, per-zone changes and the products you used. It stays on your phone until you share it.")
                    .font(.ds.footnote)
                if let pdfURL {
                    ShareLink("Share PDF", item: pdfURL)
                } else {
                    Button("Create PDF") { pdfURL = render() }
                        .disabled(scans.isEmpty)
                }
            }
        }
        .navigationTitle("Export")
    }

    @MainActor
    private func render() -> URL? {
        let url = URL.temporaryDirectory.appending(path: "Skinalyze-report.pdf")
        let renderer = ImageRenderer(content: ReportPage(scans: Array(scans.prefix(12))).frame(width: 612))
        renderer.proposedSize = .init(width: 612, height: nil)
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

private struct ReportPage: View {
    let scans: [ScanSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skinalyze — skin tracking summary").font(.title2.bold())
            Text("Generated \(Date.now.formatted(date: .long, time: .omitted)). Not a medical document; visible-change tracking only.")
                .font(.caption)
            TrendChart(scans: scans).frame(height: 180)
            ForEach(scans) { scan in
                HStack(alignment: .top) {
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .omitted)).frame(width: 110, alignment: .leading)
                    Text("Index \(scan.breakoutIndex) · \(BandCopy.title(scan.band))").frame(width: 140, alignment: .leading)
                    Text(LesionType.allCases.filter { scan.counts[$0] > 0 }
                        .map { "\(LesionGlyph.displayName(for: $0)) \(scan.counts[$0])" }
                        .joined(separator: ", "))
                }
                .font(.caption)
            }
        }
        .padding(32)
        .background(.white)
        .foregroundStyle(.black)
    }
}
