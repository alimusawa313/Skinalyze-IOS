//
//  CameraScanView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/9/24.
//

import SwiftUI
import AVFoundation
import Vision
import ARKit
import SceneKit

let synthesizer = AVSpeechSynthesizer()

struct CameraScanView: View {
    
    
    @StateObject private var viewModel = FaceTrackingViewModel()
    
    @State private var isViewActive = true
    
    @State private var capturedImages: [UIImage] = []
    @State private var currentCaptureStep: Int = 0
    @State private var showCapturedImagesView = false
    @State private var countdown: Int = 3 // Countdown starts at 3
    @State private var isCountdownActive: Bool = false // To track if countdown is active
    @State private var timer: Timer?
    
    @State private var isCameraLoaded = false
    @State private var showLoadingSheet = true
    
    @EnvironmentObject var router: Router
    
    private func cleanupResources() {
        // Stop all timers
        timer?.invalidate()
        timer = nil
        
        // Stop speech
        synthesizer.stopSpeaking(at: .immediate)
        
        // Stop camera session
        viewModel.stopSession()
        
        // Reset state
        capturedImages = []
        currentCaptureStep = 0
        isCountdownActive = false
        isCameraLoaded = false
    }
    
    var body: some View {
        ZStack {
            if isCameraLoaded {
                CameraPreviewView(session: viewModel.session)
                    .edgesIgnoringSafeArea(.all)
                //                    .onTapGesture {
                //                        router.navigateToRoot()
                //                    }
                //
                
                
                VStack {
                    GeometryReader { geometry in
                        let screenSize = geometry.size
                        let ovalWidth: CGFloat = 350 // Adjust oval width
                        let ovalHeight: CGFloat = 450 // Adjust oval height
                        
                        Ellipse()
                            .stroke(viewModel.isFaceInCircle ? Color.white : Color.red, lineWidth: 4)
                            .frame(width: ovalWidth, height: ovalHeight)
                            .position(x: screenSize.width / 2, y: screenSize.height / 2)
                    }
                }
                
                VStack {
                    Text(
                        viewModel.faceDistanceStatus == "Too Far" ? "TERLALU JAUH" :
                            viewModel.faceOrientation == "No face detected" ? "Posisikan wajah anda di\narea lingkaran" :
                            viewModel.lightingCondition == "dark" ? "TERLALU GELAP" : ""
                    )
                    if viewModel.faceDistanceStatus == "Normal" && viewModel.lightingCondition == "normal" {
                        if capturedImages.count < 1 && viewModel.faceOrientation == "Facing Forward" {
                            Text("Bersiap Memotret")
                        } else if capturedImages.count == 1 && viewModel.faceOrientation == "Facing Right" {
                            Text("Bersiap Memotret")
                        } else if capturedImages.count == 2 && viewModel.faceOrientation == "Facing Left" {
                            Text("Bersiap Memotret")
                        }
                    }
                    if viewModel.faceOrientation != "No face detected"{
                        
                        if capturedImages.count < 1 && viewModel.faceOrientation != "Facing Forward" {
                            Text("LIHAT KEDEPAN")
                        } else if capturedImages.count == 1 && viewModel.faceOrientation != "Facing Right" {
                            Text("LIHAT KEKIRI")
                        } else if capturedImages.count == 2 && viewModel.faceOrientation != "Facing Left" {
                            Text("LIHAT KEKANAN")
                        }
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 80)
                
                // Display lighting and face orientation status
                VStack {
                    HStack {
                        Spacer()
                        Text("LIGHTING")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(viewModel.lightingCondition == "normal" ? Color(hex: "5F7955").opacity(0.57) : Color(hex: "DF0D0D").opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white)
                            )
                        Spacer()
                        
                        
                        VStack {
                            let text: String = {
                                if capturedImages.count < 1 {
                                    return "LOOK FORWARD"
                                } else if capturedImages.count == 1 {
                                    return "LOOK LEFT"
                                } else {
                                    return "LOOK RIGHT"
                                }
                            }()
                            
                            let color: Color = {
                                if capturedImages.count < 1 {
                                    return viewModel.faceOrientation == "Facing Forward" ? Color(hex: "5F7955").opacity(0.57) : Color(hex: "DF0D0D").opacity(0.25)
                                } else if capturedImages.count == 1 {
                                    return viewModel.faceOrientation == "Facing Right" ? Color(hex: "5F7955").opacity(0.57) : Color(hex: "DF0D0D").opacity(0.25)
                                } else {
                                    return viewModel.faceOrientation == "Facing Left" ? Color(hex: "5F7955").opacity(0.57) : Color(hex: "DF0D0D").opacity(0.25)
                                }
                            }()
                            
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white)
                                )
                        }
                        
                        Spacer()
                        
                        Text("FACE POSITION")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(viewModel.faceDistanceStatus == "Normal" ? Color(hex: "5F7955").opacity(0.57) : Color(hex: "DF0D0D").opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white)
                            )
                        Spacer()
                    }
                    .padding()
                    .background(.black.opacity(0.69))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Image(capturedImages.count > 0 ? "doneCapture" : "frontFace")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Spacer()
                        Image(capturedImages.count > 1 ? "doneCapture" : "leftFace")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Spacer()
                        Image(capturedImages.count > 2 ? "doneCapture" : "rightFace")
                            .resizable()
                            .frame(width: 80, height: 80)
                        Spacer()
                    }
                    .padding()
                    .background(.black.opacity(0.69))
                }
                
                // Timer Overlay
                if isCountdownActive {
                    Text("\(countdown)")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }
        }
        .onChange(of: showCapturedImagesView) {
            if showCapturedImagesView == true{
                self.router.navigate(to: .capturedImagesView(images: capturedImages))
                
            }
        }
        .onAppear {
            //            viewModel.startSession()
            //            startCaptureProcess()
            //            self.showLoadingSheet = false
            //            self.viewModel.startSession()
            //            self.isCameraLoaded = true
            
            
            isViewActive = true
            viewModel.startSession()
            startCaptureProcess()
            self.showLoadingSheet = false
            self.isCameraLoaded = true
        }
        .onDisappear {
            //            viewModel.stopSession()
            //            timer?.invalidate()
            //            capturedImages = []
            //            currentCaptureStep = 0
            
            isViewActive = false
            cleanupResources()
        }
        .task {
            // Cleanup when view is dismissed
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    if !isViewActive {
                        cleanupResources()
                    }
                    continuation.resume()
                }
            }
        }
        
    }
    
    func tutorDone(){
        viewModel.startSession()
        startCaptureProcess()
        self.showLoadingSheet = false
        self.viewModel.startSession() // Start the camera session
        self.isCameraLoaded = true
    }
    
    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func speech(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
    
    func startCaptureProcess() {
        
        speech("Look forward")
        
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.0, repeats: true) { _ in
            if viewModel.faceDistanceStatus == "Normal" && viewModel.lightingCondition == "normal" {
                switch currentCaptureStep {
                case 0:
                    if viewModel.faceOrientation == "Facing Forward" {
                        triggerHapticFeedback()
                        startCountdown(for: .facingForward) // Start countdown for forward orientation
                    }
                case 1:
                    if viewModel.faceOrientation == "Facing Right" {
                        triggerHapticFeedback()
                        startCountdown(for: .facingRight) // Start countdown for right orientation
                    }
                case 2:
                    if viewModel.faceOrientation == "Facing Left" {
                        triggerHapticFeedback()
                        startCountdown(for: .facingLeft) // Start countdown for left orientation
                    }
                default:
                    break
                }
            }
        }
    }
    
    func startCountdown(for orientation: FaceOrientation) {
//        guard !isCountdownActive else { return } // Cegah countdown ganda
        guard !isCountdownActive, isViewActive else { return }
        isCountdownActive = true
        countdown = 3 // Reset countdown
        
        // Countdown loop dengan pengecekan kondisi setiap detik
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if viewModel.faceDistanceStatus == "Normal" && viewModel.lightingCondition == "normal" {
                switch orientation {
                case .facingForward:
                    if viewModel.faceOrientation != "Facing Forward" {
                        timer.invalidate()
                        isCountdownActive = false
                        return
                    }
                case .facingRight:
                    if viewModel.faceOrientation != "Facing Right" {
                        timer.invalidate()
                        isCountdownActive = false
                        return
                    }
                case .facingLeft:
                    if viewModel.faceOrientation != "Facing Left" {
                        timer.invalidate()
                        isCountdownActive = false
                        return
                    }
                }
                
                countdown -= 1 // Kurangi countdown setiap detik
                if countdown == 0 {
                    timer.invalidate() // Hentikan timer setelah countdown selesai
                    captureImage(for: orientation) // Capture image setelah countdown selesai
                    isCountdownActive = false // Sembunyikan countdown
                }
            } else {
                // Jika kondisi tidak memenuhi, hentikan countdown
                timer.invalidate()
                isCountdownActive = false
            }
        }
    }
    
    
    
    func captureImage(for orientation: FaceOrientation) {
        if let sampleBuffer = viewModel.lastSampleBuffer {
            if let capturedImage = captureImage(from: sampleBuffer) {
                capturedImages.append(capturedImage)
            }
        }
        currentCaptureStep += 1 // Move to the next capture step
        
        switch currentCaptureStep {
        case 1:
            speech("Look left")
        case 2:
            speech("Look right")
        default:
            break
        }
        
        // If we are done capturing all three orientations, navigate to the results view
        if currentCaptureStep > 2 {
            timer?.invalidate() // Stop the main capture timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showCapturedImagesView = true // Show captured images view
            }
        }
    }
    
    func captureImage(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Rotate the image to match the screen orientation
        let image = ciImage.oriented(.right)
        
        // Calculate the cropping rectangle based on the oval's size and position
        let screenSize = UIScreen.main.bounds.size
        let ovalWidth: CGFloat = 350
        let ovalHeight: CGFloat = 450
        let circleCenter = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        let cropRect = CGRect(
            x: circleCenter.x - (ovalWidth / 2),
            y: circleCenter.y - (ovalHeight / 2),
            width: ovalWidth,
            height: ovalHeight
        )
        
        // Convert the cropRect to the image's coordinate system
        let scale = CGAffineTransform(scaleX: image.extent.width / screenSize.width, y: image.extent.height / screenSize.height)
        let transformedCropRect = cropRect.applying(scale)
        
        // Crop the image
        let croppedImage = image.cropped(to: transformedCropRect)
        
        // Convert the CIImage to UIImage
        if let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
}

enum FaceOrientation {
    case facingForward
    case facingRight
    case facingLeft
}

#Preview {
    CameraScanView()
}



