import SwiftUI
import AVKit

struct SplashScreen: View {
    
    @EnvironmentObject var router: Router
    
    var body: some View {
            ZStack {
                VStack {
                    Image("ProfileAtas")
                        .resizable()
                        .frame(width: .infinity, height: 250)
                    Spacer()
                }
                VStack {
                    
                    Spacer()
                    
                    ResizableGIFPlayer(gifName: "Hover")
                    .padding(.bottom, 20)
                    
                    
                    Text("Welcome to Skinalyze")
                        .fontWeight(.semibold)
                        .font(.title)
                    Text("Face scan for analysis results\naccording to acne needs.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                        PrimaryBTN(text: "Let’s Start", isDisabled: false, action: {
                            router.navigate(to: .chatView(isFromStartup: true))
                        })
                    
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea()
        
    }
}

#Preview {
    SplashScreen()
}



