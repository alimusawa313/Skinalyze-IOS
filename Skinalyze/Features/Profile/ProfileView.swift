import SwiftData
import SwiftUI
import SkinalyzeKit

/// Profile & settings. Neutral avatar, no gender coding; data controls and privacy in one place.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(UserProfile.Key.name) private var name = ""
    @AppStorage(UserProfile.Key.skinType) private var skinTypeRaw = ""
    @AppStorage(UserProfile.Key.sensitivity) private var sensitivityRaw = ""
    @AppStorage(UserProfile.Key.goals) private var goalsRaw = ""
    @AppStorage(AppLock.enabledKey) private var appLockEnabled = false
    @Query private var scans: [ScanSession]
    @State private var confirmsDelete = false
    @State private var showsPrivacy = false

    var body: some View {
        NavigationStack {
            Form {
                Section { ProStatusRow() }
                #if DEBUG
                Section { DebugAccessToggle() } footer: { Text(verbatim: "Debug builds only.") }
                #endif
                Section("You") {
                    TextField("Name", text: $name).textContentType(.givenName)
                    Picker("Skin type", selection: $skinTypeRaw) {
                        ForEach(SkinType.allCases, id: \.self) { Text($0.title).tag($0.rawValue.capitalized) }
                    }
                    Picker("Sensitivity", selection: $sensitivityRaw) {
                        ForEach(UserProfile.Sensitivity.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
                Section("Focus") {
                    let goals = UserProfile.goals(from: goalsRaw)
                    ForEach(UserProfile.Goal.allCases) { goal in
                        Toggle(isOn: Binding(
                            get: { goals.contains(goal) },
                            set: { isOn in
                                goalsRaw = UserProfile.store(isOn ? goals.union([goal]) : goals.subtracting([goal]))
                            }
                        )) {
                            Label(goal.title, systemImage: goal.systemImage)
                        }
                    }
                }
                Section {
                    Toggle(isOn: $appLockEnabled) {
                        Label(AppLock.toggleTitle, systemImage: AppLock.symbolName)
                    }
                    ReminderSettingsRow()
                    NavigationLink {
                        ExportView()
                    } label: {
                        Label("Dermatologist visit pack", systemImage: "doc.richtext")
                    }
                } header: {
                    Text("Privacy & data")
                } footer: {
                    Text("Scans stay on this iPhone and in your own iCloud. \(scans.count) scans saved.")
                }
                Section {
                    Button("Privacy policy") { showsPrivacy = true }
                    Button("Delete all scans", role: .destructive) { confirmsDelete = true }
                        .disabled(scans.isEmpty)
                } footer: {
                    Text("Skinalyze tracks visible changes. It isn't a medical device and doesn't diagnose.")
                }
            }
            .navigationTitle("Profile")
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
            .confirmationDialog(Text("Delete all \(scans.count) scans?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete all scans", role: .destructive) {
                    scans.forEach { AppPersistence.delete($0, in: modelContext) }
                }
            } message: {
                Text("This removes them from this iPhone and your iCloud. It can't be undone.")
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(LocalizedStringKey, LocalizedStringKey)] = [
        ("1. No data collection by Skinalyze",
         "Skinalyze does not collect, store, or access your personal data or photos. All analysis runs locally on your device using Apple's on-device machine learning."),
        ("2. Data handling and storage",
         "Photo analysis happens on your device; your data never leaves it during analysis. Saved scans and products are stored in your personal iCloud account via CloudKit, which Skinalyze cannot access."),
        ("3. Facial data",
         "Face photos (and, on iPhones with Face ID, face-shape data used for the 3D view) are used only for skin tracking inside the app. They are never shared, uploaded to us, or used for advertising."),
        ("4. Product images",
         "Product photos are loaded from public product pages when you browse products. No personal data or scan data is sent with these requests."),
        ("5. Data sharing",
         "Skinalyze does not share personal data or facial photos with third parties."),
        ("6. Your rights",
         "You control all saved data. Delete scans in the app (Profile → Delete all scans) or from your iCloud settings at any time."),
        ("7. Cookies and tracking", "Skinalyze does not use cookies or tracking technologies."),
        ("8. Changes", "We may update this policy; changes will be shown in app updates."),
        ("9. Contact", "Questions? Email skinalyze.id@gmail.com"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Your privacy comes first. This explains how your data is handled when you use Skinalyze.")
                        .font(.ds.body)
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(section.0).font(.ds.headline).accessibilityAddTraits(.isHeader)
                            Text(section.1).font(.ds.body).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .dsCanvas()
            .navigationTitle("Privacy policy")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
