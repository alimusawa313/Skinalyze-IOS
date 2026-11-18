import SwiftData
import SwiftUI
import SkinalyzeKit

@main
struct SkinalyzeApp: App {
    @State private var appModel = AppModel()
    private let container: ModelContainer

    init() {
        do {
            container = try AppPersistence.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .appLockGate()
                .task {
                    await LegacyMigrationRunner.run(container: container)
                    #if DEBUG
                    await DemoData.seedIfRequested(into: container)
                    #endif
                    await WidgetSummary.refresh(from: container)
                }
        }
        .modelContainer(container)
    }
}
