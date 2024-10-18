import SwiftUI
import AVKit

struct SplashScreen: View {
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Image("ProfileAtas")
                    Spacer()
                }
                VStack {
                    
                    
                    Text("Welcome to Skinalyze")
                        .fontWeight(.semibold)
                        .font(.title)
                    Text("Face scan for analysis results\naccording to acne needs.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(destination: ChatView(isFromStartup: true)) {
                        PrimaryBTN(text: "Let’s Start", isDisabled: false, action: {})
                    }
                    .padding(.top, 100)
                    .padding(.bottom, 50)
                    Spacer()
                }
                .padding(.top, 200)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    SplashScreen()
}
