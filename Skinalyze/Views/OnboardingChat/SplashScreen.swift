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
//                    LoopingVideoPlayer(videoName: "SplashScreenPimpi")
//                        .frame(height: 250)
                    
                    Image("Maskot")
                        .resizable()
                        .frame(width: 200, height: 150)
                        .padding(.bottom, 50)
                        
                    
//                    Spacer()
                    Text("Welcome to Skinalyze")
                        .fontWeight(.semibold)
                        .font(.title)
                    Text("Face scan for analysis results\naccording to acne needs.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
//                    NavigationLink(destination: ChatView(isFromStartup: true)) {
                    Spacer()
                        PrimaryBTN(text: "Let’s Start", isDisabled: false, action: {
                            router.navigate(to: .chatView(isFromStartup: true))
                        })
//                    }
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea()
        
    }
}

#Preview {
    SplashScreen()
}

struct LoopingVideoPlayer: View {
    private let player: AVQueuePlayer
    private let playerLooper: AVPlayerLooper
    
    init(videoName: String) {
        // Create an AVPlayerItem with the video
        guard let fileUrl = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            fatalError("Failed to find video file: \(videoName).mp4")
        }
        let playerItem = AVPlayerItem(url: fileUrl)
        
        // Create the player and player looper
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        self.player = queuePlayer
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .background(.clear)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
            .edgesIgnoringSafeArea(.all)
    }
}
