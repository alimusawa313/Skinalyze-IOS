import SwiftData
import SwiftUI
import SkinalyzeKit

@main
struct SkinalyzeApp: App {
    @State private var appModel = AppModel()
    @State private var proAccess = ProAccess()
    private let container: ModelContainer

    init() {
        do {
            container = try AppPersistence.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        #if DEBUG
        DemoData.seedActivityIfRequested()
        #endif
        WatchBridge.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(proAccess)
                .appLockGate()
                .task {
                    await LegacyMigrationRunner.run(container: container)
                    // Before any demo data: a phone that already holds scans belongs to an existing user.
                    #if DEBUG
                    await proAccess.start(container: container, seedsDemoData: DemoData.isRequested)
                    await DemoData.seedIfRequested(into: container)
                    BenchPhotoExport.runIfRequested(container: container)
                    #else
                    await proAccess.start(container: container)
                    #endif
                    await WidgetSummary.refresh(from: container)
                }
        }
        .modelContainer(container)
    }
}
