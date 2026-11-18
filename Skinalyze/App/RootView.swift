import SwiftData
import SwiftUI
import SkinalyzeKit

/// Onboarding for new users; the Mirror shell for everyone else. Existing users (who answered the old chat onboarding)
/// skip straight to the app.
struct RootView: View {
    @AppStorage(UserProfile.Key.onboardingComplete) private var onboardingComplete = false
    @AppStorage(UserProfile.Key.legacyUseSkincare) private var legacyUseSkincare = ""

    var body: some View {
        Group {
            if onboardingComplete || !legacyUseSkincare.isEmpty {
                AppShell()
            } else {
                OnboardingView()
            }
        }
        .tint(Color.ds.signal)
    }
}
