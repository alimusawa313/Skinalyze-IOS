import SwiftData
import SwiftUI
import SkinalyzeKit

/// G9 creator kit: reel looks for people who post their progress, a few tips, and how creator codes work. Creator
/// codes are App Store offer codes the Skinalyze team sets up per creator (no server of our own), so redemptions show
/// in App Store Connect.
struct CreatorKitView: View {
    @Query(filter: #Predicate<ScanSession> { !$0.isHidden }, sort: \ScanSession.createdAt, order: .reverse)
    private var scans: [ScanSession]
    @State private var making: VideoShareSource?

    var body: some View {
        List {
            Section {
                ForEach(ReelTemplate.allCases) { template in
                    Button { making = .reel(scans: scans, template: template) } label: {
                        HStack {
                            Image(systemName: symbol(template)).frame(width: 28).foregroundStyle(Color.ds.signal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.title).font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
                                Text(detail(template)).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(scans.count < 2)
                    .accessibilityIdentifier("reelTemplate.\(template.rawValue)")
                }
            } header: {
                Text("Reel looks")
            } footer: {
                Text(scans.count < 2 ? "Reels need at least two scans." : "Every look can hide your face, like the normal reel.")
            }
            Section("Tips") {
                Label("Scan in the same spot and light each time — the reel lines faces up by the eyes.", systemImage: "lightbulb")
                Label("Hide my face shares the outline and numbers only.", systemImage: "eye.slash")
                Label("Talk about your routine and habits — skin changes for many reasons.", systemImage: "text.bubble")
            }
            .font(.ds.footnote)
            Section {
                Text("Creator codes are App Store offer codes made for you by the Skinalyze team. Your followers type the code in the App Store or in Skinalyze, and every redemption is counted by Apple.")
                    .font(.ds.footnote)
            } header: {
                Text("Creator codes")
            }
        }
        .navigationTitle("Creator kit")
        .sheet(item: $making) { VideoShareSheet(source: $0) }
    }

    private func symbol(_ template: ReelTemplate) -> String {
        switch template {
        case .classic: "sparkles.rectangle.stack"
        case .minimal: "circle.lefthalf.filled"
        case .dayCounter: "calendar"
        }
    }

    private func detail(_ template: ReelTemplate) -> String {
        switch template {
        case .classic: String(localized: "Mood colours and your index counting down.")
        case .minimal: String(localized: "Dark and quiet — the face does the talking.")
        case .dayCounter: String(localized: "\"Day 1 → Day 40\" — how long you've kept going.")
        }
    }
}
