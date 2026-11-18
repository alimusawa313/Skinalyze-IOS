import SwiftData
import SwiftUI
import SkinalyzeKit

/// Onboarding for new users; the tab shell for everyone else. Existing users (who answered the old chat onboarding)
/// skip straight to the app.
struct RootView: View {
    @AppStorage(UserProfile.Key.onboardingComplete) private var onboardingComplete = false
    @AppStorage(UserProfile.Key.legacyUseSkincare) private var legacyUseSkincare = ""

    var body: some View {
        Group {
            if onboardingComplete || !legacyUseSkincare.isEmpty {
                AppTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Color.ds.signal)
    }
}

struct AppTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appModel = appModel
        TabView(selection: $appModel.selectedTab) {
            Tab("Today", systemImage: "sun.horizon", value: AppModel.Tab.today) {
                TodayView()
            }
            Tab("Timeline", systemImage: "chart.line.downtrend.xyaxis", value: AppModel.Tab.timeline) {
                ScanTimelineView()
            }
            Tab("Products", systemImage: "drop", value: AppModel.Tab.products) {
                ProductsView()
            }
            Tab(value: AppModel.Tab.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(isPresented: $appModel.isScanning) {
            ScanFlowView()
        }
        .sheet(item: $appModel.presentedScan) { presented in
            NavigationStack {
                if let session = modelContext.model(for: presented.id) as? ScanSession {
                    ScanResultView(session: session, isFreshScan: true)
                }
            }
        }
        .sheet(isPresented: $appModel.isShowingProfile) {
            ProfileView()
        }
        .onOpenURL { appModel.open($0) }
        #if DEBUG
        .onAppear {
            // Debug-only: `-startTab timeline|products|search` for screenshots and UI tests.
            if let tab = UserDefaults.standard.string(forKey: "startTab") {
                appModel.open(URL(string: "skinalyze://\(tab)")!)
            }
        }
        #endif
    }
}

/// The scan action lives above the tab bar on every screen (not a fake tab).
private struct ScanAccessory: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Button {
            appModel.startScan()
        } label: {
            Label("Scan my skin", systemImage: "viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .accessibilityHint("Opens the camera for a three-angle face scan")
    }
}
