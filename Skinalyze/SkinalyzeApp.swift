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
    @State private var tintColor: Color = Color("brownSecondary")
    
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
                                .environmentObject(router)
                        case .camScanView:
                            CameraScanView()
                                .environmentObject(router)
                                .onAppear { tintColor = .white }
                                .onDisappear { tintColor = Color("brownSecondary") }
                        case .capturedImagesView(images: let images):
                            CapturedImagesView(images: images)
                                .environmentObject(router)
                        case .prodUsed(isFromStartup: let isFromStartup):
                            ProductUsedView(isFromStartup: isFromStartup)
                                .environmentObject(router)
                        case .compareImagesView(selectedLogs: let selectedLogs):
                            CompareView(selectedLogs: selectedLogs)
                                .environmentObject(router)
                        case .detailView(selectedLogs: let selectedLogs):
                            DetailVIew(selectedLogs: selectedLogs)
                                .environmentObject(router)
                        case .chatView(isFromStartup: let isFromStartup):
                            ChatView(isFromStartup: isFromStartup)
                                .environmentObject(router)
                        case .productUsedView(isFromStartup: let isFromStartup):
                            ProductUsedView(isFromStartup: isFromStartup)
                                .environmentObject(router)
                        case .newDetailView(selectedLogs: let selectedLogs):
                            NewDetailViewTest(selectedLogs: selectedLogs)
                                .environmentObject(router)
                        case .newCompareImagesView(selectedLogs: let selectedLogs):
                            NewCompareView(selectedLogs: selectedLogs)
                                .environmentObject(router)
                        }
                    }
                    .environmentObject(router)
            }
            .accentColor(tintColor)
        }
        .modelContainer(sharedModelContainer)
    }
}
