import AVFoundation
import SwiftUI

/// Live camera preview. Owns the rotation coordinator (one per camera, created once the preview layer is in a window)
/// so preview AND captured photos stay upright in every orientation and iPhone Duo pose (CLAUDE.md §1 rule 2).
struct CameraPreview: UIViewRepresentable {
    let camera: CameraSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.camera = camera
        view.isAccessibilityElement = true
        view.accessibilityLabel = String(localized: "Camera preview")
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer } // layerClass guarantees it
        weak var camera: CameraSession?

        private var coordinator: AVCaptureDevice.RotationCoordinator?
        private var observations: [NSKeyValueObservation] = []

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observations.forEach { $0.invalidate() }
            observations = []
            coordinator = nil
            guard window != nil, let camera, let device = camera.device else { return }

            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            self.coordinator = coordinator
            // Read both angles first, then observe (KVO only reports later changes).
            applyPreviewAngle(coordinator.videoRotationAngleForHorizonLevelPreview)
            camera.applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
            observations = [
                coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] coordinator, _ in
                    let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                    DispatchQueue.main.async { self?.applyPreviewAngle(angle) }
                },
                coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak camera] coordinator, _ in
                    camera?.applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
                },
            ]
        }

        private func applyPreviewAngle(_ angle: CGFloat) {
            guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}
