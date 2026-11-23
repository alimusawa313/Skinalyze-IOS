import SwiftData
import SwiftUI
import SkinalyzeKit

// P13 private vault: hide a scan from the Mirror, Deck, widgets and exports; see hidden scans only after Face ID /
// Touch ID / passcode. "Keep it secret" also removes the vault's entry from Profile — then it opens by pressing and
// holding the Deck title, so someone browsing the phone wouldn't know it's there.

enum Vault {
    static let secretKey = "vaultSecret"
}

/// On a scan: hide it, or show it again.
struct HideScanButton: View {
    let session: ScanSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        Menu {
            if session.isHidden {
                Button("Show in Mirror and Deck", systemImage: "eye") { setHidden(false) }
            } else {
                Button("Hide this scan", systemImage: "eye.slash") { confirming = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .accessibilityIdentifier("scanMore")
        .confirmationDialog("Hide this scan?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Hide", role: .destructive) {
                setHidden(true)
                dismiss()
            }
        } message: {
            Text("It leaves the Mirror, Deck, widgets and exports. Find it again in Profile → Hidden scans, behind \(AppLock.biometryName).")
        }
    }

    private func setHidden(_ hidden: Bool) {
        session.isHidden = hidden
        try? modelContext.save()
    }
}

/// The hidden scans, after authentication every time the list opens.
struct HiddenScansView: View {
    @Query(filter: #Predicate<ScanSession> { $0.isHidden }, sort: \ScanSession.createdAt, order: .reverse)
    private var scans: [ScanSession]
    @AppStorage(Vault.secretKey) private var secret = false
    @State private var unlocked = false
    @State private var failed = false

    var body: some View {
        Group {
            if unlocked {
                List {
                    if scans.isEmpty {
                        Text("No hidden scans. Hide one from its result screen (••• → Hide this scan).")
                            .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                    }
                    ForEach(scans) { scan in
                        NavigationLink {
                            ScanResultView(session: scan)
                        } label: {
                            Text(scan.createdAt, format: .dateTime.day().month().year().hour().minute())
                        }
                    }
                    Section {
                        Toggle("Keep hidden scans secret", isOn: $secret)
                            .accessibilityIdentifier("vaultSecret")
                    } footer: {
                        Text("Removes Hidden scans from Profile. To open it, press and hold the Deck title.")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Hidden scans", systemImage: "lock.fill")
                } description: {
                    Text(failed ? "Couldn't unlock. Try again." : "Unlock with \(AppLock.biometryName) to see them.")
                } actions: {
                    Button("Unlock") { Task { await unlock() } }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("vaultUnlock")
                }
            }
        }
        .navigationTitle("Hidden scans")
        .task { await unlock() }
    }

    private func unlock() async {
        #if DEBUG
        // UI tests can't answer Face ID.
        if UserDefaults.standard.bool(forKey: "vaultSkipAuth") {
            unlocked = true
            return
        }
        #endif
        unlocked = await AppLock.authenticate()
        failed = !unlocked
    }
}

/// Profile's entry, unless the user keeps the vault secret.
struct HiddenScansRow: View {
    @AppStorage(Vault.secretKey) private var secret = false

    var body: some View {
        if !secret {
            NavigationLink {
                HiddenScansView()
            } label: {
                Label("Hidden scans", systemImage: "eye.slash")
            }
            .accessibilityIdentifier("hiddenScansRow")
        }
    }
}
