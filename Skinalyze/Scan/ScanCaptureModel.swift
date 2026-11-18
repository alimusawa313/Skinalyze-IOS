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
    static let manualCaptureDelay: TimeInterval = 8
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

    /// Debounced so the instruction never flickers (it changes only after a new hint has persisted ~0.6 s).
    var hint: GuidanceHint? { hintStabilizer.displayed }
    private var hintStabilizer = HintStabilizer()
    /// The angle the current frames are being matched against (front, or whichever side the user turned to).
    private(set) var targetAngle: CaptureAngle?
    /// Live head yaw (degrees, + = turned right) driving the Face ID-style ring.
    private(set) var liveYaw: Double = 0

    /// Ring progress per arc (0…1): captured arcs are full; the active arc fills as the head turns toward it.
    var ringProgress: (front: Double, right: Double, left: Double) {
        let target = GateThresholds.default.sideYaw.lowerBound
        func side(_ angle: CaptureAngle, sign: Double) -> Double {
            if captures[angle] != nil { return 1 }
            guard captures[.front] != nil else { return 0 }
            return min(max(liveYaw * sign / target, 0), 1) * 0.85 + (targetAngle == angle ? holdProgress * 0.15 : 0)
        }
        let front = captures[.front] != nil ? 1 : (targetAngle == .front ? max(holdProgress, report?.passed.count == CaptureGate.allCases.count ? 0.5 : 0.15) : 0)
        return (front, side(.right, sign: 1), side(.left, sign: -1))
    }

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
        guard let expected = currentAngle, !isCapturing else { return }
        // After the front photo, accept whichever side the user turns to first (like Face ID enrollment).
        let candidates: [CaptureAngle] = expected == .front
            ? [.front]
            : [CaptureAngle.right, .left].filter { captures[$0] == nil }
        let evaluated = candidates.map { ($0, GateEvaluator.evaluate(face: sample.face, quality: sample.quality, angle: $0)) }
        let (angle, report) = evaluated.first { $0.1.allPassed } ?? evaluated.first ?? (expected, GateReport(passed: [], hint: .noFace))
        self.report = report
        liveYaw = sample.face?.yawDegrees ?? liveYaw
        if targetAngle != angle { tracker = StabilityTracker() }
        targetAngle = angle
        hintStabilizer = hintStabilizer.updated(candidate: report.hint, at: sample.timestamp)
        tracker = tracker.updated(allPassed: report.allPassed, at: sample.timestamp)
        holdProgress = tracker.progress(at: sample.timestamp)
        angleStartedAt = angleStartedAt ?? sample.timestamp
        canCaptureManually = sample.timestamp - (angleStartedAt ?? sample.timestamp) >= Self.manualCaptureDelay
        logCalibration(sample, report: report, angle: angle)
        if tracker.isReady(at: sample.timestamp) {
            Task { await capture(angle) }
        }
    }

    #if DEBUG
    private var lastLog: TimeInterval = 0
    #endif

    /// Debug builds print live gate numbers (read with `devicectl … --console`) to calibrate thresholds on real hardware.
    private func logCalibration(_ sample: FrameSample, report: GateReport, angle: CaptureAngle) {
        #if DEBUG
        guard sample.timestamp - lastLog >= 0.5 else { return }
        lastLog = sample.timestamp
        let f = sample.face
        let q = sample.quality
        print(String(format: "[scan] %@ face=%@ w=%.2f cx=%.2f cy=%.2f yaw=%.0f pitch=%.0f roll=%.0f luma=%.0f clip=%.2f sharp=%.1f motion=%.2f passed=%d hint=%@",
                     angle.rawValue, f == nil ? "no" : "yes", f?.bounds.width ?? 0, f.map { $0.bounds.x + $0.bounds.width / 2 } ?? 0,
                     f.map { $0.bounds.y + $0.bounds.height / 2 } ?? 0, f?.yawDegrees ?? 0, f?.pitchDegrees ?? 0, f?.rollDegrees ?? 0,
                     q.meanLuma, q.clippedFraction, q.sharpness, q.motion, report.passed.count, report.hint?.rawValue ?? "ok"))
        #endif
    }

    private func capture(_ angle: CaptureAngle) async {
        guard !isCapturing, captures[angle] == nil, currentAngle != nil else { return }
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
        hintStabilizer = HintStabilizer()
        targetAngle = nil
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
