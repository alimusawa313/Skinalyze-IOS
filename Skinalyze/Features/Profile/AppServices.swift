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

/// Scan reminders at a daylight time (good light = more consistent scans). Local notifications only.
enum ScanReminders {
    static let enabledKey = "scanRemindersEnabled"
    static let intervalKey = "scanReminderDays"
    private static let identifier = "scan-reminder"
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Reminders")

    static func schedule(everyDays days: Int) async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { return }
        } catch {
            logger.error("Notification permission failed: \(error.localizedDescription)")
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a quick skin scan")
        content.body = String(localized: "Daylight makes scans more consistent — face a window for best results.")
        content.sound = .default
        content.userInfo = ["url": "skinalyze://scan"]
        let fireDate = Calendar.current.date(byAdding: .day, value: max(days, 1), to: .now) ?? .now
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 10
        let request = UNNotificationRequest(identifier: identifier, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        do {
            try await center.add(request)
        } catch {
            logger.error("Scheduling reminder failed: \(error.localizedDescription)")
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Called after every saved scan so the next reminder counts from the latest scan.
    static func rescheduleIfEnabled() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        await schedule(everyDays: max(defaults.integer(forKey: intervalKey), 1))
    }
}

struct ReminderSettingsRow: View {
    @AppStorage(ScanReminders.enabledKey) private var enabled = false
    @AppStorage(ScanReminders.intervalKey) private var days = 3

    var body: some View {
        Toggle(isOn: $enabled) {
            Label("Scan reminders", systemImage: "bell")
        }
        .onChange(of: enabled) { _, isOn in
            if isOn { Task { await ScanReminders.schedule(everyDays: days) } } else { ScanReminders.cancel() }
        }
        if enabled {
            Stepper("Every \(days) days", value: $days, in: 1...14)
                .onChange(of: days) { _, value in Task { await ScanReminders.schedule(everyDays: value) } }
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
