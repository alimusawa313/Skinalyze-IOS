import Observation
import OSLog
import SwiftData
import UIKit
import SkinalyzeKit

/// Drives a scan: permission → gated auto-capture of front/right/left → review → analysis → save.
/// UI state only; the camera works on its own queues and analysis runs off the main actor.
@Observable
@MainActor
final class ScanCaptureModel {
    static let manualCaptureDelay: TimeInterval = 20
    private static let logger = Logger(subsystem: "com.Patani.Skinalyze", category: "Scan")

    private(set) var state: ScanFlowState = .idle
    private(set) var report: GateReport?
    private(set) var holdProgress: Double = 0
    private(set) var captures: [CaptureAngle: UIImage] = [:]
    private(set) var isCapturing = false
    private(set) var canCaptureManually = false
    private(set) var cameraUnavailable = false
    private(set) var captureFailed = false
    private(set) var savedSessionID: PersistentIdentifier?

    let camera = CameraSession()
    private var tracker = StabilityTracker()
    private var angleStartedAt: TimeInterval?
    private var latestTimestamp: TimeInterval = 0
    private var frameTask: Task<Void, Never>?

    var currentAngle: CaptureAngle? {
        if case let .capturing(angle, _) = state { return angle }
        return nil
    }

    var hint: GuidanceHint? { report?.hint }

    // MARK: - Lifecycle

    func start() async {
        guard state == .idle else { return }
        send(.start)
        let granted: Bool = switch CameraSession.authorizationStatus() {
        case .authorized: true
        case .notDetermined: await CameraSession.requestAccess()
        default: false
        }
        guard granted else {
            send(.permissionDenied)
            return
        }
        do {
            try await camera.configure()
        } catch {
            Self.logger.error("Camera configuration failed: \(error.localizedDescription)")
            cameraUnavailable = true
            return
        }
        send(.permissionGranted)
        camera.start()
        listenToFrames()
    }

    /// Called when the app leaves/returns to the foreground or the device folds/unfolds: captured angles are kept.
    func pause() {
        camera.stop()
        resetHold()
        send(.interrupted)
    }

    func resume() {
        guard case .capturing = state else { return }
        camera.start()
    }

    func cancel() {
        frameTask?.cancel()
        frameTask = nil
        camera.stop()
        captures = [:]
        resetHold()
        send(.cancel)
    }

    // MARK: - Capture

    func captureManually() {
        guard let angle = currentAngle else { return }
        Task { await capture(angle) }
    }

    func retake(_ angle: CaptureAngle) {
        captures[angle] = nil
        send(.retake(angle))
        resetHold()
        camera.start()
    }

    private func listenToFrames() {
        frameTask?.cancel()
        let frames = camera.frames
        frameTask = Task { [weak self] in
            for await sample in frames {
                guard let self, !Task.isCancelled else { return }
                self.handle(sample)
            }
        }
    }

    private func handle(_ sample: FrameSample) {
        latestTimestamp = sample.timestamp
        guard let angle = currentAngle, !isCapturing else { return }
        let report = GateEvaluator.evaluate(face: sample.face, quality: sample.quality, angle: angle)
        self.report = report
        tracker = tracker.updated(allPassed: report.allPassed, at: sample.timestamp)
        holdProgress = tracker.progress(at: sample.timestamp)
        angleStartedAt = angleStartedAt ?? sample.timestamp
        canCaptureManually = sample.timestamp - (angleStartedAt ?? sample.timestamp) >= Self.manualCaptureDelay
        if tracker.isReady(at: sample.timestamp) {
            Task { await capture(angle) }
        }
    }

    private func capture(_ angle: CaptureAngle) async {
        guard !isCapturing, currentAngle == angle else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let photo = try await camera.capturePhoto()
            captures[angle] = photo
            captureFailed = false
            send(.captured(angle))
            resetHold()
            if case .reviewing = state { camera.stop() }
        } catch {
            Self.logger.error("Photo capture failed: \(error.localizedDescription)")
            captureFailed = true
            resetHold()
        }
    }

    private func resetHold() {
        tracker = StabilityTracker()
        holdProgress = 0
        angleStartedAt = nil
        canCaptureManually = false
        report = nil
    }

    // MARK: - 3D (Face ID iPhones only; never on iPhone Duo)

    private(set) var faceMesh: FaceMeshDraft?
    private(set) var isCapturingMesh = false
    private(set) var meshFailed = false
    var canCapture3D: Bool { FaceMeshCapturer.isSupported }

    func captureFaceMesh() async {
        guard canCapture3D, !isCapturingMesh else { return }
        camera.stop()
        isCapturingMesh = true
        defer { isCapturingMesh = false }
        do {
            faceMesh = try await FaceMeshCapturer().capture()
            meshFailed = false
        } catch {
            Self.logger.error("3D capture failed: \(error.localizedDescription)")
            meshFailed = true
        }
    }

    // MARK: - Analysis

    func confirm(productIDs: [Int], container: ModelContainer) async {
        send(.confirm)
        guard state == .analyzing else { return }
        await analyze(productIDs: productIDs, container: container)
    }

    func retryAnalysis(productIDs: [Int], container: ModelContainer) async {
        send(.retryAnalysis)
        guard state == .analyzing else { return }
        await analyze(productIDs: productIDs, container: container)
    }

    private func analyze(productIDs: [Int], container: ModelContainer) async {
        camera.stop()
        let prepared = ScanFlow.sequence.compactMap { angle in
            captures[angle].flatMap { ScanAnalyzer.prepare($0, angle: angle) }
        }
        guard prepared.count == ScanFlow.sequence.count else {
            send(.analysisFailed("photos"))
            return
        }
        do {
            let analysis = try await ScanAnalyzer.analyze(prepared, productIDs: productIDs)
            var pins: [FacePin] = []
            if let faceMesh, let frontFace = analysis.frontFace {
                pins = FacePinMapper.pins(for: analysis.draft.detections, photoFace: frontFace, mesh: faceMesh)
            }
            savedSessionID = try await ScanStore(modelContainer: container)
                .save(analysis.draft, faceMesh: faceMesh, pins: pins)
            send(.analysisSucceeded)
        } catch {
            Self.logger.error("Analysis failed: \(error.localizedDescription)")
            send(.analysisFailed(error.localizedDescription))
        }
    }

    private func send(_ event: ScanFlowEvent) {
        state = ScanFlow.reduce(state, event)
    }
}
