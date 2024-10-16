//
//  CameraView.swift
//  Skinalyze
//
//  Created by Ali Haidar on 10/16/24.
//

import SwiftUI
import AVFoundation
import Vision
import ARKit

struct CameraView: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

struct CameraPreviewView: UIViewControllerRepresentable {
    var session: AVCaptureSession
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = CameraPreviewController()
        controller.session = session
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No need to update anything here for this simple preview
    }
}

class CameraPreviewController: UIViewController {
    var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let session = session else {
            return
        }
        
        // Setup the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Adjust the preview layer size when the view's layout changes
        previewLayer?.frame = view.bounds
    }
}

