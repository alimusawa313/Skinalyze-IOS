//
//  SkinalyzeApp.swift
//  Skinalyze
//
//  Created by Heical Chandra on 23/09/24.
//

import SwiftUI
import SwiftData

@main
struct SkinalyzeApp: App {
    
    @StateObject var router = Router()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Result.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.navPath){
                ContentView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        switch destination {
                        case .anlyzResultView(let image):
                            AnalyzedResultView(images: image)
                                .environmentObject(router)
                        case .log(let isTabBarHidden):
                            LogView(isTabBarHidden: .constant(isTabBarHidden))
                        case .camScanView:
                            CameraScanView()
                                .environmentObject(router)
                        case .capturedImagesView(images: let images):
                            CapturedImagesView(images: images)
                                .environmentObject(router)
                        case .prodUsed(isFromStartup: let isFromStartup):
                            ProductUsedView(isFromStartup: isFromStartup)
                        case .compareImagesView(selectedLogs: let selectedLogs):
                            CompareView(selectedLogs: selectedLogs)
                        }
                    }
                    .environmentObject(router)
            }
            .accentColor(Color(hex: "5E0000"))
        }
        .modelContainer(sharedModelContainer)
    }
}
